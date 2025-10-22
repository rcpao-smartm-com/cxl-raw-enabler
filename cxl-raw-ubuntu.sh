#!/bin/bash -vx


# script cxl-raw-ubuntu_$(date +%Y%m%d-%H%M%S)_$(hostname)_$(uname -r).txt
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOGFILE=cxl-raw-ubuntu_${TIMESTAMP}_$(hostname)_$(uname -r).txt


uname -a
uname -r
# $UNAME_R is the currently running kernel or the kernel you wish to build
# UNAME_R=6.5.0-21-generic
# UNAME_R=6.5.0-26-generic
# UNAME_R=6.5.0-27-generic
# UNAME_R=6.5.0-28-generic
# UNAME_R=linux-hwe-6.5-6.5.0
# UNAME_R=linux-oem-6.5-6.5.0
# UNAME_R=6.14.0-32-generic
UNAME_R=$(uname -r)
UNAME_R_3=${UNAME_R%%-*} # "6.14.0" remove first/greedy "-##-generic"
UNAME_R_2=${UNAME_R%.*} # "6.14^" remove last ".*"
KVERS=${UNAME_R%-generic} # "6.14.0-32" remove "-generic"


# https://wiki.ubuntu.com/Kernel/BuildYourOwnKernel


# Enable apt deb-src repositories to get kernel sources
#
# One-Line-Style Format
cat /etc/os-release
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
  [ ! -f /etc/apt/sources.list.d/ubuntu.sources_before-$(basename $0) ] && sudo cp -f /etc/apt/sources.list.d/ubuntu.sources /root/ubuntu.sources.backup_before_$(basename $0) # make a backup
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


apt-cache search linux-source | tee apt-cache_search_linux-source.txt
grep ${KVERS} apt-cache_search_linux-source.txt
if [ $? -gt 0 ]; then
  echo ""
  echo "--------------------------------------------------"
  echo "error: linux-source for ${KVERS} does not exist!"
  echo "--------------------------------------------------"
  echo ""
fi

# ERROR:
# https://askubuntu.com/a/938955
# 'apt-get source ...' only gets the _latest_ source:
# + uname -r
# 6.7.6-060706-generic
# + apt-get source linux-image-unsigned-6.7.6-060706-generic
# Reading package lists... Done
# Picking 'linux' as source package instead of 'linux-image-unsigned-6.7.6-060706-generic'
# Need to get 232 MB of source archives.
# Get:1 http://us.archive.ubuntu.com/ubuntu noble-updates/main linux 6.8.0-35.35 (dsc) [9,267 B]
# Get:2 http://us.archive.ubuntu.com/ubuntu noble-updates/main linux 6.8.0-35.35 (tar) [230 MB]
# Get:3 http://us.archive.ubuntu.com/ubuntu noble-updates/main linux 6.8.0-35.35 (diff) [1,617 kB]
# Fetched 232 MB in 44s (5,314 kB/s)
# dpkg-source: info: extracting linux in linux-6.8.0
# dpkg-source: info: unpacking linux_6.8.0.orig.tar.gz
# dpkg-source: info: applying linux_6.8.0-35.35.diff.gz
# dpkg-source: info: upstream files that have been modified:
uname -r
apt-get source linux-image-unsigned-${UNAME_R} # 6.11.0-25-generic
# apt-get source linux-source-${UNAME_R_3}
RETVAL=0 # Assume apt-get source works and try to cd into the extracted directory # $? # DBG: non-zero will use git clone
# https://ubuntuforums.org/showthread.php?t=1758823&p=10822030#post10822030
# If you really want the older kernel info, you can get it from the
# Ubuntu Git repository. The tags will allow to you select the exact
# version you want.
#RETVAL=-1 # force using git instead of 'apt source'
if [ ${RETVAL} -eq 0 ]; then
  # [ -f linux-hwe-6.5_6.5.0.orig.tar.gz ] && tar -xvf linux-hwe-6.5_6.5.0.orig.tar.gz && mv linux-6.5 linux-hwe-6.5-6.5.0
  [ -f linux-hwe-${UNAME_R_2}_${UNAME_R_3}.orig.tar.gz ] && tar -xvf linux-hwe-${UNAME_R_2}_${UNAME_R_3}.orig.tar.gz && mv linux-${UNAME_R_2} linux-hwe-6.5-${UNAME_R_3}
  # ToDo patch linux-hwe-6.5_6.5.0-27.28~22.04.1.diff.gz or $(uname -r) equivalent, except Ubuntu probably wouldn't patch the cxl driver sources.
  cd linux-hwe-${UNAME_R_2}-${UNAME_R_3} # "linux-hwe-6.5-6.5.0"
  RETVAL=$? # 0=cd success, contrary to 'man bash cd' true=success
  # cd xxx # fail test
  # RETVAL=$? # 1 if cd fails
  # [ "$(basename $PWD)"!="linux-hwe-${UNAME_R_2}-${UNAME_R_3}" ] && cd linux-${UNAME_R_3} # "linux-6.8.0"
  if [ ${RETVAL} -ne 0 ]; then
    cd linux-oem-${UNAME_R_2}-${UNAME_R_3} # "linux-oem-6.5-6.5.0"
    RETVAL=$?
  fi
  if [ ${RETVAL} -ne 0 ]; then
    cd linux-${UNAME_R_3} # "linux-6.8.0"
    RETVAL=$?
  fi
  if [ ${RETVAL} -ne 0 ]; then
    echo "Error: Failed to cd into kernel source directory."
    echo "Fall through and attempt to use 'git clone . . .'"
    # exit 1
  fi
  # LS_D_LINUX=$(ls -d linux-*/) 
  # cd ${LS_D_LINUX}
    # + cd linux-hwe-6.5-6.5.0/ linux-hwe-6.5-6.5.0-26/
    # ./cxl-raw-ubuntu.sh: line 68: cd: too many arguments
    # Manually created folders will confuse 'cd linux-*/'

