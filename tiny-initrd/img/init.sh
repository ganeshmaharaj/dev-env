#!/bin/sh

#mount -t proc none /proc
#mount -t devtmpfs none /dev
#mount -t sysfs none /sys
#mount -t debugfs none /sys/kernel/debug

if [ -e /etc/motd ]; then
  cat /etc/motd
fi

echo ""
echo "Booting tiny init system"
echo ""

exec /bin/sh -i

echo ""
echo "Shutting down tiny init system"
echo ""

#umount  /proc
#umount /sys/kernel/debug
#umount /sys
#umount /dev
