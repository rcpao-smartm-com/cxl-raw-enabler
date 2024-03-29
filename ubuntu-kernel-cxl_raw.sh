#!/bin/bash -x


# $UNAME_R is the currently running kernel or the kernel you wish to build
# UNAME_R=6.5.0-21-generic
# UNAME_R=6.5.0-26-generic
UNAME_R=$(uname -r)


# https://wiki.ubuntu.com/Kernel/BuildYourOwnKernel


# Enable apt deb-src repositories to get kernel sources
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


# /boot/config-6.5.0-21-generic
# CONFIG_CC_VERSION_TEXT="x86_64-linux-gnu-gcc-12 (Ubuntu 12.3.0-1ubuntu1~22.04) 12.3.0"
sudo apt-get -y install gcc-12
gcc --version
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 11
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 12
yes "" | sudo update-alternatives --config gcc
gcc --version
# gcc (Ubuntu 12.3.0-1ubuntu1~22.04) 12.3.0


uname -r
apt source linux-image-unsigned-${UNAME_R}

cd linux-hwe-6.5-6.5.0


# chmod a+x debian/rules
# chmod a+x debian/scripts/*
# chmod a+x debian/scripts/misc/*


cp /boot/config-${UNAME_R} .config # 'make oldconfig' changes kernel version comment to 6.5.13?
# make olddefconfig 
# make menuconfig # This is the text based menu config 
# make xconfig # This is the GUI based menu config 
#
# Enable CONFIG_CXL_MEM_RAW_COMMANDS=y
# Device Drivers > PCI support > CXL (Compute Express Link) Devices Support > 
#   [*] RAW Command Interface for Memory Devices (default=[_])
#
sed -e 's/# CONFIG_CXL_MEM_RAW_COMMANDS is not set/CONFIG_CXL_MEM_RAW_COMMANDS=y/' < .config > .config.cxl_raw_y
mv .config.cxl_raw_y .config 
grep CONFIG_CXL_MEM_RAW_COMMANDS .config
# CONFIG_CXL_MEM_RAW_COMMANDS=y


# Copy /usr/src/linux-headers-${UNAME_R}/Module.symvers
#
# https://docs.kernel.org/kbuild/modules.html#symbols-from-the-kernel-vmlinux-modules
# During a kernel build, a file named Module.symvers will be
# generated. Module.symvers contains all exported symbols from the kernel
# and compiled modules. For each symbol, the corresponding CRC value is
# also stored.
#
#   MODPOST /home/rcpao/Documents/job/sgh/gitlab-ub/ubuntu-kernel/linux-hwe-6.5-6.5.0/drivers/cxl/Module.symvers
# WARNING: Module.symvers is missing.
#          Modules may not have dependencies or modversions.
#          You may get many unresolved symbol errors.
#          You can set KBUILD_MODPOST_WARN=1 to turn errors into warning
#          if you want to proceed at your own risk.
#
cp /usr/src/linux-headers-${UNAME_R}/Module.symvers .


# fakeroot debian/rules clean


# make && make modules_install && make install
# 
# make -j clean
# make modules_prepare
# make -j 
# make -j modules
# sudo make modules_install
# sudo make install
#
# make -j clean
make modules_prepare
make -j -C $PWD M=$PWD/drivers/cxl clean
make -j -C $PWD M=$PWD/drivers/cxl modules


# Copy newly built cxl kernel modules to ./cxl-raw-$UNAME_R/

SRCDIR=./drivers/cxl
DSTDIR1=./drivers/cxl-raw-$UNAME_R 

[ -d $DSTDIR1 ] && rm -rf $DSTDIR1 # signed .ko files are owned by root
[ ! -d $DSTDIR1/core ] && mkdir -p $DSTDIR1/core

for KOSPEC in \
  core/cxl_core.ko \
  cxl_acpi.ko \
  cxl_mem.ko \
  cxl_pci.ko \
  cxl_pmem.ko \
  cxl_port.ko \
