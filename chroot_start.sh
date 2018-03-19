#!/bin/bash

##########################################
# prepare

# copy qemu binary
sudo cp /usr/bin/qemu-arm-static target-rootfs/usr/bin

# bind host things so chroot can use theme
## this call binds successfully
## but if you exit the chroot this produces a broken /dev....
# sudo mount -o bind /dev/ target-rootfs/dev/
# this works better:
sudo mount --rbind /dev target-rootfs/dev/
sudo mount --make-rslave target-rootfs/dev/
# source: https://unix.stackexchange.com/questions/263972/unmount-a-rbind-mount-without-affecting-the-original-mount/264488#264488


##########################################
# start chroot
sudo LC_ALL=C LANGUAGE=C LANG=C chroot target-rootfs /bin/bash
# https://www.gnu.org/software/coreutils/manual/html_node/chroot-invocation.html
# sudo LC_ALL=C LANGUAGE=C LANG=C chroot --userspec=light target-rootfs /bin/bash
# this seems to not work as expected.

# switch user to our default target user
# sudo su light
# and his home directory
# cd ~

##########################################
# we have exited the chroot...
# clean up

# check user
# echo $USER

# remove previous mounted things
sudo umount -R target-rootfs/dev/

# remove qemu binary
sudo rm target-rootfs/usr/bin/qemu-arm-static
