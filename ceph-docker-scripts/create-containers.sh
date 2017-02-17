#!/bin/bash
set -e

# Common Variables
COUNT=${COUNT:=1}
SERVICE=""
NAME=${NAME}
CEPH_DEV_DIR=${CEPH_DEV_DIR}
CEPH_DOCKER_DAEMON=${CEPH_DOCKER_DAEMON:="ceph/daemon:latest"}
CEPH_ETC=${CEPH_ETC:="/etc/ceph"}
CEPH_VAR=${CEPH_VAR:="/var/lib/ceph"}

# MON
HNAME=${HNAME:="`hostname -s`"}
MON_IP=${MON_IP}
CEPH_PUB_NETWORK=${CEPH_PUB_NETWORK}

# OSD
MON_NAME=${MON_NAME}

function usage()
{
	echo ""
	echo "Script to create monitors"
	echo "Usage: ${0} [-s|--service] [-c|--count] [-t|--hostname] [-m|--mon-name] [-n|--name] [-d|--ceph-dir] [-i|--mon-ip] [-p|--pub-network] [-o|--docker-daemon]"
	echo ""
	echo "	s|service: What service to run. Options are osd,mon"
	echo "	c|count: No. of services to start"
	echo "	n|name: Name of the service container"
	echo "	d|ceph-dir: Fake ceph drive, if any"
	echo "	o|docker-daemon: Docker daemon container"
	echo "	h|help: Show usage"
	echo ""
	echo "		ONLY FOR MONITORS"
	echo "	t|hostname: HNAME to be passed to container"
	echo "	i|mon-ip: IP to be used on the MON"
	echo "	p|pub-network: ceph public network"
	echo ""
	echo "		ONLY FOR OSDs"
	echo "	m|mon-name: Name of the monitor container."
	echo ""
	exit 1
}

ARGS=$(getopt -o s:c:m:n:d:t:i:p:o:h -l service:,mon-name:,count:,hostname:,name:,ceph-dir:,mon-ip:,pub-network:,docker-daemon:,help -- "$@");
if [ $? -ne 0 ]; then usage; fi
eval set -- "$ARGS"
while true; do
	case "$1" in
		-s|service)SERVICE="${2,,}"; shift 2;;
		-c|count)COUNT="$2"; shift 2;;
		-m|mon-name)MON_NAME="$2"; shift 2;;
		-n|name)NAME="$2"; shift 2;;
		-d|ceph-dir)CEPH_DEV_DIR="$2"; shift 2;;
		-o|docker-daemon)CEPH_DOCKER_DAEMON="$2"; shift 2;;
		-t|hostname)HNAME="$2"; shift 2;;
		-i|mon-ip)MON_IP="$2"; shift 2;;
		-p|pub-network)CEPH_PUB_NETWORK="$2"; shift 2;;
		-h|--help)usage; break;;
		--)shift; break;;
		*)usage;;
	esac
done

# Check the mandatory stuff first
if [ -z "${SERVICE}" ]; then
	echo "Need what service to start. Options are osd,mon"
   	usage
fi
if [ "${SERVICE}" == "mon" ]; then
	if [ -z "${MON_IP}" ] || [ -z "${CEPH_PUB_NETWORK}" ]; then
		echo "Need IP monitor will use and info on ceph's public network"
		usage
	fi
elif [ "${SERVICE}" == "osd" ]; then
	if [ -z "${MON_NAME}" ]; then
		echo "Need monitor container name to register OSDs."
	fi
else
	echo "SERVICE can be only one of these options."
	echo "mon, osd"
	exit 1
fi

# Now to set the things we need to set
if [ -z "${NAME}" ]; then
	NAME="ceph-${SERVICE}"
fi

if [ -n "${CEPH_DEV_DIR}" ]; then
	CEPH_ETC=${CEPH_DEV_DIR%%\/}/${CEPH_ETC}
	CEPH_VAR=${CEPH_DEV_DIR%%\/}/${CEPH_VAR}
fi

function create_mons()
{
	for i in $(eval echo {1..${COUNT}}); do
		echo "Creating mon ${NAME}-${i}..."
		docker run -d --name "${NAME}-${i}" \
			--net=host \
			-e HNAME="${HNAME}-${i}" \
			-e MON_IP="${MON_IP}:4000${i}" \
			-e CEPH_PUBLIC_NETWORK="${CEPH_PUB_NETWORK}" \
			-v ${CEPH_ETC}:/etc/ceph \
			-v ${CEPH_VAR}:/var/lib/ceph \
			${CEPH_DOCKER_DAEMON} mon
	done
}

function create_osds()
{
	# Find the last OSD_ID created and find IDs for this run
	last_osd_id=$(docker exec ${MON_NAME} ceph osd ls | tail -1)
	if [[ "$last_osd_id" =~ ^[0-9]+$ ]]; then
		osd_start=$(( last_osd_id + 1 ))
		osd_end=$(( last_osd_id + COUNT ))
	else
		osd_start=0
		osd_end=$(( COUNT - 1 ))
	fi

	# Create all the auxiliary stuff you need for the OSD containers
	# Need to use sudo given that the CEPH_DEV_DIR is/will be owned by root
	for i in $(eval echo {${osd_start}..${osd_end}}); do
		sudo mkdir -p ${CEPH_VAR}/osd/${i}
		sudo chown -R ceph. ${CEPH_VAR}/osd/${i}
	done

	#Create first OSD on host
	ret=$(docker exec ${MON_NAME} ceph osd create)
	if [ "${ret}" -eq "${osd_start}" ]; then
		docker run -d --name ${NAME}-${osd_start} --net=host \
		-e OSD_ID=${osd_start} \
		-v ${CEPH_ETC}:/etc/ceph \
		-v ${CEPH_VAR}/osd/${osd_start}:/var/lib/ceph/osd/ceph-${osd_start} \
		-v ${CEPH_VAR}/bootstrap-osd:/var/lib/ceph/bootstrap-osd \
		${CEPH_DOCKER_DAEMON} osd
   	else
	   	echo "Something wrong."
   	fi

	#Find if the first OSD is running
	sleep 10
	ret=$(docker ps -a --filter name=${NAME}-${osd_start} --format="{{.Status}}" | cut -d ' ' -f1)
	if [ "${ret,,}" != "up" ]; then
		echo "Something went wrong with the first contianer. Check logs"
		exit 1
	fi

	#Run other containers
	for ((i=$((osd_start+1)); i<=${osd_end}; i++)); do
		ret=$(docker exec ${MON_NAME} ceph osd create)
		if [ "${ret}" -ne "${i}" ]; then
			echo "Ceph cluster is reporting a different OSD number compared to what we expect"
			exit 1
		fi
		docker run -d --name ${NAME}-${i} --net=host \
		--pid=container:${NAME}-${osd_start} \
		-e OSD_ID=${i} \
		-v ${CEPH_ETC}:/etc/ceph \
		-v ${CEPH_VAR}/osd/${i}:/var/lib/ceph/osd/ceph-${i} \
		-v ${CEPH_VAR}/bootstrap-osd:/var/lib/ceph/bootstrap-osd \
		${CEPH_DOCKER_DAEMON} osd
	done
}
if [ "${SERVICE}" == "mon" ]; then
	create_mons
elif [ "${SERVICE}" == "osd" ]; then
	create_osds
else
	echo "Apparently something is wrong and i cannot do anything"
fi
