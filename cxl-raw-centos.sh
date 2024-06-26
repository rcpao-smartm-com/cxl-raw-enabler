#!/bin/bash -x


# $UNAME_R is the currently running kernel or the kernel you wish to build
# UNAME_R=5.14.0-432.el9.x86_64
# UNAME_R=6.8.4-1.el9.elrepo.x86_64
UNAME_R=$(uname -r)
UNAME_R_NO_DASH=${UNAME_R%-*}


source /etc/os-release
# NAME="CentOS Stream"
# VERSION="9"
# ID="centos"
# ID_LIKE="rhel fedora"
# VERSION_ID="9"
# PLATFORM_ID="platform:el9"
# PRETTY_NAME="CentOS Stream 9"
# ANSI_COLOR="0;31"
# LOGO="fedora-logo-icon"
# CPE_NAME="cpe:/o:centos:centos:9"
# HOME_URL="https://centos.org/"
# BUG_REPORT_URL="https://bugzilla.redhat.com/"
# REDHAT_SUPPORT_PRODUCT="Red Hat Enterprise Linux 9"
# REDHAT_SUPPORT_PRODUCT_VERSION="CentOS Stream"


#==> /boot/config-5.14.0-432.el9.x86_64 <==
# Linux/x86_64 5.14.0-432.el9.x86_64 Kernel Configuration
#CONFIG_CC_VERSION_TEXT="gcc (GCC) 11.4.1 20231218 (Red Hat 11.4.1-3)"
#==> /boot/config-6.8.4-1.el9.elrepo.x86_64 <==
# Linux/x86_64 6.8.4-1.el9.elrepo.x86_64 Kernel Configuration
#CONFIG_CC_VERSION_TEXT="gcc (GCC) 11.4.1 20230605 (Red Hat 11.4.1-2)"
gcc --version
# gcc (GCC) 11.4.1 20231218 (Red Hat 11.4.1-3)


# https://wiki.crowncloud.net/?How_to_install_or_upgrade_to_Kernel_6_x_on_CentOS_Stream_9
# WARNING: elrepo.org kernel-ml is unsigned.  Secure Boot must be disabled.

sudo rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
sudo dnf -y install https://www.elrepo.org/elrepo-release-9.el9.elrepo.noarch.rpm
sudo dnf -y --enablerepo=elrepo-kernel install kernel-ml

# /boot/vmlinuz-6.8.4-1.el9.elrepo.x86_64
# uname -r: 6.8.4-1.el9.elrepo.x86_64
NEW_UNAME_R=$(sudo grubby --default-kernel)
NEW_UNAME_R_NO_DASH_1=${NEW_UNAME_R#/boot/vmlinuz-}
NEW_UNAME_R_NO_DASH=${NEW_UNAME_R_NO_DASH_1%-*}
if [ "$NEW_UNAME_R_NO_DASH"!="$UNAME_R" ]; then
  # https://stackoverflow.com/a/226724
  # echo "Reboot to the new $NEW_UNAME_R_NO_DASH kernel?"
  # select yn in "Yes" "No"; do
  #   case $yn in
  #     Yes ) sudo shutdown -r now; break;;
  #     No ) break;;
  #   esac
  # done
  #
  while true; do
    read -p "Reboot to the new $NEW_UNAME_R_NO_DASH kernel (y/n)? " yn
    case $yn in
      [Yy]* ) sudo shutdown -r now; break;;
      [Nn]* ) break;;
      * ) echo "Please answer yes or no.";;
    esac
  done

fi
# After reboot, kernel signature invalid
# 'uname -r'= 6.8.4-1.el9.elrepo.x86_64

