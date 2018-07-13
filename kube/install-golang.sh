#!/bin/bash -x
set -e

GO_VER="1.10"

function apt_install() {
  sudo add-apt-repository -y ppa:gophers/archive
  sudo apt update
  sudo apt install -y golang-${GO_VER}
}

function install_golang() {
  GO_URL=$(curl -s https://golang.org/dl/#stable | grep 'linux-amd64' | grep downloadBox | awk -F '"' '{print $4}')
  curl ${GO_URL} | sudo tar -C /usr/local -xzf -
}

function set_env_vars() {
  echo 'export GOPATH=$HOME/go' >> $HOME/.bashrc
  echo 'export GOBIN=$GOPATH/bin' >> $HOME/.bashrc
  echo 'export PATH=/usr/local/go/bin:$PATH:$GOBIN' >> $HOME/.bashrc
}

install_golang
set_env_vars
