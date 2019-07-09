#!/bin/bash

set -o errexit
set -o nounset

source /etc/os-release

function install_ubuntu()
{
	sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

	sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
	sudo apt update
	sudo apt install -y docker-ce docker-ce-cli containerd.io
}

function install_debian()
{
	sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -

	sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable"

	sudo apt update
	sudo apt install -y docker-ce docker-ce-cli containerd.io
}

function install_fedora()
{
	sudo dnf -y install dnf-plugins-core
	sudo dnf config-manager \
    --add-repo \
    https://download.docker.com/linux/fedora/docker-ce.repo
	sudo dnf -y install docker-ce docker-ce-cli containerd.io
}

function user_docker_grp()
{
	sudo usermod -aG docker $USER
}

case "$ID" in
  "ubuntu"*)  install_ubuntu;;
  "fedora")   install_fedora;;
  "debian")   instalL_debian;;
  *)          echo "OS not supported!"; exit 1;;
esac
user_docker_grp