# kernel packages: https://cbs.centos.org/koji/packageinfo?packageID=455
# https://cbs.centos.org/kojifiles/packages/kernel/6.8.2/1.el9/src/kernel-6.8.2-1.el9.src.rpm
# https://cbs.centos.org/kojifiles/packages/kernel/${UNAME_R_NO_DASH}/1.el9/src/kernel-${UNAME_R_NO_DASH}-1.el9.src.rpm
# https://cbs.centos.org/kojifiles/packages/kernel/${NEW_UNAME_R_NO_DASH}/1.el9/src/kernel-${NEW_UNAME_R_NO_DASH}-1.el9.src.rpm


# https://wiki.almalinux.org/documentation/building-packages-guide.html#setup-mock-and-rpm-build
sudo dnf install -y epel-release
sudo dnf install -y mock rpm-build

# https://wiki.centos.org/HowTos(2f)I_need_the_Kernel_Source.html
sudo dnf -y install kernel-devel
mkdir -p ~/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
echo '%_topdir %(echo $HOME)/rpmbuild' > ~/.rpmmacros

sudo dnf -y install asciidoc audit-libs-devel bash bc binutils binutils-devel bison diffutils elfutils
sudo dnf -y install elfutils-devel elfutils-libelf-devel findutils flex gawk gcc gettext gzip hmaccalc hostname java-devel
sudo dnf -y install m4 make module-init-tools ncurses-devel net-tools newt-devel numactl-devel openssl
sudo dnf -y install patch pciutils-devel perl perl-ExtUtils-Embed pesign python-devel python-docutils redhat-rpm-config
# Error: Unable to find a match: python-docutils
sudo dnf -y install patch pciutils-devel perl perl-ExtUtils-Embed pesign python-devel                 redhat-rpm-config
sudo dnf -y install rpm-build sh-utils tar xmlto xz zlib-devel
# Error: Unable to find a match: sh-utils
sudo dnf -y install rpm-build          tar xmlto xz zlib-devel

# warning: user mockbuild does not exist - using root
# warning: group mock does not exist - using root
# https://unix.stackexchange.com/a/558757
#sudo dnf -y install mock-centos-sig-configs
#
# https://copr.fedorainfracloud.org/coprs/g/mock/mock-stable/repo/epel-9/group_mock-mock-stable-epel-9.repo
# sudo dnf copr enable @mock/mock-stable
# sudo dnf install mock
#   - nothing provides python3-backoff needed by mock-5.5-1.el9.noarch from copr:copr.fedorainfracloud.org:group_mock:mock-stable
#   - nothing provides python3-pyroute2 needed by mock-5.5-1.el9.noarch from copr:copr.fedorainfracloud.org:group_mock:mock-stable
#   - nothing provides python3-templated-dictionary needed by mock-5.5-1.el9.noarch from copr:copr.fedorainfracloud.org:group_mock:mock-stable
#
# https://rpm-software-management.github.io/mock/
#
sudo groupadd mock
sudo usermod -a -G mock $(whoami) # or ${USER}
sudo useradd mockbuild
sudo usermod -G mock mockbuild

# rpm -i http://vault.centos.org/7.9.2009/updates/Source/SPackages/kernel-3.10.0-1160.95.1.el7.src.rpm 2>&1 | grep -v 'exist'
rpm -i https://cbs.centos.org/kojifiles/packages/kernel/${NEW_UNAME_R_NO_DASH}/1.el9/src/kernel-${NEW_UNAME_R_NO_DASH}-1.el9.src.rpm

pushd ~/rpmbuild/SPECS
# mock rebuild -r epel-6-x86_64 /home/mockbuild/kernel 2.6.32-71.7.1.el6.src.rpm
# mock rpmbuild -bp --target=$(uname -m) kernel.spec
  rpmbuild -bp --target=$(uname -m) kernel.spec
popd
ls ~/rpmbuild/BUILD/linux*/

pushd ~/rpmbuild/BUILD/linux-6.8/
  make # -j: cc1 runs out of memory with 2GB to 3GB
  make modules # -j: cc1 runs out of memory
  # sudo make install
  # sudo make modules_install
popd


exit


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