; do
  cp $SRCDIR/$KOSPEC $DSTDIR1/$KOSPEC
  # Sign new cxl modules for UEFI Secure Boot with machine owner keys (MOK) 
  [ -f /var/lib/shim-signed/mok/MOK.priv ] && [ -f /var/lib/shim-signed/mok/MOK.der ] && sudo /usr/src/linux-headers-$UNAME_R/scripts/sign-file sha256 /var/lib/shim-signed/mok/MOK.priv /var/lib/shim-signed/mok/MOK.der $DSTDIR1/$KOSPEC
done


# Copy newly built cxl kernel modules to $DSTDIR2/cxl-raw-$UNAME_R/

DSTDIR2=/usr/lib/modules/$UNAME_R/kernel/drivers

if [ ! -d  $DSTDIR2/cxl-raw-$UNAME_R ]; then
  sudo cp -r $DSTDIR1 $DSTDIR2/
else
  sudo cp -r $DSTDIR1/* $DSTDIR2/cxl-raw-$UNAME_R/
fi

# ls -lR $DSTDIR2/cxl*


SCRIPTSPEC=../cxl-raw.sh
# Enable CONFIG_CXL_MEM_RAW_COMMANDS=y modules
cat <<EOF > $SCRIPTSPEC
#!/bin/bash -x
[ -L $DSTDIR2/cxl ] && sudo rm $DSTDIR2/cxl 
[ -d $DSTDIR2/cxl ] && sudo mv $DSTDIR2/cxl $DSTDIR2/cxl-original
[ -d $DSTDIR2/cxl-raw-$UNAME_R ] && sudo ln -s $DSTDIR2/cxl-raw-$UNAME_R $DSTDIR2/cxl
EOF
chmod +x $SCRIPTSPEC
sudo cp $SCRIPTSPEC $DSTDIR2/

SCRIPTSPEC=../cxl-original.sh
# Restore original cxl modules
cat <<EOF > $SCRIPTSPEC
#!/bin/bash -x
[ -L $DSTDIR2/cxl ] && sudo rm $DSTDIR2/cxl 
[ ! -d $DSTDIR2/cxl ] && [ -d $DSTDIR2/cxl-original ] && sudo ln -s $DSTDIR2/cxl-original $DSTDIR2/cxl
EOF
chmod +x $SCRIPTSPEC
sudo cp $SCRIPTSPEC $DSTDIR2/

# ls -lR $DSTDIR2/cxl*


SCRIPTSPEC=../cxl-lsmod.sh
# list cxl modules
cat <<EOF > $SCRIPTSPEC
lsmod | grep cxl
EOF
chmod +x $SCRIPTSPEC
sudo cp $SCRIPTSPEC $DSTDIR2/

SCRIPTSPEC=../cxl-insmod.sh
# install cxl modules
cat <<EOF > $SCRIPTSPEC
sudo insmod cxl/core/cxl_core.ko # must be first
sudo insmod cxl/cxl_acpi.ko
sudo insmod cxl/cxl_mem.ko
sudo insmod cxl/cxl_pci.ko
sudo insmod cxl/cxl_pmem.ko
sudo insmod cxl/cxl_port.ko
EOF
chmod +x $SCRIPTSPEC
sudo cp $SCRIPTSPEC $DSTDIR2/

SCRIPTSPEC=../cxl-rmmod.sh
# remove cxl modules
cat <<EOF > $SCRIPTSPEC
sudo rmmod cxl/cxl_acpi.ko
sudo rmmod cxl/cxl_mem.ko
sudo rmmod cxl/cxl_pci.ko
sudo rmmod cxl/cxl_pmem.ko
sudo rmmod cxl/cxl_port.ko
sudo rmmod cxl/core/cxl_core.ko # must be last
EOF
chmod +x $SCRIPTSPEC
sudo cp $SCRIPTSPEC $DSTDIR2/

ls -lR $DSTDIR2/cxl*
