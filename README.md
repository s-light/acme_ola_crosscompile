# How to compile OLA for ACME boards
https://github.com/s-light/acme_ola_crosscompile

07.02.2016 18:42 s-light   
goal: cross-compile ola for the ACME Aria & Arietta boards.
(tested with Aria G25; for other board there may be modifications needed...)


setup everything like explained in the official ACME-tutorials:   
--> [Building a Debian Jessie Linux distribution](http://www.acmesystems.it/tutorials)   
this guide is heavily based on the original tutorials.

1. [Format the microSD](http://www.acmesystems.it/microsd_format)
2. Compile AT91bootstrap from the sources [3.7](http://www.acmesystems.it/compile_at91bootstrap)
3. Build the rootfs from the Debian binary repositories [Jessie](http://www.acmesystems.it/debian_jessie)
4. Compile the Kernel from the sources [4.4.1](http://www.acmesystems.it/compile_linux_4_4)

i will shortly summarize all steps here:

## 1. Format the (micro)SDCard:   
You need two partitions on the card for Linux to be able to boot:
* a small FAT16 for the bootloader and device-tree
* a big EXT4 for the root file system
```
id  type     Label      Size
1   FAT16    boot       128MB
2   EXT4     rootfs     >800MB
```

## 2. Compile AT91bootstrap:
follow the original procedure: http://www.acmesystems.it/compile_at91bootstrap   
if you get to the step of 'Launch the compilation' we have a small modification:  
this only works with gcc 4.7 but on my system (kubuntu 15.10) i had gcc 5.x installed.  
thanks to [Giulio Gaio](https://groups.google.com/d/msg/acmesystems/mAViwYA_bow/tum1WDJYEgAJ) for a workaround:  
additionally install the 4.7 packages:  
```
sudo apt-get install arm-linux-gnueabi-gcc-4.7
sudo apt-get install arm-linux-gnueabi-g++-4.7
```
then you can create a alternative option to use one of the two installed:
```
sudo update-alternatives --install /usr/bin/arm-linux-gnueabi-gcc arm-linux-gnueabi-gcc /usr/bin/arm-linux-gnueabi-gcc-4.7 10 --slave /usr/bin/arm-linux-gnueabi-g++ arm-linux-gnueabi-g++ /usr/bin/arm-linux-gnueabi-g++-4.7
sudo update-alternatives --install /usr/bin/arm-linux-gnueabi-gcc arm-linux-gnueabi-gcc /usr/bin/arm-linux-gnueabi-gcc-5 20 --slave /usr/bin/arm-linux-gnueabi-g++ arm-linux-gnueabi-g++ /usr/bin/arm-linux-gnueabi-g++-5
```
now you can switch between the two with:  
```shell
$ sudo update-alternatives --config arm-linux-gnueabi-gcc
There are 2 choices for the alternative arm-linux-gnueabi-gcc (providing /usr/bin/arm-linux-gnueabi-gcc).

  Selection    Path                                Priority   Status
------------------------------------------------------------
* 0            /usr/bin/arm-linux-gnueabi-gcc-5     20        auto mode
  1            /usr/bin/arm-linux-gnueabi-gcc-4.7   10        manual mode
  2            /usr/bin/arm-linux-gnueabi-gcc-5     20        manual mode

Press <enter> to keep the current choice[*], or type selection number: 0
```

with this setup you now can switch to the 4.7 version.
than run `$ make CROSS_COMPILE=arm-linux-gnueabi-`
and after this just switch back to auto or force 5.  
than just follow the final step from the guide. (copy the bin to the card.)




## 3. Build the rootfs:    

first install all needed packages.
```shell
~$ sudo apt-get install multistrap qemu qemu-user-static binfmt-support dpkg-cross
```
create your working dir
```shell
~$ mkdir debian_jessie
~$ cd debian_jessie
~/debian_jessie$
```
download the [multistrap_ola.conf](multistrap_ola.conf) i have prepared.
it is based on the Aria (and commented out Arietta) conf and extended to also include all packages from the ola dependencies list plus some helpers.
```shell
~/debian_jessie$ sudo multistrap -a armel -f multistrap_ola.conf
```

no we prepare our emulated target:
```shell
~/debian_jessie$ sudo cp /usr/bin/qemu-arm-static target-rootfs/usr/bin
~/debian_jessie$ sudo mount -o bind /dev/ target-rootfs/dev/
```
first configure dpkg
```shell
~/debian_jessie$ sudo LC_ALL=C LANGUAGE=C LANG=C chroot target-rootfs dpkg --configure -a
```
go through the configuration as you like -
the acme tutorial states you should choose `NO` at 'Use dash as default system shell (/bin/sh)?'.
if this process is finished there are some default config settings to do:
```shell
~/debian_jessie$ ./configs_ola.sh
```
(this sets up some default configs like network, hostname, ...)
now we can enter the chroot session:
```shell
~/debian_jessie$ sudo LC_ALL=C LANGUAGE=C LANG=C chroot target-rootfs /bin/bash
root@username:/#
```
so you have a shell that works in your target-rootfs - and also all commands are emulated by qemu in this environment.

first set the root password:
```shell
root@username:/# echo "root:acmes" | chpasswd
```
then we add user:
```shell
root@username:/# adduser light --disabled-password
root@username:/# echo "light:sun" | chpasswd
```
(these command are usable for scripting the actions..)
now it makes sens to add the new user to some of the io related groups:
```shell
root@username:/# usermod -aG  sudo light
root@username:/# usermod -aG  plugdev light
root@username:/# usermod -aG  dialout light
root@username:/# usermod -aG  i2c light
```
allow ssh login to root
```shell
root@username:/# sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/i' etc/ssh/sshd_config
```
other things to do??
for example install some python packages:
```shell
root@username:/# pip install spidev
```
if you have your work done exit the shell and remove the qemu emulator:
```shell
root@username:/# exit
~/debian_jessie$ sudo rm target-rootfs/usr/bin/qemu-arm-static
```
as last step you now can copy your new target-rootfs to the sd card:
```shell
~/debian_jessie$ sudo rsync -axHAX --progress target-rootfs/ /media/$USER/rootfs/
```



## 4. Compile the Kernel:  
```shell
~/linux-4.4.1$ make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- acme-aria_defconfig
```
check that 'User mode SPI support' is active:
```shell
~/linux-4.4.1$ make ARCH=arm menuconfig
-> Device Drivers
    -> [*] SPI Support
        -> <*> Atmel SPI
        -> <*> User mode SPI support
```
```shell
~/linux-4.4.1$ make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- acme-aria.dtb
```
```shell
~/linux-4.4.1$ make -j8 ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- zImage
```
```shell
~/linux-4.4.1$ cp arch/arm/boot/dts/acme-aria.dtb /media/$USER/boot/at91-ariag25.dtb
~/linux-4.4.1$ cp arch/arm/boot/zImage /media/$USER/boot
#or
~/linux-4.4.1$ scp arch/arm/boot/dts/acme-aria.dtb light@aria.local:/media/mmc_p1/at91-ariag25.dtb
```

# now compile your application:
this basically follows the original [Linux install guide](https://www.openlighting.org/ola/linuxinstall/).

prepare the chroot
```shell
~/debian_jessie$ sudo cp /usr/bin/qemu-arm-static target-rootfs/usr/bin
~/debian_jessie$ sudo mount -o bind /dev/ target-rootfs/dev/
```
enter the chroot session:
```shell
~/debian_jessie$ sudo LC_ALL=C LANGUAGE=C LANG=C chroot target-rootfs /bin/bash
root@username:/#
```

first let us clone the ola repository:
```shell
root@username:/# cd /home/light/
root@username:/home/light# git clone https://github.com/OpenLightingProject/ola.git ola
root@username:/home/light# cd ola
root@username:/home/light/ola#
```
as first step run autoreconf (and for the first time with `-i` to install all missing files)
```shell
root@username:/home/light/ola# autoreconf -i
```
now you can configure your build-options. for a overview try `./configure --help`.  
here is a 'relative small' config with only the plugins i needed..
```shell
root@username:/home/light/ola# ./configure --enable-python-libs --disable-all-plugins --enable-dummy --enable-e131 --enable-spi --enable-usbpro --enable-artnet
```
then just run make (with the -j option followed by the numbers of cores)
```shell
root@username:/home/light/ola# make -j 8
```
for me this took about 45min - i think the long time comes from the emulation..  
if it is ready install it and make the new libs accessible
```shell
root@username:/home/light/ola# make install
root@username:/home/light/ola# ldconfig
```
now you can give it a test-run:
```shell
root@username:/home/light/ola# olad -l3
```
olad should start up.(on an emulated arm hw ;-) )

if you have your work done exit the shell and remove the qemu emulator:
```shell
root@username:/# exit
~/debian_jessie$ sudo rm target-rootfs/usr/bin/qemu-arm-static
```
now copy your rootfs to the sd-card and test it:
```shell
~/debian_jessie$ sudo rsync -axHAX --progress target-rootfs/ /media/$USER/rootfs/
```
