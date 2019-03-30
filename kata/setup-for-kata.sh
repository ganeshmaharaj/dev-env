#!/bin/bash

set -o errexit
set -o nounset

# Global Vars
: ${GO_VER:=""}
: ${ARCH:=$(arch)}
crio_ver=$(curl -fsSLI -o /dev/null -w %{url_effective} https://github.com/containerd/containerd/releases/latest | awk -F '/' '{print $8}')
: ${CRIO_VER:=${crio_ver#v}}
source /etc/os-release
DEBIAN_FRONTEND=noninteractive

function install_kata()
{
  case "$ID" in
  "ubuntu"*)
    echo "Installing for Ubuntu..."
    sudo sh -c "echo 'deb http://download.opensuse.org/repositories/home:/katacontainers:/releases:/${ARCH}:/master/xUbuntu_$(lsb_release -rs)/ /' > /etc/apt/sources.list.d/kata-containers.list"
    curl -sL  http://download.opensuse.org/repositories/home:/katacontainers:/releases:/${ARCH}:/master/xUbuntu_$(lsb_release -rs)/Release.key | sudo apt-key add -
    sudo -E apt-get update
    sudo -E apt-get -y install kata-runtime kata-proxy kata-shim
    ;;
  "fedora")
    echo "Installing for Fedora..."
	  sudo dnf -y install dnf-plugins-core
	  sudo -E dnf config-manager --add-repo "http://download.opensuse.org/repositories/home:/katacontainers:/releases:/${ARCH}:/master/Fedora_${VERSION_ID}/home:katacontainers:releases:${ARCH}:master.repo"
	  sudo -E dnf -y install kata-runtime kata-proxy kata-shim
    ;;
  "debian")
    echo "Installing for Debian..."
    sudo sh -c "echo '# for unstable packages
deb http://ftp.debian.org/debian/ unstable main contrib non-free
deb-src http://ftp.debian.org/debian/ unstable main contrib non-free' > /etc/apt/sources.list.d/unstable.list"
    sudo sh -c "echo 'Package: *
Pin: release a=unstable
Pin-Priority: 10' >> /etc/apt/preferences.d/unstable"
    [ "$ID" = debian ] && [ -z "$VERSION_ID" ] && echo >&2 "ERROR: Debian unstable not supported.
    You can try stable packages here:
    http://download.opensuse.org/repositories/home:/katacontainers:/releases:/${ARCH}:/master" && exit 1
    sudo sh -c "echo 'deb http://download.opensuse.org/repositories/home:/katacontainers:/releases:/${ARCH}:/master/Debian_${VERSION_ID}/ /' > /etc/apt/sources.list.d/kata-containers.list"
    curl -sL  http://download.opensuse.org/repositories/home:/katacontainers:/releases:/${ARCH}:/master/Debian_${VERSION_ID}/Release.key | sudo apt-key add -
    sudo -E apt-get update
    sudo -E apt-get -y install kata-runtime kata-proxy kata-shim
    ;;
  *)
    echo "OS not supported"
    exit 1
    ;;
esac
}

function install_golang()
{
  if [ -z "${GO_VER}" ]; then
    GO_URL=$(curl -s https://golang.org/dl/#stable | grep 'linux-amd64' | grep downloadBox | awk -F '"' '{print $4}')
  else
    GO_URL=$(curl -s https://golang.org/dl/#stable | grep 'linux-amd64' | grep ${GO_VER} | head -1 | awk -F '"' '{print $6}')
  fi
  # Clean old stuff
  sudo rm -rf /usr/local/go
  curl ${GO_URL} | sudo tar -C /usr/local -xzf -
}

function install_containerd()
{
  curl https://storage.googleapis.com/cri-containerd-release/cri-containerd-${CRIO_VER}.linux-amd64.tar.gz | sudo tar -C / -xzf -
  sudo mkdir -p /etc/containerd
}

function set_env_vars() {
  echo 'export GOPATH=$HOME/go' >> $HOME/.bashrc
  echo 'export GOBIN=$GOPATH/bin' >> $HOME/.bashrc
  echo 'export PATH=/usr/local/go/bin:$PATH:$GOBIN' >> $HOME/.bashrc
}

install_golang
install_kata
install_containerd
set_env_vars
