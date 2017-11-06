==========================
Notes on using ceph-deploy
==========================

Scratch notes for using ceph-deploy

Fresh Install
=============
We will assume hostname to be cephaio for this doc. Replace it as you need.

* Setup the system to install packages

	* Install the latest lttng if you ever need it from ppa
	```
	sudo add-apt-repository ppa:lttng/ppa
	sudo apt-get update
	sudo apt-get install lttng-tools liblttng-ust0
	```

	* Download the packages if you have a mirror somewhere and want to use that
	against upstream

	```
	ceph install --repo-url=<URL> cephaio
	```
		(or)
	```
	ceph new cephaio
	```

	* Continue with the rest of the process
	```
	# Create initial monitor
	ceph-deploy mon create-initial

	# if aboe fails, below two will help
	ceph-deploy mon create
	sudo ceph-create-keys --verbose --id cephaio

	#Find disks that will run OSD
	ceph-deploy disk zap cephaio:<disk>

	#Setup OSD
	ceph-deploy osd prepare cephaio:<disk>:<journal>
	ceph-deploy osd activate cephaio:<disk partition>:<journal>

	#setup admin user for machine
	ceph-deploy admin cephaio

	# This is very very bad in production
	sudo chmod +r /etc/ceph/ceph.client.admin.keyring
	```
