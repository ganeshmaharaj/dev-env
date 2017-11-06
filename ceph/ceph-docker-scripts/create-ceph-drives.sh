#!/bin/bash
set -e

DISK_NAME=${DISK_NAME:=ceph-disk}
MOUNT_DIR=${MOUNT_DIR:="`pwd`"}
DISK_SIZE=${DISK_SIZE:="10G"}
DISKS=${DISKS:=1}

function usage()
{
	echo ""
	echo "Script to create make drives for ceph"
	echo "Usage: ${0} [-n | --name] [-s | --size] [-m | --mount] [-c|--count] [-h|--help]"
	echo ""
	echo "	n|name: name of the fake ceph disk"
	echo "	s|size: Size of the fake ceph disk"
	echo "	m|mount: Mount point for the disk"
	echo "	c|count: No. of ceph disks"
	echo "	h|help: Show usage"
	echo ""
	exit 1
}

ARGS=$(getopt -o n:s:m:c:h -l name:,size:,mount:,help,count: -- "$@");
if [ $? -ne 0 ]; then usage; fi
eval set -- "$ARGS"
while true; do
	case "$1" in
		-n|--name)DISK_NAME="$2"; shift 2;;
		-s|--size)DISK_SIZE="$2"; shift 2;;
		-m|--mount)MOUNT_DIR="$2"; shift 2;;
		-c|--count)DISKS="$2"; shift 2;;
		-h|--help)usage; break;;
		--)shift; break;;
		*)usage;;
	esac
done

function create_disks()
{
	echo "Starting disk creation"
	for i in $(eval echo {1..${DISKS}})
	do
		echo "Creating disk ${i}..."
		truncate -s ${DISK_SIZE} ${DISK_NAME}-${i}
		sudo mkfs.xfs ${DISK_NAME}-${i}
		if [ ! -d "${MOUNT_DIR}/c-disk-${i}" ]
		then
			mkdir -p ${MOUNT_DIR}/c-disk-${i}
		fi
		sudo mount ${DISK_NAME}-${i} ${MOUNT_DIR}/c-disk-${i}
	done
	echo "Disks created"
}

create_disks
