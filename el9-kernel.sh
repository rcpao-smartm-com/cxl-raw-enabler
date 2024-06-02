#!/bin/bash


# $UNAME_R is the currently running kernel or the kernel you wish to build
# UNAME_R=5.14.0-362.8.1.el9_3.x86_64
# UNAME_R=5.14.0-362.24.2.el9_3.x86_64
# UNAME_R=6.8.4-1.el9.elrepo.x86_64
UNAME_R=$(uname -r)
UNAME_R_NO_DASH=${UNAME_R%-*}


source /etc/os-release
# NAME="AlmaLinux"
# VERSION="9.3 (Shamrock Pampas Cat)"
# ID="almalinux"
# ID_LIKE="rhel centos fedora"
# VERSION_ID="9.3"
# PLATFORM_ID="platform:el9"
# PRETTY_NAME="AlmaLinux 9.3 (Shamrock Pampas Cat)"
# ANSI_COLOR="0;34"
# LOGO="fedora-logo-icon"
# CPE_NAME="cpe:/o:almalinux:almalinux:9::baseos"
# HOME_URL="https://almalinux.org/"
# DOCUMENTATION_URL="https://wiki.almalinux.org/"
# BUG_REPORT_URL="https://bugs.almalinux.org/"
# 
# ALMALINUX_MANTISBT_PROJECT="AlmaLinux-9"
# ALMALINUX_MANTISBT_PROJECT_VERSION="9.3"
# REDHAT_SUPPORT_PRODUCT="AlmaLinux"
# REDHAT_SUPPORT_PRODUCT_VERSION="9.3"

# NAME="AlmaLinux"
# VERSION="9.4 (Seafoam Ocelot)"
# ID="almalinux"
# ID_LIKE="rhel centos fedora"
# VERSION_ID="9.4"
# PLATFORM_ID="platform:el9"
# PRETTY_NAME="AlmaLinux 9.4 (Seafoam Ocelot)"
# ANSI_COLOR="0;34"
# LOGO="fedora-logo-icon"
# CPE_NAME="cpe:/o:almalinux:almalinux:9::baseos"
# HOME_URL="https://almalinux.org/"
# DOCUMENTATION_URL="https://wiki.almalinux.org/"
# BUG_REPORT_URL="https://bugs.almalinux.org/"
# 
# ALMALINUX_MANTISBT_PROJECT="AlmaLinux-9"
# ALMALINUX_MANTISBT_PROJECT_VERSION="9.4"
# REDHAT_SUPPORT_PRODUCT="AlmaLinux"
# REDHAT_SUPPORT_PRODUCT_VERSION="9.4"
# SUPPORT_END=2032-06-01


# https://wiki.crowncloud.net/?Installing_the_Linux_Kernel_6x_on_AlmaLinux_9
# WARNING: elrepo.org kernel-ml is unsigned.  Secure Boot must be disabled.

# elrepo kernel branch
# KERNEL_BRANCH=lt # long term
# KERNEL_BRANCH=ml # mainline
KERNEL_BRANCH=$1 # "lt" or "ml"
if [[ "$KERNEL_BRANCH"  !=  "lt" && ( "$KERNEL_BRANCH"  !=  "ml" ) ]]; then
  # https://stackoverflow.com/a/226724
  while true; do
    read -p "Install which kernel [l]ongterm 6.1 / [m]ainline 6.9)? " LM
    case $LM in
      [Ll]* ) KERNEL_BRANCH=lt; break;;
      [Mm]* ) KERNEL_BRANCH=ml; break;;
      * ) echo "Please answer l or m.";;
    esac
  done
fi

sudo rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
sudo dnf -y install https://www.elrepo.org/elrepo-release-9.el9.elrepo.noarch.rpm
sudo dnf -y --enablerepo=elrepo-kernel install kernel-${KERNEL_BRANCH} kernel-${KERNEL_BRANCH}-devel
# file /usr/include/asm-generic/bitsperlong.h from install of kernel-ml-headers-6.8.4-1.el9.elrepo.x86_64 conflicts with file from package kernel-headers-5.14.0-362.24.1.el9_3.0.1.x86_64
# https://elrepo.org/wiki/doku.php?id=kernel-ml
# There is no need to install the kernel-ml-headers package. It is only necessary if you intend to rebuild glibc and, thus, the entire operating system. If there is a need to have the kernel headers installed, you should use the current distributed kernel-headers package as that is related to the current version of glibc. When you see a message like “your kernel headers for kernel xxx cannot be found …”, you most likely need the kernel-ml-devel package, not the kernel-ml-headers package

