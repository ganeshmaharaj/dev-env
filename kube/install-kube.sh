#!/bin/bash

# Script to install kube and helm in a new machine/container
# Author: Ganesh Mahalingam

# Peg the versions to the ones below as that is what openstack-helm uses. We can
# move it to newer ones when we stop using them or stop working on openstack-helm
# Using kube version from the apt sources against downloading the tar like OSH does.
KUBE_VERSION="1.7.5-*"
HELM_VERSION=v2.6.1
TMP_DIR=$(mktemp -d)
SCRIPT_ENV="KUBECONFIG=/etc/kubernetes/admin.conf "

function apt_install() {
  echo "Installing Kubernetes in an apt based system..."
  sudo -E bash -c "cat << EOF > /etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF"

  echo "Get keys..."
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo -E apt-key add -

  sudo -E apt update
  sudo -E apt install -y make git curl
  sudo -E apt install -y docker.io kubelet="${KUBE_VERSION}" kubeadm="${KUBE_VERSION}" \
              kubectl="${KUBE_VERSION}"
  sudo -E apt-mark hold kubelet kubeadm kubectl
}

function dnf_install() {
  echo "Installing Kubernetes in a dnf based system..."
  sudo -E bash -c "cat << EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF"

  echo "put selinux setenforce to 0 until kubelet can handle selinux better..."
  sudo -E setenforce 0
  sudo dnf -y update
  sudo dnf install -y  make git curl wget
  sudo dnf install -y kubelet-${KUBE_VERSION} kubeadm-${KUBE_VERSION} kubectl-${KUBE_VERSION} docker
  sudo systemctl enable kubelet && sudo systemctl start kubelet
  sudo systemctl enable docker && sudo systemctl start docker

  # Issue logged and discussed https://github.com/openshift/origin/issues/15038
  echo "Clearing rhel secrets.. This is a workaround.."
  sudo rm -rf /usr/share/rhel/secrets
}

if [ -f /etc/redhat-release ]; then
  dnf_install
elif [ -f /etc/lsb-release ]; then
  apt_install
else
  echo "Unable to find the OS type to use a package manager."
  exit 1
fi

# Setting the subnet static here for now.
# Running kubeadm reset cause of issue https://github.com/kubernetes/kubernetes/issues/53356
echo "Setup kube on this system"
sudo -E kubeadm reset
sudo -E kubeadm init --pod-network-cidr 10.244.0.0/16

echo "Tainting master on NoSchedule..."
sudo -E ${SCRIPT_ENV} kubectl taint nodes `hostname` node-role.kubernetes.io/master:NoSchedule-

# Using calico as the CNI given I mostly work with openstack-helm
# Using info from: https://openstack-helm.readthedocs.io/en/latest/install/multinode.html
sudo -E ${SCRIPT_ENV} kubectl create -f http://docs.projectcalico.org/v2.1/getting-started/kubernetes/installation/hosted/kubeadm/1.6/calico.yaml
wget -q https://github.com/projectcalico/calicoctl/releases/download/v1.6.1/calicoctl -O ~/calicoctl
sudo -E chmod +x ~/calicoctl

echo "Setting up default RBAC for OSH..."
sudo -E ${SCRIPT_ENV} kubectl update -f https://raw.githubusercontent.com/openstack/openstack-helm/master/tools/kubeadm-aio/assets/opt/rbac/dev.yaml

echo "Now let us install helm.."
curl -sSL https://storage.googleapis.com/kubernetes-helm/helm-${HELM_VERSION}-linux-amd64.tar.gz | tar -zxv --strip-components=1 -C ${TMP_DIR}
sudo mv ${TMP_DIR}/helm /usr/local/bin/helm
rm -rf ${TMP_DIR}
sudo -E ${SCRIPT_ENV} /usr/local/bin/helm init

# https://github.com/kubernetes/helm/issues/2224
echo "Creating tiller service account..."
curl https://raw.githubusercontent.com/ganeshmaharaj/ceph-dev-env/master/kube/tiller-perms.yaml | sudo -E ${SCRIPT_ENV} kubectl create -f -
sudo -E ${SCRIPT_ENV} kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'

echo "Setting some env variables.. Writing them to your bashrc.."
echo "export KUBE_VERSION=${KUBE_VERSION}" >> ~/.bashrc
echo "export HELM_VERSION=${HELM_VERSION}" >> ~/.bashrc
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> ~/.bashrc
