#!/bin/bash -x


# $UNAME_R is the currently running kernel or the kernel you wish to build
# UNAME_R=6.5.0-21-generic
# UNAME_R=6.5.0-26-generic
UNAME_R=$(uname -r)


# https://wiki.ubuntu.com/Kernel/BuildYourOwnKernel


# Enable apt deb-src repositories to get kernel sources
#
# One-Line-Style Format
source /etc/os-release
# VERSION_CODENAME=jammy
echo Uncomment the following lines from /etc/apt/sources.list
echo deb-src http://archive.ubuntu.com/ubuntu ${VERSION_CODENAME} main
echo deb-src http://archive.ubuntu.com/ubuntu ${VERSION_CODENAME}-updates main
# deb-src http://us.archive.ubuntu.com/ubuntu/ \${VERSION_CODENAME} main restricted
sed 's|\# deb-src http:\/\/us\.archive\.ubuntu\.com\/ubuntu\/ '"${VERSION_CODENAME}"' main restricted$|deb-src http:\/\/us\.archive\.ubuntu\.com\/ubuntu\/ '"${VERSION_CODENAME}"' main restricted|' /etc/apt/sources.list > /tmp/sources.list.1.$$
# deb-src http://us.archive.ubuntu.com/ubuntu/ ${VERSION_CODENAME}-updates main restricted
sed 's|\# deb-src http:\/\/us\.archive\.ubuntu\.com\/ubuntu\/ '"${VERSION_CODENAME}"'-updates main restricted$|deb-src http:\/\/us\.archive\.ubuntu\.com\/ubuntu\/ '"${VERSION_CODENAME}"'-updates main restricted|' /tmp/sources.list.1.$$ > /tmp/sources.list.2.$$
[ ! -f /etc/apt/sources.list_before-$(basename $0) ] && sudo cp /etc/apt/sources.list /etc/apt/sources.list_before-$(basename $0)
sudo cp -f /tmp/sources.list.2.$$ /etc/apt/sources.list
# rm /tmp/sources.list.[12].$$ 

# DEB822-Style Format in Ubuntu 24.04 daily 2024-03-23 06:41
if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
  [ ! -f /etc/apt/sources.list.d/ubuntu.sources_before-$(basename $0) ] && sudo cp -f /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources_before-$(basename $0) # make a backup
  echo Replace "Types: deb" with "Types: deb deb-src"
  sed 's|Types: deb$|Types: deb deb-src|' /etc/apt/sources.list.d/ubuntu.sources > /tmp/ubuntu.sources.1.$$
  sudo cp -f /tmp/ubuntu.sources.1.$$ /etc/apt/sources.list.d/ubuntu.sources
fi

sudo apt-get -y update
sudo apt-get -y build-dep linux linux-image-unsigned-${UNAME_R}
sudo apt-get -y install libncurses-dev gawk flex bison openssl libssl-dev dkms libelf-dev libudev-dev libpci-dev libiberty-dev autoconf llvm
sudo apt-get -y install zstd
sudo apt-get -y install rustc


