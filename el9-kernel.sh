#!/bin/bash


# script el9-kernel_$(date +%Y%m%d-%H%M%S)_$(hostname)_$(uname -r).txt
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOGFILE=el9-kernel_${TIMESTAMP}_$(hostname)_$(uname -r).txt


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


# echo kernel packages: https://cbs.centos.org/koji/packageinfo?packageID=455
# echo https://cbs.centos.org/kojifiles/packages/kernel/6.8.2/1.el9/src/kernel-6.8.2-1.el9.src.rpm
# echo https://cbs.centos.org/kojifiles/packages/kernel/6.8.4/1.el9/src/kernel-6.8.4-1.el9.src.rpm
# echo https://cbs.centos.org/kojifiles/packages/kernel/${UNAME_R_NO_DASH}/1.el9/src/kernel-${UNAME_R_NO_DASH}-1.el9.src.rpm
# echo https://cbs.centos.org/kojifiles/packages/kernel/${NEW_UNAME_R_NO_DASH}/1.el9/src/kernel-${NEW_UNAME_R_NO_DASH}-1.el9.src.rpm


echo "Use grubby to select the default kernel for GRUB to boot:"
sudo grubby --info=ALL
echo -n "'grubby --default-index' returns "
sudo grubby --default-index
echo "as the current default boot index."
echo "Run 'sudo grubby --set-default-index=#' where # is the new default boot index."
echo ""
echo "You must disable Secure Boot to run elrepo kernels as they are unsigned."


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
