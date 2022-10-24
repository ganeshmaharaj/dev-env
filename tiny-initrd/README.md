# Tiny initramfs
Set of scripts that helps one create a tiny initramfs that can be used to boot a kernel inside qemu to validate, check if qemu works, or just for giggles.

We have enabled two types of images.  (a)Super small one using toybox (b) alpine rootfs based image.

## Pre-requisites
1. Download latest toybox binary (http://landley.net/toybox/about.html) or alpine mini root filesystem (https://alpinelinux.org/downloads/)
2. make sure `cpio` and `zstd` are installed in the system.
3. A kernel `bzImage` of choice.

## Steps
1. `make_initrd.sh` [Creates the init ramfs.  Defaults  toybox. You can choose ALPINE by setting TYPE=alpine]
2. `boot_img.sh <initrd> <kernel>` [boots the image with the given initrd and kernel]