fi # else


# exit 1 # DBG


if [ ${RETVAL} -ne 0 ]; then

  # https://stackoverflow.com/a/226724
  while true; do
    read -p "apt source failed.  Do you wish to git clone? " yn
    case $yn in
      [Yy]* ) break;;
      [Nn]* ) exit 2;;
      * ) echo "Please enter y or n.";;
    esac
  done

  # Attempt 'git clone . . .'
  if [ ! $(command -v git) ]; then
    sudo apt-get -y install git
  fi

  # https://wiki.ubuntu.com/Kernel/Dev/KernelGitGuide
  if [ ! -d ${VERSION_CODENAME} ]; then
    # git clone --depth 1 --branch <tag_name> <repo_url> # https://stackoverflow.com/a/21699307/1707260
    # git clone git://git.launchpad.net/~ubuntu-kernel/ubuntu/+source/linux/+git/${VERSION_CODENAME} # blocked by IT from Engr & Test
    git clone https://git.launchpad.net/~ubuntu-kernel/ubuntu/+source/linux/+git/${VERSION_CODENAME}
    RETVAL=$? # DBG: non-zero is fatal
    if [ ${RETVAL} -ne 0 ]; then
      echo "Error: git clone failed."
      exit 1
    fi
  fi
  ls -ld ${VERSION_CODENAME}
  cd ${VERSION_CODENAME}
  git pull
  # git tag -l "Ubuntu-${UNAME_R_2}*" # UNAME_R_2=${UNAME_R%.*} # "6.5" remove last ".*"
  # GITTAG=$(git tag -l "Ubuntu-${UNAME_R_2}*")
  # git tag -l "Ubuntu-${UNAME_R_3}*" # UNAME_R_3=${UNAME_R%%-*} # "6.5.0" remove first/greedy "-##-generic"
  # GITTAG=$(git tag -l "Ubuntu-${UNAME_R_3}*")
  # git tag -l "Ubuntu-${KVERS}*" # KVERS=${UNAME_R%-generic} # remove "-generic"
  # GITTAG=$(git tag -l "Ubuntu-${KVERS}.*")
    git tag -l "Ubuntu-hwe-*-${KVERS}*" # KVERS=${UNAME_R%-generic} # remove "-generic"
    GITTAG=$(git tag -l "Ubuntu-hwe-*-${KVERS}.*" | tail -n 1)
  if [ -z "${GITTAG}" ]; then
    # echo "Error: git tag -l \"\${UNAME_R_2}*\" failed."
    # echo "Error: git tag -l \"\${UNAME_R_3}*\" failed."
    echo "Error: git tag -l \"Ubuntu-\${KVERS}.*\" failed."
    exit 1
  fi
  git checkout -b ${GITTAG}-cxl-raw ${GITTAG}
  RETVAL=$? # DBG: non-zero is fatal
  if [ ${RETVAL} -ne 0 ]; then
    echo "Error: git checkout failed."
    exit 1
  fi

fi


