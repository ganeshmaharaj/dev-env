#!/bin/bash

set -o nounset
set -o errexit

: {INITRD:-}
: {KERNELIMG:-}

function usage() {
  if [[ $? -ne 0 ]]; then
    echo ""
    echo "${0} <initrdimage> <kernelimage>"
    echo ""
    exit 1
  fi
}

trap usage EXIT

if [[ ! -z "${1}" ]]; then
  INITRD="${1}"
fi

if [[ ! -z "${2}" ]]; then
  KERNELIMG="${2}"
fi

qemu-system-x86_64 \
  -name "tiny-initrd" \
  -enable-kvm -cpu host \
  -cpu host -smp sockets=1,cpus=2,cores=2,threads=1 \
  -m 2048 \
  -vga none -display none \
  -serial stdio -append  "console=ttyS0" \
  -initrd ${INITRD} \
  -kernel ${KERNELIMG}
