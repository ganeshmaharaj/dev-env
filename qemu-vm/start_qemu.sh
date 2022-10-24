#!/bin/bash

: ${IMAGE:=""}
: ${FORMAT:="qcow2"}
: ${DISPLAY:=" -vga none -display none "}

function usage() {
  echo ""
  echo "${0} [-v|--vnc] [-i|--image] [-h|--help]"
  echo ""
  echo "v|vnc: Use vnc port for display"
  echo "i|image: Image to boot"
  echo "h|help: Print this"
  echo ""
  exit 1
}

ARGS=$(getopt -o vi:h -l vnc,image:,help -- "$@")

if [ $? -ne 0 ];  then usage; fi

eval set -- "${ARGS}"

while true; do
  case "$1" in
    -v|--vnc) DISPLAY=" -vnc 0.0.0.0:21 "; shift;;
    -i|--image) IMAGE="$2"; shift 2;;
    -h|--help)  usage;;
    --)  shift; break;;
    *)usage;;
  esac
done

if [[ "${IMAGE}" == "" ]]; then
  echo "Image not found"
  exit 1
fi

FORMAT=$(qemu-img info $IMAGE | grep 'file format' | awk -F ': ' '{print $2}')

# Hard-coding a lot of the bits for this revision. This script will eventually
# grow  to do things better.
#  -bios /data/workspace/clr-vm/bios.bin-1.16.0 \

qemu-system-x86_64 \
  -enable-kvm \
  -smp sockets=1,cpus=4,cores=4,threads=1 -cpu host \
  -m 4096 \
  -monitor pty -daemonize \
  -drive file=/usr/share/qemu/OVMF_CODE.fd,if=pflash,format=raw,unit=0,readonly=on \
  -drive file=/usr/share/qemu/OVMF_VARS.fd,if=pflash,format=raw,unit=1,readonly=on \
  ${DISPLAY} \
  -drive file="${IMAGE}",if=virtio,aio=threads,format=${FORMAT},cache=none \
  -drive if=virtio,format=raw,file=xorriso-cloud-init.img,file.locking=off \
  -netdev user,id=mynet0,hostfwd=tcp::30022-:22 \
  -device virtio-net-pci,netdev=mynet0 \
  -serial telnet:localhost:2345,server,nowait \