pwd


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
# Enable CONFIG_CXL_REGION_INVALIDATION_TEST=y
#
sed -e 's/# CONFIG_CXL_MEM_RAW_COMMANDS is not set/CONFIG_CXL_MEM_RAW_COMMANDS=y/' < .config > .config.cxl_raw_y
mv .config.cxl_raw_y .config 
sed -e 's/# CONFIG_CXL_REGION_INVALIDATION_TEST is not set/CONFIG_CXL_REGION_INVALIDATION_TEST=y/' < .config > .config.cxl_raw_y
mv .config.cxl_raw_y .config 
#
diff /boot/config-${UNAME_R} .config
grep CONFIG_CXL_MEM_RAW_COMMANDS .config
# CONFIG_CXL_MEM_RAW_COMMANDS=y
# CONFIG_CXL_REGION_INVALIDATION_TEST=y


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
[ ! -f /usr/src/linux-headers-${UNAME_R}/Module.symvers ] && echo "error $LINENO: \"/usr/src/linux-headers-${UNAME_R}/Module.symvers\" file not found" && exit $LINENO
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
time make modules_prepare
time make -j -C $PWD M=$PWD/drivers/cxl clean
time make -j -C $PWD M=$PWD/drivers/cxl modules


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


SCRIPTDIR=./drivers
SCRIPTSPEC=$SCRIPTDIR/cxl-raw.sh
# Enable CONFIG_CXL_MEM_RAW_COMMANDS=y modules
cat <<EOF > $SCRIPTSPEC
#!/bin/bash -x
[ -L $DSTDIR2/cxl ] && sudo rm $DSTDIR2/cxl 
[ -d $DSTDIR2/cxl ] && [ ! -d $DSTDIR2/cxl-original ] && sudo mv $DSTDIR2/cxl $DSTDIR2/cxl-original
[ -d $DSTDIR2/cxl-raw-$UNAME_R ] && sudo ln -s $DSTDIR2/cxl-raw-$UNAME_R $DSTDIR2/cxl
sudo update-initramfs -c -k ${UNAME_R} # update /boot/initrd.img-${UNAME_R} in case cxl drivers are loaded at Linux kernel boot
EOF
chmod +x $SCRIPTSPEC
sudo cp $SCRIPTSPEC $DSTDIR2/

SCRIPTSPEC=$SCRIPTDIR/cxl-original.sh
# Restore original cxl modules
cat <<EOF > $SCRIPTSPEC
#!/bin/bash -x
[ -L $DSTDIR2/cxl ] && sudo rm $DSTDIR2/cxl 
[ ! -d $DSTDIR2/cxl ] && [ -d $DSTDIR2/cxl-original ] && sudo ln -s $DSTDIR2/cxl-original $DSTDIR2/cxl
sudo update-initramfs -c -k ${UNAME_R} # update /boot/initrd.img-${UNAME_R} in case cxl drivers are loaded at Linux kernel boot
EOF
chmod +x $SCRIPTSPEC
sudo cp $SCRIPTSPEC $DSTDIR2/

# ls -lR $DSTDIR2/cxl*


SCRIPTSPEC=$SCRIPTDIR/cxl-lsmod.sh
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
SCRIPTSPEC=$SCRIPTDIR/cxl-insmod.sh
# install cxl modules
cat <<EOF > $SCRIPTSPEC
# DOTZSTEXT=.zst
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

SCRIPTSPEC=$SCRIPTDIR/cxl-rmmod.sh
# remove cxl modules
cat <<EOF > $SCRIPTSPEC
sudo rmmod -v cxl_acpi
sudo rmmod -v cxl_mem
sudo rmmod -v cxl_pci
sudo rmmod -v cxl_pmem
sudo rmmod -v cxl_port
sudo rmmod -v cxl_core # cxl_core must be last
EOF
chmod +x $SCRIPTSPEC
sudo cp $SCRIPTSPEC $DSTDIR2/

ls -lR $DSTDIR2/cxl*


echo "WARNING: rmmod cxl drivers which are in-use, may hang the system."
echo "         $DSTDIR2/cxl-raw.sh will be run to install cxl raw enabled drivers."
echo "         cxl raw enabled drivers will be used when this kernel is restarted."

# while true; do
#   echo "WARNING: rmmod cxl drivers which are in-use, may hang the system."
#   echo "         rmmod cxl drivers from a fresh booted system has a higher chance of working."
#   read -p "Do you wish to rmmod current cxl drivers, enable raw, and insmod? " yn
#   case $yn in
#     [Yy]* ) break;;
#     [Nn]* ) exit 3;;
#     * ) echo "Please answer y or n.";;
#   esac
# done

# bash -x $DSTDIR2/cxl-lsmod.sh
#bash -x $DSTDIR2/cxl-rmmod.sh # remove existing cxl driver modules
bash -x $DSTDIR2/cxl-raw.sh # replace original cxl driver modules with raw enabled ones
# bash -x $DSTDIR2/cxl-lsmod.sh
#bash -x $DSTDIR2/cxl-insmod.sh # insert existing cxl driver modules
#bash -x $DSTDIR2/cxl-lsmod.sh


date # Subtract $TIMESTAMP for time to run this script including waiting for user input
