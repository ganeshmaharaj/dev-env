Repository to host scripts related to ceph
===================

This repository contains
1. Vagrant VM script to run a vstart env
2. Docker env for vstart
3. Docker env to create deb/rpm packages for a limited set of distros

* * *

Docker for Deb/Rpm Package
--------------------------
The script will crate deb/rpm packages for the below OS

 * Ubuntu 16.04/14.04
 * Fedora 25
 * Centos 7

 * * *

Vagrant VM
----------
A simple vagrant script to run 'vstart.sh' from ceph source compiled on host

### Host Changes
Script uses NFS mounting of the ceph source directory to guest.
Install ``nfs-common`` and ``nfs-kernel-server`` in ubuntu or the
equivalent packages in other distributions

### Configurations

#### Required
##### ``CEPH_SRC_DIR``

This tells Vagrant where the ceph source folder is. You should have compiled
Ceph in this space. If you are using the new build system ``cmake``, make sure
you have completed ``make vstart`` before invoking the vagrant script.
###### Default Value: ``../ceph`` (Relative to the git repository)

#### Optional
##### ``CEPH_MON``, ``CEPH_MDS``, ``CEPH_OSD``

The number of monitors, mds and osd you would like vagrant to spawn
respectively.. Will use the script default if not set.