# Ubuntu 22.04.4: /boot/config-6.5.0-21-generic; CONFIG_CC_VERSION_TEXT="x86_64-linux-gnu-gcc-12 (Ubuntu 12.3.0-1ubuntu1~22.04) 12.3.0"
# Ubuntu 24.04 daily; /boot/config-6.8.0-11-generic; Linux/x86 6.8.0-rc4 Kernel Configuration; CONFIG_CC_VERSION_TEXT="x86_64-linux-gnu-gcc-13 (Ubuntu 13.2.0-13ubuntu1) 13.2.0"
GCCVERSTR=$(grep -Eo 'gcc-[0-9]+' /boot/config-$UNAME_R) # gcc-12
GCCVERNUM=${GCCVERSTR#gcc-} # 12
sudo apt-get -y install $GCCVERSTR
$GCCVERSTR --version
# sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 11
# sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 12
# sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 13
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/$GCCVERSTR $GCCVERNUM
yes "" | sudo update-alternatives --config gcc
gcc --version
# 22.04.4: gcc (Ubuntu 12.3.0-1ubuntu1~22.04) 12.3.0
# 24.04 daily: gcc (Ubuntu 12.3.0-15ubuntu1) 12.3.0
# 24.04 daily: gcc-13 (Ubuntu 13.2.0-21ubuntu1) 13.2.0


uname -r
apt source linux-image-unsigned-${UNAME_R}
RETVAL=$? # DBG: non-zero will use git clone
if [ ${RETVAL} -eq 0 ]; then
  # cd linux-hwe-6.5-6.5.0
  # cd linux-6.8.0
  LS_D_LINUX=$(ls -d linux-*/)
  cd ${LS_D_LINUX}
else
  # https://wiki.ubuntu.com/Kernel/Dev/KernelGitGuide
  git clone git://git.launchpad.net/~ubuntu-kernel/ubuntu/+source/linux/+git/${VERSION_CODENAME}
  ls -ld ${VERSION_CODENAME}
  cd ${VERSION_CODENAME}
  KVERS=${UNAME_R%-generic} # remove "-generic"
  GITTAG=$(git tag -l Ubuntu-${KVERS}.*)
  git checkout -b ${GITTAG}-cxl-raw ${GITTAG}
fi


# ls -RF debian
# chmod a+x debian/rules
# chmod a+x debian/scripts/*
# chmod a+x debian/scripts/misc/*


cp /boot/config-${UNAME_R} .config # 'make oldconfig' changes kernel version comment to 6.5.13?
# yes "" | make oldconfig # https://serverfault.com/a/116317/221343
make olddefconfig # https://serverfault.com/a/538150/221343
# make menuconfig # This is the text based menu config 
# make xconfig # This is the GUI based menu config 
#
# Enable CONFIG_CXL_MEM_RAW_COMMANDS=y
# Device Drivers > PCI support > CXL (Compute Express Link) Devices Support > 
#   [*] RAW Command Interface for Memory Devices (default=[_])
#
sed -e 's/# CONFIG_CXL_MEM_RAW_COMMANDS is not set/CONFIG_CXL_MEM_RAW_COMMANDS=y/' < .config > .config.cxl_raw_y
mv .config.cxl_raw_y .config 
#
diff /boot/config-${UNAME_R} .config
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


# Fix: Skipping BTF generation for .../drivers/cxl/cxl_acpi.ko due to unavailability of vmlinux
#
# https://askubuntu.com/a/1439053
#sudo apt-get -y install dwarves
sudo ln -sf /sys/kernel/btf/vmlinux .


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

if [[ ( ! -f /var/lib/shim-signed/mok/MOK.priv ) && ( ! -f /var/lib/shim-signed/mok/MOK.der ) ]]; then
  mokutil --sb-state
  echo "Creating new UEFI Secure Boot machine owner keys (MOK)"
  # pushd /var/lib/shim-signed/mok/
    sudo openssl req -new -x509 \
    -newkey rsa:2048 -keyout /var/lib/shim-signed/mok/MOK.priv \
    -outform DER -out /var/lib/shim-signed/mok/MOK.der \
    -nodes -days 36500 -subj "/CN=$(hostname --fqdn) Driver Kmod Signing MOK"
    echo "When prompted, enter a one-time password to import your new MOK.der"
    echo "at the next reboot into the blue Shim UEFI key MOK Management menu:"
    echo "Enroll MOK > Continue > Yes > "
    echo "Enter the one-time password you just entered > Reboot"
    # Screenshots: http://docs.blueworx.com/BVR/InfoCenter/V7/Linux/help/topic/com.ibm.wvrlnx.config.doc/lnx_installation_secure_boot.html
    sudo mokutil --import /var/lib/shim-signed/mok/MOK.der
  # popd
fi

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
  zstd $DSTDIR1/$KOSPEC
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

# Use compressed .ko.zst if original is compressed
DOTZSTEXT=""
[ -d $DSTDIR2/cxl ] && [ -f $DSTDIR2/cxl/core/cxl_core.ko.zst ] && DOTZSTEXT=.zst
[ -f $DSTDIR2/cxl/core/cxl_core.ko.zst ] && DOTZSTEXT=.zst
# Ubuntu 24.04 daily ships with *.ko.zstd Zstd compressed kernel modules
SCRIPTSPEC=../cxl-insmod.sh
# install cxl modules
cat <<EOF > $SCRIPTSPEC
DOTZSTEXT=$DOTZSTEXT
sudo insmod $DSTDIR2/cxl/core/cxl_core.ko\$DOTZSTEXT # cxl_core must be first
sudo insmod $DSTDIR2/cxl/cxl_acpi.ko\$DOTZSTEXT
sudo insmod $DSTDIR2/cxl/cxl_mem.ko\$DOTZSTEXT
sudo insmod $DSTDIR2/cxl/cxl_pci.ko\$DOTZSTEXT
sudo insmod $DSTDIR2/cxl/cxl_pmem.ko\$DOTZSTEXT
sudo insmod $DSTDIR2/cxl/cxl_port.ko\$DOTZSTEXT
EOF
chmod +x $SCRIPTSPEC
sudo cp $SCRIPTSPEC $DSTDIR2/

SCRIPTSPEC=../cxl-rmmod.sh
# remove cxl modules
cat <<EOF > $SCRIPTSPEC
sudo rmmod cxl_acpi
sudo rmmod cxl_mem
sudo rmmod cxl_pci
sudo rmmod cxl_pmem
sudo rmmod cxl_port
sudo rmmod cxl_core # cxl_core must be last
EOF
chmod +x $SCRIPTSPEC
sudo cp $SCRIPTSPEC $DSTDIR2/

ls -lR $DSTDIR2/cxl*
