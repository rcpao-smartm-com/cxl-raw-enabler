#!/bin/bash -x


# $UNAME_R is the currently running kernel or the kernel you wish to build
# UNAME_R=$(uname -r)
UNAME_R=6.5.0-21-generic
# UNAME_R=6.5.0-26-generic


# https://wiki.ubuntu.com/Kernel/BuildYourOwnKernel


source /etc/os-release
# VERSION_CODENAME=jammy
echo Uncomment the following lines from /etc/apt/sources.list
echo deb-src http://archive.ubuntu.com/ubuntu ${VERSION_CODENAME} main
echo deb-src http://archive.ubuntu.com/ubuntu ${VERSION_CODENAME}-updates main
# deb-src http://us.archive.ubuntu.com/ubuntu/ \${VERSION_CODENAME} main restricted
sed 's|\# deb-src http:\/\/us\.archive\.ubuntu\.com\/ubuntu\/ '"${VERSION_CODENAME}"' main restricted$|deb-src http:\/\/us\.archive\.ubuntu\.com\/ubuntu\/ '"${VERSION_CODENAME}"' main restricted|' /etc/apt/sources.list > /tmp/sources.list.1.$$
# deb-src http://us.archive.ubuntu.com/ubuntu/ ${VERSION_CODENAME}-updates main restricted
sed 's|\# deb-src http:\/\/us\.archive\.ubuntu\.com\/ubuntu\/ '"${VERSION_CODENAME}"'-updates main restricted$|deb-src http:\/\/us\.archive\.ubuntu\.com\/ubuntu\/ '"${VERSION_CODENAME}"'-updates main restricted|' /tmp/sources.list.1.$$ > /tmp/sources.list.2.$$
[ ! -f /etc/apt/sources.list.original ] && sudo mv -f /etc/apt/sources.list /etc/apt/sources.list.original
sudo cp -f /tmp/sources.list.2.$$ /etc/apt/sources.list
# rm /tmp/sources.list.[12].$$ 

sudo apt-get -y update
sudo apt-get -y build-dep linux linux-image-unsigned-${UNAME_R}

sudo apt-get -y install libncurses-dev gawk flex bison openssl libssl-dev dkms libelf-dev libudev-dev libpci-dev libiberty-dev autoconf llvm

uname -r
apt source linux-image-unsigned-${UNAME_R}

cd linux-hwe-6.5-6.5.0


chmod a+x debian/rules
chmod a+x debian/scripts/*
chmod a+x debian/scripts/misc/*


# https://discourse.ubuntu.com/t/kernel-configuration-in-ubuntu/35857
./debian/scripts/misc/annotations --arch amd64 --flavour generic --export > .config

# cp /boot/config-${UNAME_R} .config # make oldconfig will do this if needed
#make olddefconfig 
# make menuconfig # This is the text based menu config 
# make xconfig # This is the GUI based menu config 
#
# Enable CONFIG_CXL_MEM_RAW_COMMANDS:
# Device Drivers > PCI support > CXL (Compute Express Link) Devices Support > 
#   [*] RAW Command Interface for Memory Devices (default=[_])
sed -e 's/# CONFIG_CXL_MEM_RAW_COMMANDS is not set/CONFIG_CXL_MEM_RAW_COMMANDS=y/' < .config > .config.cxl_raw_y
mv .config.cxl_raw_y .config 
grep CONFIG_CXL_MEM_RAW_COMMANDS .config

./debian/scripts/misc/annotations --arch amd64 --flavour generic --import .config
# find . -name .config
# grep CONFIG_CXL_MEM_RAW_COMMANDS ./debian/build/build-generic/source/.config
grep -R CONFIG_CXL_MEM_RAW_COMMANDS debian*
# debian.hwe-6.5/config/annotations:CONFIG_CXL_MEM_RAW_COMMANDS                     policy<{'amd64': 'y', 'arm64': 'n', 'armhf': 'n', 'ppc64el': 'n', 'riscv64': 'n', 's390x': '-'}>^M
# debian.master/changelog:    - [Config] Disable CONFIG_CXL_MEM_RAW_COMMANDS on riscv64^M
# debian.master/config/annotations:CONFIG_CXL_MEM_RAW_COMMANDS                     policy<{'amd64': 'n', 'arm64': 'n', 'armhf': 'n', 'ppc64el': 'n', 'riscv64': 'n', 's390x': '-'}>^M


fakeroot debian/rules clean

# Must be done before 'fakeroot debian/rules updateconfigs' to rm .config:
# *** The source tree is not clean, please run 'make ARCH=x86 mrproper'
# *** in /home/rcpao/Documents/job/sgh/ubuntu-linux-kernel/6.5.0-26-generic/linux-hwe-6.5-6.5.0
make ARCH=x86 mrproper

# yes n | fakeroot debian/rules editconfigs # you need to go through each (Y, Exit, Y, Exit..) or get a complaint about config later
fakeroot debian/rules updateconfigs

fakeroot debian/rules binary-headers binary-generic binary-perarch
# ./debian/build/build-generic/.config has now been created

# fakeroot debian/rules binary
exit


# https://docs.kernel.org/kbuild/modules.html#targets
# The default will build the module(s) located in the current directory,
# so a target does not need to be specified. All output files will also be
# generated in this directory. No attempts are made to update the kernel
# source, and it is a precondition that a successful “make” has been
# executed for the kernel.
#
# make && make modules_install && make install
# 
#make -j36 clean
make -j36 
make -j36 modules
sudo make modules_install
sudo make install
sudo depmod ${UNAME_R}
#
# make -j36 -C $PWD M=$PWD/drivers/cxl clean
#make -j36 -C $PWD M=$PWD/drivers/cxl modules
#sudo make -j36 -C $PWD M=$PWD/drivers/cxl modules_install
# sudo make -j36 INSTALL_MOD_DIR=cxl-raw -C $PWD M=$PWD/drivers/cxl modules_install
#[ ! -d /lib/modules/${UNAME_R}/kernel/drivers/cxl-original ] && sudo cp -r /lib/modules/${UNAME_R}/kernel/drivers/cxl /lib/modules/${UNAME_R}/kernel/drivers/cxl-original
#[ -d /lib/modules/${UNAME_R}/kernel/drivers/cxl-raw ] && sudo rm -rf /lib/modules/${UNAME_R}/kernel/drivers/cxl-raw
#sudo cp -rf $PWD/drivers/cxl /lib/modules/${UNAME_R}/kernel/drivers/cxl-raw
#sudo rm -r /lib/modules/${UNAME_R}/kernel/drivers/cxl
#sudo cp -rf /lib/modules/${UNAME_R}/kernel/drivers/cxl-raw /lib/modules/${UNAME_R}/kernel/drivers/cxl

# https://docs.kernel.org/kbuild/modules.html#symbols-from-the-kernel-vmlinux-modules
# During a kernel build, a file named Module.symvers will be
# generated. Module.symvers contains all exported symbols from the kernel
# and compiled modules. For each symbol, the corresponding CRC value is
# also stored.

