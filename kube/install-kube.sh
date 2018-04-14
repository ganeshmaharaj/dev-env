#!/bin/bash -x

# Script to install kube and helm in a new machine/container
# Author: Ganesh Mahalingam

# Peg the versions to the ones below as that is what openstack-helm uses. We can
# move it to newer ones when we stop using them or stop working on openstack-helm
# Using kube version from the apt sources against downloading the tar like OSH does.
helm_ver=$(curl -SsL https://github.com/kubernetes/helm/releases/latest | awk '/\/tag\//' | grep -v no-underline | cut -d '"' -f 2 | awk '{n=split($NF,a,"/");print a[n]}'  | awk 'a !~ $0{print}; {a=$0}')
kube_ver=$(curl -SsL https://storage.googleapis.com/kubernetes-release/release/stable.txt)
# Hack the kub version more to get apt to work nice.
# Not using kube version from here anymore. Just what is there in the latest package
kube_ver=${kube_ver#\"v}
KUBE_VERSION=${KUBE_VERSION:-${kube_ver#v}-*}
HELM_VERSION=${HELM_VERSION:-${helm_ver//\"/}}
TMP_DIR=$(mktemp -d)
SCRIPT_ENV="KUBECONFIG=/etc/kubernetes/admin.conf "
NETWORK_CIDR="10.244.0.0/16"

function apt_install() {
  echo "Installing Kubernetes in an apt based system..."
  sudo -E bash -c "cat << EOF > /etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF"

  echo "Get keys..."
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo -E apt-key add -

  sudo -E apt update
  sudo groupadd docker
  sudo gpasswd -a ${USER} docker
  sudo -E apt install -y make git curl
  sudo -E apt install -y docker-ce kubelet kubeadm kubectl
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

  sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
  echo "put selinux setenforce to 0 until kubelet can handle selinux better..."
  sudo -E setenforce 0
  sudo sed -i 's/^SELINUX=.*/SELINUX=permissive/g' /etc/selinux/config
  sudo dnf -y update
  sudo groupadd docker
  sudo gpasswd -a ${USER} docker
  sudo dnf install -y  make git curl wget
  sudo dnf install -y kubelet kubeadm kubectl docker-ce
  # Hack for docker-ce & kubeadm
  sudo sed -i 's/--cgroup-driver=systemd/--cgroup-driver=cgroupfs/g' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
  sudo systemctl enable docker && sudo systemctl start docker
  sudo systemctl enable kubelet && sudo systemctl start kubelet

  # Issue logged and discussed https://github.com/openshift/origin/issues/15038
  echo "Clearing rhel secrets.. This is a workaround.."
  sudo rm -rf /usr/share/rhel/secrets
}

function install_kube() {
  # Setting the subnet static here for now.
  # Running kubeadm reset cause of issue https://github.com/kubernetes/kubernetes/issues/53356
  echo "Setup kube on this system"
  sudo -E kubeadm reset
  sudo -E kubeadm init --pod-network-cidr "${NETWORK_CIDR}"

  echo "Allow $USER to run kube commands..."
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
}

function setup_master() {
  echo "Tainting master on NoSchedule..."
  kubectl taint nodes `hostname` node-role.kubernetes.io/master:NoSchedule-

  # Using calico as the CNI given I mostly work with openstack-helm
  # Using info from: https://openstack-helm.readthedocs.io/en/latest/install/multinode.html
  curl https://docs.projectcalico.org/v3.0/getting-started/kubernetes/installation/hosted/kubeadm/1.7/calico.yaml | sed -e 's|192.168.0.0/16|'"${NETWORK_CIDR}"'|g' | kubectl create -f -
  curl -O -L https://github.com/projectcalico/calicoctl/releases/download/v2.0.0/calicoctl
  sudo -E chmod +x ~/calicoctl

  echo "Now let us install helm.."
  curl -sSL https://storage.googleapis.com/kubernetes-helm/helm-${HELM_VERSION}-linux-amd64.tar.gz | tar -zxv --strip-components=1 -C ${TMP_DIR}
  sudo mv ${TMP_DIR}/helm /usr/local/bin/helm
  rm -rf ${TMP_DIR}
  /usr/local/bin/helm init

  # https://github.com/kubernetes/helm/issues/2224
  echo "Creating tiller service account..."
  curl https://raw.githubusercontent.com/ganeshmaharaj/ceph-dev-env/master/kube/extra-perms.yaml | kubectl create -f -
  kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'

  echo "Setting some env variables.. Writing them to your bashrc.."
  echo "export KUBE_VERSION=${KUBE_VERSION}" >> ~/.bashrc
  echo "export HELM_VERSION=${HELM_VERSION}" >> ~/.bashrc
  echo "export KUBECONFIG=${HOME}/.kube/config" >> ~/.bashrc
}

function label_nodes_ceph() {
  for lbl in openstack-control-plane ceph-mon ceph-osd ceph-mgr ceph-rgw ceph-mds
  do
    echo "Label Node:  $lbl"
    kubectl label nodes $lbl=enabled --all --overwrite
  done
}


if [ -f /etc/redhat-release ]; then
  dnf_install
elif [ -f /etc/lsb-release ]; then
  apt_install
else
  echo "Unable to find the OS type to use a package manager."
  exit 1
fi
install_kube
setup_master
label_nodes_ceph
