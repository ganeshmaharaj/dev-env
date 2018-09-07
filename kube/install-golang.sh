#!/bin/bash -x
set -e

function apt_install() {
  sudo add-apt-repository -y ppa:gophers/archive
  sudo apt update
  sudo apt install -y golang-${GO_VER}
}

function install_golang() {
  if [ -z "${GO_VER}" ]; then
    GO_URL=$(curl -s https://golang.org/dl/#stable | grep 'linux-amd64' | grep downloadBox | awk -F '"' '{print $4}')
  else
    GO_URL=$(curl -s https://golang.org/dl/#stable | grep 'linux-amd64' | grep ${GO_VER} | head -1 | awk -F '"' '{print $6}')
  fi
  # Clean old stuff
  sudo rm -rf /usr/local/go
  curl ${GO_URL} | sudo tar -C /usr/local -xzf -
}

function set_env_vars() {
  echo 'export GOPATH=$HOME/go' >> $HOME/.bashrc
  echo 'export GOBIN=$GOPATH/bin' >> $HOME/.bashrc
  echo 'export PATH=/usr/local/go/bin:$PATH:$GOBIN' >> $HOME/.bashrc
}

install_golang
set_env_vars