# /boot/vmlinuz-6.8.4-1.el9.elrepo.x86_64
NEW_UNAME_R_BOOT_VMLINUZ=$(sudo grubby --default-kernel) # /boot/vmlinuz-6.8.4-1.el9.elrepo.x86_64
NEW_UNAME_R=${NEW_UNAME_R_BOOT_VMLINUZ#/boot/vmlinuz-} # 6.8.4-1.el9.elrepo.x86_64
NEW_UNAME_R_NO_DASH=${NEW_UNAME_R%-*} # 6.8.4
if [ "$NEW_UNAME_R"  !=  "$UNAME_R" ]; then
  # https://stackoverflow.com/a/226724
  # echo "Reboot to the new $NEW_UNAME_R kernel?"
  # select yn in "Yes" "No"; do
  #   case $yn in
  #     Yes ) sudo shutdown -r now; break;;
  #     No ) break;;
  #   esac
  # done
  #
  while true; do
    read -p "Reboot to the new $NEW_UNAME_R kernel (y/n)? " yn
    case $yn in
      [Yy]* ) sudo shutdown -r now; break;;
      [Nn]* ) break;;
      * ) echo "Please answer yes or no.";;
    esac
  done
fi
# After reboot, kernel signature is invalid, so elrepo kernels are unsigned.
# You must disable Secure Boot to run elrepo kernels.
# 'uname -r'= 6.8.4-1.el9.elrepo.x86_64

# kernel packages: https://cbs.centos.org/koji/packageinfo?packageID=455
# https://cbs.centos.org/kojifiles/packages/kernel/6.8.2/1.el9/src/kernel-6.8.2-1.el9.src.rpm
# https://cbs.centos.org/kojifiles/packages/kernel/6.8.4/1.el9/src/kernel-6.8.4-1.el9.src.rpm
# https://cbs.centos.org/kojifiles/packages/kernel/${UNAME_R_NO_DASH}/1.el9/src/kernel-${UNAME_R_NO_DASH}-1.el9.src.rpm
# https://cbs.centos.org/kojifiles/packages/kernel/${NEW_UNAME_R_NO_DASH}/1.el9/src/kernel-${NEW_UNAME_R_NO_DASH}-1.el9.src.rpm

exit # Only upgrade to the latest mainline kernel. Skip building from sources.


# Build kernel from sources

# https://wiki.almalinux.org/documentation/building-packages-guide.html#setup-mock-and-rpm-build
sudo dnf install -y epel-release
sudo dnf install -y mock rpm-build

# https://wiki.centos.org/HowTos(2f)I_need_the_Kernel_Source.html
#sudo dnf -y install kernel-devel # replaced by kernel-ml-devel above
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


# Rocky Linux 9, AlmaLinux 9, CentOS Stream 9
# $ grep "gcc\|Kernel\ Configuration" /boot/config-*
# /boot/config-5.14.0-362.24.2.el9_3.x86_64:# Linux/x86_64 5.14.0-362.24.2.el9_3.x86_64 Kernel Configuration
# /boot/config-5.14.0-362.24.2.el9_3.x86_64:CONFIG_CC_VERSION_TEXT="gcc (GCC) 11.4.1 20230605 (Red Hat 11.4.1-2)"
# /boot/config-5.14.0-362.8.1.el9_3.x86_64:# Linux/x86_64 5.14.0-362.8.1.el9_3.x86_64 Kernel Configuration
# /boot/config-5.14.0-362.8.1.el9_3.x86_64:CONFIG_CC_VERSION_TEXT="gcc (GCC) 11.4.1 20230605 (Red Hat 11.4.1-2)"
# /boot/config-6.8.4-1.el9.elrepo.x86_64:# Linux/x86_64 6.8.4-1.el9.elrepo.x86_64 Kernel Configuration
# /boot/config-6.8.4-1.el9.elrepo.x86_64:CONFIG_CC_VERSION_TEXT="gcc (GCC) 11.4.1 20230605 (Red Hat 11.4.1-2)"
gcc --version
# gcc (GCC) 11.4.1 20230605 (Red Hat 11.4.1-2)

