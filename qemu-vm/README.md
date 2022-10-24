# qemu-vm scripts
Scripts and accessories that helps one spin up QEMU VMs off cloud images created by Linux distributions.

## Pre-requisite
1. Install qemu, kvm and supporting packages in your system.
2. Make sure OVMF files are installed and available at `/usr/share/qemu`

### How-To
1. Download the cloud image of your choice. The script has been tested with the below list.
    1. Debian Sid (http://cloud.debian.org/images/cloud/sid/daily/latest/debian-sid-generic-amd64-daily.qcow2)
    2. Ubuntu Jammy (https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img)
    3. Rocky Linux (https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-9.0-20220830.0.x86_64.qcow2)
    4. Alma Linux  (https://mirrors.radwebhosting.com/almalinux/9.0/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2)
    5. Fedora 36 (https://download.fedoraproject.org/pub/fedora/linux/releases/36/Cloud/x86_64/images/Fedora-Cloud-Base-36-1.5.x86_64.qcow2)

2. `start_qemu.sh -i <image>`
3. Login as `test` with password `buildmach`
    a. `ssh -i <key> -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no  -p 30022 test@localhost`

## Supporting bits

### Create cloud-init
1. Make sure you have `cloud-localds` or `xorriso` package in your system. You can use  one of the below options  to create  the cloud-init image.
    a. `cloud-localds cloud-init.img user-data`
    b. `xorriso -as mkisofs -o ./xorriso-cloud-init.img -volid cidata -joliet -rock user-data meta-data`
2.  You can add your own public keys in the `ssh_authorized_keys` list and should be able to ssh using it.
