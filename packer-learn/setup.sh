#!/bin/bash

set -o errexit
set -o xtrace
set -o nounset

source /usr/lib/os-release

function deb_pkg_install()
{
  sudo apt update
  sudo apt install -y fio
}

function dnf_pkg_install()
{
  sudo dnf install -y fio
}

function zypper_pkg_install()
{
  sudo zypper install -y fio
}

case "$ID" in
  "ubuntu"*|"debian"*)
    deb_pkg_install;;
  "centos"|"fedora"*)
    dnf_pkg_install;;
  *"suse"*)
    zypper_pkg_install;;
  *)
    echo "Unknown OS. No provisioning will happen";;
esac
