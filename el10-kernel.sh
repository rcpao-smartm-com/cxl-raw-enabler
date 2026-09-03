#!/bin/bash


# ToDo: See Tags in https://github.com/openela-main/kernel


# script el10-kernel_$(date +%Y%m%d-%H%M%S)_$(hostname)_$(uname -r).txt
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOGFILE=el10-kernel_${TIMESTAMP}_$(hostname)_$(uname -r).txt


# $UNAME_R is the currently running kernel or the kernel you wish to build
# UNAME_R=6.14.0-1.el10_0.x86_64
# UNAME_R=6.17.2-1.el10.elrepo.x86_64
# UNAME_R=7.1.3-1.el10.elrepo.x86_64
UNAME_R=$(uname -r)
UNAME_R_NO_DASH=${UNAME_R%-*}


source /etc/os-release
# NAME="AlmaLinux"
# VERSION="10.0 (Purple Lion)"
# ID="almalinux"
# ID_LIKE="rhel centos fedora"
# VERSION_ID="10.0"
# PLATFORM_ID="platform:el10"
# PRETTY_NAME="AlmaLinux 10.0 (Purple Lion)"
# ANSI_COLOR="0;34"
# LOGO="fedora-logo-icon"
# CPE_NAME="cpe:/o:almalinux:almalinux:10::baseos"
# HOME_URL="https://almalinux.org/"
# DOCUMENTATION_URL="https://wiki.almalinux.org/"
# BUG_REPORT_URL="https://bugs.almalinux.org/"
#
# ALMALINUX_MANTISBT_PROJECT="AlmaLinux-10"
# ALMALINUX_MANTISBT_PROJECT_VERSION="10.0"
# REDHAT_SUPPORT_PRODUCT="AlmaLinux"
# REDHAT_SUPPORT_PRODUCT_VERSION="10.0"


# https://elrepo.org/wiki/doku.php?id=kernel-ml
# WARNING: elrepo.org kernel-ml is unsigned.  Secure Boot must be disabled.
# NOTE: EL10 elrepo-kernel currently provides kernel-ml only (no kernel-lt).

# Query latest elrepo kernel version for a branch (lt/ml), if available.
get_latest_elrepo_kernel_version() {
  local branch=$1
  sudo dnf -q --refresh --enablerepo=elrepo-kernel repoquery \
    --latest-limit=1 \
    --qf '%{VERSION}-%{RELEASE}.%{ARCH}' \
    "kernel-${branch}" 2>/dev/null | head -n 1
}

# elrepo kernel branch
# KERNEL_BRANCH=lt # long term (not available on EL10 as of 2026-07)
# KERNEL_BRANCH=ml # mainline
KERNEL_BRANCH=$1 # "lt" or "ml"
ELREPO_READY=0
if [[ "$KERNEL_BRANCH"  !=  "lt" && ( "$KERNEL_BRANCH"  !=  "ml" ) ]]; then
  # https://elrepo.org/wiki/doku.php?id=start
  sudo rpm --import https://www.elrepo.org/RPM-GPG-KEY-v2-elrepo.org
  sudo dnf -y install https://www.elrepo.org/elrepo-release-10.el10.elrepo.noarch.rpm
  ELREPO_READY=1
  LATEST_ML=$(get_latest_elrepo_kernel_version ml)
  ML_DISPLAY=${LATEST_ML:-unknown}
  # https://stackoverflow.com/a/226724
  while true; do
    read -p "Install which kernel [l]ongterm (not on EL10) / [m]ainline (${ML_DISPLAY})? " LM
    case $LM in
      [Ll]* ) KERNEL_BRANCH=lt; break;;
      [Mm]* ) KERNEL_BRANCH=ml; break;;
      * ) echo "Please answer l or m.";;
    esac
  done
fi

if [ "$ELREPO_READY" -eq 0 ]; then
  # https://elrepo.org/wiki/doku.php?id=start
  sudo rpm --import https://www.elrepo.org/RPM-GPG-KEY-v2-elrepo.org
  sudo dnf -y install https://www.elrepo.org/elrepo-release-10.el10.elrepo.noarch.rpm
fi

if [ "$KERNEL_BRANCH" = "lt" ]; then
  echo "kernel-lt is not currently published for EL10; use kernel-ml instead."
  exit 1
fi

sudo dnf -y --enablerepo=elrepo-kernel --refresh upgrade kernel-${KERNEL_BRANCH} kernel-${KERNEL_BRANCH}-devel # upgrade --refresh pulls the latest elrepo metadata and upgrades if a newer kernel is already installed.
sudo dnf -y --enablerepo=elrepo-kernel install kernel-${KERNEL_BRANCH} kernel-${KERNEL_BRANCH}-devel # A follow-up install covers first-time installs (upgrade alone won't install an absent package).

# File /usr/include/asm-generic/bitsperlong.h from install of
# kernel-ml-headers-7.1.3-1.el10.elrepo.x86_64 conflicts with file from
# package kernel-headers-6.14.0-1.el10_0.x86_64.

# https://elrepo.org/wiki/doku.php?id=kernel-ml
# There is no need to install the kernel-ml-headers package. It is only
# necessary if you intend to rebuild glibc and, thus, the entire operating
# system. If there is a need to have the kernel headers installed, you
# should use the current distributed kernel-headers package as that is
# related to the current version of glibc. When you see a message like
# “your kernel headers for kernel xxx cannot be found …”, you most
# likely need the kernel-ml-devel package, not the kernel-ml-headers package


# echo kernel packages: https://elrepo.org/linux/kernel/el10/x86_64/RPMS/
# echo https://elrepo.org/linux/kernel/el10/SRPMS/kernel-ml-${UNAME_R_NO_DASH}-1.el10.elrepo.nosrc.rpm
# echo https://elrepo.org/linux/kernel/el10/SRPMS/kernel-ml-${NEW_UNAME_R_NO_DASH}-1.el10.elrepo.nosrc.rpm


echo "Use grubby to select the default kernel for GRUB to boot:"
sudo grubby --info=ALL
echo -n "'grubby --default-index' returns "
sudo grubby --default-index
echo "as the current default boot index."
echo "Run 'sudo grubby --set-default-index=#' where # is the new default boot index."
echo ""
echo "You must disable Secure Boot to run elrepo kernels as they are unsigned."


NEW_UNAME_R=$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-${KERNEL_BRANCH} 2>/dev/null) # NEW_UNAME_R is set from the installed kernel-${KERNEL_BRANCH} RPM version
NEW_UNAME_R_NO_DASH=${NEW_UNAME_R%-*}
if [ -n "$NEW_UNAME_R" ] && [ "$NEW_UNAME_R" != "$UNAME_R" ]; then # If the new kernel version is different from the current kernel version, reboot to the new kernel.
  # https://stackoverflow.com/a/226724
  while true; do
    read -p "Reboot to the new $NEW_UNAME_R kernel (y/n)? " yn
    case $yn in
      [Yy]* ) sudo shutdown -r now; break;;
      [Nn]* ) break;;
      * ) echo "Please answer yes or no.";;
    esac
  done
fi
