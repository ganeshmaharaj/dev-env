===================
Ceph Dev Testing VM
===================

A simple vagrant script to run 'vstart.sh' from ceph source compiled on host

Configurations
==============

Required
--------
### ``CEPH_SRC_DIR``

This tells Vagrant where the ceph source folder is. You should have compiled
Ceph in this space. If you are using the new build system ``cmake``, make sure
you have completed ``make vstart`` before invoking the vagrant script.
#### Default Value: ``../ceph`` (Relative to the git repository)

Optional
--------
### ``CEPH_MON``, ``CEPH_MDS``, ``CEPH_OSD``

The number of monitors, mds and osd you would like vagrant to spawn
respectively.. Will use the script default if not set.
