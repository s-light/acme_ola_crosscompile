#!/bin/sh

sudo cp /usr/bin/qemu-arm-static target-rootfs/usr/bin
sudo mount -o bind /dev/ target-rootfs/dev/
sudo LC_ALL=C LANGUAGE=C LANG=C chroot target-rootfs /bin/bash
