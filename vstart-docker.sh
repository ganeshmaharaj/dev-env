#!/bin/bash
set -e

#####################
#
# Script to run ceph vstart inside container
# Author: Ganesh Mahalingam
#
#####################

# Defaults
SRC=""
OS=""
REL=""
CONT_ARGS=""
CONT_NAME=""
WD=`pwd`
DIMG=""
DMOUNT=""
OP=""

function usage()
{
	echo ""
	echo "Usage: ${0} [-s|--source]"
	echo ""
	echo "-s|--source:	Location of the source ceph repo"
	echo "-d|--delete:	Delete container and associated files"
	echo ""
	exit 1
}

ARGS=$(getopt -o s:d:h -l source:,delete:,help -- "$@");
if [ $? -ne 0 ]; then usage; fi
eval set -- "$ARGS"
while true; do
	case "$1" in
	-s|--source) OP="CREATE"; SRC=$2; shift 2;;
	-d|--delete) OP="DELETE"; CONT_NAME=$2; shift 2;;
	-h|--help) usage; break;;
	--)shift; break;;
	*) usage;;
	esac
done

if [ "${OP}" == "CREATE" ] && [ -z "${SRC}" ]; then
	echo "Need source dir to run vstart"
	usage
fi

if [ "${OP}" == "DELETE" ] && [ -z "${CONT_NAME}" ]; then
	echo "Need container name to delete"
	usage
fi

function populate_stuff()
{
	# Sanitize SRC data
	SRC=${SRC%/}

	# Find OS and release of the build machine. We are assuming that this is
	# being run on the same machine code was built on and sticking to the same
	# image for the build to avoid random issues.
	OS=$(lsb_release -is) || (echo "Unable to run lsb_release"; exit 1)
	REL=$(lsb_release -rs) || (echo "Unable to run lsb_release"; exit 1)
	CONT_NAME="${OS,,}-${REL}-vstart-${SRC##*/}"
	CONT_ARGS+=" --name ${CONT_NAME} "

	# Find other env settings
	if [ -n "${http_proxy}" ]; then
		echo "Proxy detected. Adding those to container args"
		CONT_ARGS+="-e http_proxy=${http_proxy} \
			-e https_proxy=${https_proxy} \
			-e no_proxy=${no_proxy} "
	fi

	DIMG="c-disk-${SRC##*/}"
	DMOUNT="ceph-disk-${SRC##*/}"

	# Setup disk for use as CEPH_DEV_DIR
	truncate -s 1G ${WD}/${DIMG}
	mkfs.xfs ${WD}/${DIMG}
	mkdir -p ${WD}/${DMOUNT}
	sudo mount -t xfs ${WD}/${DIMG} ${WD}/${DMOUNT}
	sudo chmod 777 ${WD}/${DMOUNT}

	# Add source and ceph-disk as mounts to container
	CONT_ARGS+="-v ${SRC}:${SRC} -v ${WD}/${DMOUNT}:/data/ceph-disk "
}

function run_container()
{
	# Start container
	docker run -it -d ${CONT_ARGS} ${OS,,}:${REL} bash
	if [ "${USER}" != "root" ]; then
		docker exec -it ${CONT_NAME} bash -c \
			"adduser --disabled-password --gecos '' ${USER}"
	fi

	# Fix up the container
	docker exec -it ${CONT_NAME} apt-get update
	docker exec -it ${CONT_NAME} bash -c \
		"cd ${SRC}; ${SRC}/install-deps.sh"

	# Install additional packages since we almost always use them.
	docker exec -it ${CONT_NAME} \
		apt-get install -y libcrypto++*

	# Run vstart
	if [ -d "${SRC}/build" ]; then
		docker exec -it --user ${USER} ${CONT_NAME} bash -c \
			"cd ${SRC}/build; \
			CEPH_DEV_DIR=/data/ceph-disk ${SRC}/src/vstart.sh -d -n -x"
	else
		docker exec -it --user ${USER} ${CONT_NAME} bash -c \
			"cd ${SRC}/src; \
			CEPH_DEV_DIR=/data/ceph-disk ${SRC}/src/vstart.sh -d -n -x"
	fi
}

function delete_container()
{
	# Find drives mounted on host from container
	DMOUNT="`docker inspect -f '{{ range .Mounts}}{{if eq .Destination "/data/ceph-disk" }}{{.Source}}{{end}}{{end}}' $CONT_NAME`"
	DIMG="c-disk-${DMOUNT##*/ceph-disk-}"

	# Delete container
	docker stop ${CONT_NAME}
	docker rm ${CONT_NAME}

	#Unmount and delete files
	sudo umount ${DMOUNT}
	sudo rm -rf ${DMOUNT} ${DIMG}
}

if [ "${OP}" == "CREATE" ]; then
	populate_stuff
	run_container
elif [ "${OP}" == "DELETE" ]; then
	delete_container
fi