# $ grep -E 'CONFIG_CC_VERSION_TEXT=\"gcc \(GCC\) ' /boot/config-6.8.4-1.el9.elrepo.x86_64
# CONFIG_CC_VERSION_TEXT="gcc (GCC) 11.4.1 20230605 (Red Hat 11.4.1-2)"
GCCVERSTR=$(grep -E 'CONFIG_CC_VERSION_TEXT' /boot/config-$NEW_UNAME_R)
# + GCCVERSTR='CONFIG_CC_VERSION_TEXT="gcc (GCC) 11.4.1 20230605 (Red Hat 11.4.1-2)"'
GCCVERSTRPREFIX='CONFIG_CC_VERSION_TEXT="gcc (GCC) '
GCCVERSTR_1=${GCCVERSTR#"$GCCVERSTRPREFIX"} # "11.4.1 20230605 (Red Hat 11.4.1-2)"
GCCVERSTRSUFFIX='\ .*'
GCCVERNUM=${GCCVERSTR_1%%"$GCCVERSTRSUFFIX"} # "11.4.1"
GCCVERNUM=$(echo $GCCVERSTR_1 | sed -e "s/$GCCVERSTRSUFFIX$//") # "11.4.1"
GCCVERSTRSUFFIX='\..*'
GCCVERMAJOR=$(echo $GCCVERNUM | sed -e "s/$GCCVERSTRSUFFIX$//") # "11"
# GCCVERSTR=gcc-$GCCVERMAJOR 
# sudo dnf -y install $GCCVERSTR
# $GCCVERSTR --version
gcc --version
# https://developers.redhat.com/articles/2023/11/10/install-gcc-and-build-hello-world-application-rhel-9#step_3__build_a_hello_world_application


# warning: user mockbuild does not exist - using root
# warning: group mock does not exist - using root
# https://unix.stackexchange.com/a/558757
#sudo usermod -a -G mock $(whoami) # or ${USER}
#sudo useradd mockbuild
#sudo usermod -G mock mockbuild

# rpm -i http://vault.centos.org/7.9.2009/updates/Source/SPackages/kernel-3.10.0-1160.95.1.el7.src.rpm 2>&1 | grep -v 'exist'
rpm -i https://cbs.centos.org/kojifiles/packages/kernel/${NEW_UNAME_R_NO_DASH}/1.el9/src/kernel-${NEW_UNAME_R_NO_DASH}-1.el9.src.rpm

pushd ~/rpmbuild/SPECS
# mock rebuild -r epel-6-x86_64 /home/mockbuild/kernel 2.6.32-71.7.1.el6.src.rpm
# mock rpmbuild -bp --target=$(uname -m) kernel.spec
  rpmbuild -bp --target=$(uname -m) kernel.spec
popd
ls ~/rpmbuild/BUILD/linux*/

pushd ~/rpmbuild/BUILD/linux-6.8/
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
  # cp .config /home/rcpao/rpmbuild/SOURCES/kernel-x86_64.config
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
  # cp /usr/src/linux-headers-${UNAME_R}/Module.symvers . # Ubuntu
  cp /usr/src/kernels/${UNAME_R}/Module.symvers . # Rocky Linux 9


  # Fix: Skipping BTF generation for .../drivers/cxl/cxl_acpi.ko due to unavailability of vmlinux
  #
  # https://askubuntu.com/a/1439053
  #sudo apt-get -y install dwarves
  sudo ln -sf /sys/kernel/btf/vmlinux .


  # -j 4 works. -j runs out of memory with 2GB, 3GB, and 4GB memory

  # make -j 4
  # make -j 4 modules
  #make -j 4 V=1 modules # V=1 verbose
  # sudo make install
  # sudo make modules_install

  make modules_prepare
  # make -j 4 -C $PWD M=$PWD/drivers/cxl clean
  #make -j 4 -C $PWD M=$PWD/drivers/cxl 
  make -C $PWD M=$PWD/drivers/cxl/core
  make -C $PWD M=$PWD/drivers/cxl 


  # Copy newly built cxl kernel modules to ./cxl-raw-$UNAME_R/
  SRCDIR=./drivers/cxl
  DSTDIR1=./drivers/cxl-raw-$UNAME_R 
pwd
ls -alR $SRCDIR

  [ -d $DSTDIR1 ] && rm -rf $DSTDIR1 # signed .ko files are owned by root
  [ ! -d $DSTDIR1/core ] && mkdir -p $DSTDIR1/core

  # https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/managing_monitoring_and_updating_the_kernel/signing-a-kernel-and-modules-for-secure-boot_managing-monitoring-and-updating-the-kernel
  # 1. Secure Boot must be disabled for unsigned kernel-ml to boot
  # 2. We only want to generate one MOK key, so checks for existing keys
  #    are needed before creating.
  MOKUTIL_SB_STATE_STRING=$(mokutil --sb-state)
  MOKUTIL_SB_STATE_ENABLED=0
  [ "$MOKUTIL_SB_STATE_STRING" == "SecureBoot enabled" ] && MOKUTIL_SB_STATE_ENABLED=1
  if [[ ($MOKUTIL_SB_STATE_ENABLED -ne 0) && ( -d /etc/pki/pesign ) ]]; then
    echo "Creating new UEFI Secure Boot machine owner keys (MOK)"
    # pushd /etc/pki/pesign # root only
      sudo dnf -y install pesign openssl kernel-devel mokutil keyutils
      mokutil --sb-state
      sudo ls -l /etc/pki/pesign
      # sudo keyctl list %:.builtin_trusted_keys
      sudo keyctl list %:.platform
      # sudo keyctl list %:.blacklist
      # Create an X.509 public and private key pair to sign custom kernel modules
      sudo efikeygen --dbdir /etc/pki/pesign \
	--self-sign \
	--module \
	--common-name 'CN=Organization signing key' \
	--nickname 'Custom Secure Boot key'
      sudo ls -l /etc/pki/pesign
      sudo certutil -d /etc/pki/pesign \
	-n 'Custom Secure Boot key' \
	-Lr \
	/etc/pki/pesign/sb_cert.cer
      sudo ls -l /etc/pki/pesign
      echo When prompted, enter a new password that encrypts the private key. 
      sudo pk12util -o /etc/pki/pesign/sb_cert.p12 \
           -n 'Custom Secure Boot key' \
           -d /etc/pki/pesign
      sudo ls -l /etc/pki/pesign
      sudo openssl pkcs12 \
	-in /etc/pki/pesign/sb_cert.p12 \
	-out /etc/pki/pesign/sb_cert.priv \
	-nocerts \
	-noenc
      sudo ls -l /etc/pki/pesign
      echo "When prompted, enter a one-time password to import your new MOK.der"
      echo "at the next reboot into the blue Shim UEFI key MOK Management menu:"
      echo "Enroll MOK > Continue > Yes > "
      echo "Enter the one-time password you just entered > Reboot"
      # Screenshots: http://docs.blueworx.com/BVR/InfoCenter/V7/Linux/help/topic/com.ibm.wvrlnx.config.doc/lnx_installation_secure_boot.html
      sudo mokutil --import /etc/pki/pesign/sb_cert.cer
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

    if [[ ($MOKUTIL_SB_STATE_ENABLED -ne 0) && ( -f /etc/pki/pesign/sb_cert.priv ) && ( -f /etc/pki/pesign/sb_cert.cer ) ]]; then
      # Sign new cxl modules for UEFI Secure Boot with machine owner keys (MOK) 
      sudo /usr/src/kernels/$UNAME_R/scripts/sign-file \
	sha256 \
	/etc/pki/pesign/sb_cert.priv \
	/etc/pki/pesign/sb_cert.cer \
	$DSTDIR1/$KOSPEC
      modinfo $DSTDIR1/$KOSPEC | grep signer
    fi
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
sudo update-initramfs -c -k ${UNAME_R} # update /boot/initrd.img-${UNAME_R} in case cxl drivers are loaded at Linux kernel boot
EOF
  chmod +x $SCRIPTSPEC
  sudo cp $SCRIPTSPEC $DSTDIR2/

  SCRIPTSPEC=../cxl-original.sh
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


  # $DSTDIR2/cxl-lsmod.sh
  $DSTDIR2/cxl-rmmod.sh # remove existing cxl driver modules
  # $DSTDIR2/cxl-lsmod.sh
  $DSTDIR2/cxl-raw.sh # replace original cxl driver modules with raw enabled ones
  $DSTDIR2/cxl-insmod.sh # insert existing cxl driver modules
  # $DSTDIR2/cxl-lsmod.sh
