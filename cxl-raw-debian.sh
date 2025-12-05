#!/bin/bash -x


# script cxl-raw-debian_$(date +%Y%m%d-%H%M%S)_$(hostname)_$(uname -r).txt
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOGFILE=cxl-raw-debian_${TIMESTAMP}_$(hostname)_$(uname -r).txt


# PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"
# NAME="Debian GNU/Linux"
# VERSION_ID="12"
# VERSION="12 (bookworm)"
# VERSION_CODENAME=bookworm
# ID=debian
# HOME_URL="https://www.debian.org/"
# SUPPORT_URL="https://www.debian.org/support"
# BUG_REPORT_URL="https://bugs.debian.org/"


# https://www.cyberciti.biz/faq/howto-display-all-installed-linux-kernel-version/
dpkg --list | grep linux-image


# $UNAME_R is the currently running kernel or the kernel you wish to build
# UNAME_R=6.1.0-28-amd64
# UNAME_R=6.12.57+deb13-amd64
# UNAME_R_3=6.1.0
# UNAME_R_2=6.1
# KVERS=6.1.0-28
UNAME_R=$(uname -r)
# UNAME_R_3=${UNAME_R%%-*} # "6.1.0" remove first/greedy "-*"
UNAME_R_3=${UNAME_R%%[-+]*} # "6.1.0" remove first/greedy "-*" or "+*"
UNAME_R_2=${UNAME_R%.*} # "6.1" remove last ".*"
KVERS=${UNAME_R%-*} # "6.1.0-28" remove "-amd64"


# https://www.debian.org/doc/manuals/debian-kernel-handbook/ch-common-tasks.html


# sudo apt-get -y install linux-source
# tar xaf /usr/src/linux-source-${UNAME_R_2}


sudo apt-get -y install build-essential fakeroot
sudo apt-get -y build-dep linux

apt-get source linux # gets the latest kernel version for this debian release, not the currently running kernel version, and no backports

pushd linux-${UNAME_R_3}

  # [ ! -f .config ] && cp /boot/config-${UNAME_R} .config
                        cp /boot/config-${UNAME_R} .config # 'make oldconfig' changes kernel version comment?
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
  #sed -e 's/# CONFIG_CXL_REGION_INVALIDATION_TEST is not set/CONFIG_CXL_REGION_INVALIDATION_TEST=y/' < .config > .config.cxl_raw_y
  #mv .config.cxl_raw_y .config 
  #
  diff /boot/config-${UNAME_R} .config
  grep CONFIG_CXL_MEM_RAW_COMMANDS .config
  # CONFIG_CXL_MEM_RAW_COMMANDS=y
  # CONFIG_CXL_REGION_INVALIDATION_TEST=y

  make clean

  # make deb-pkg
    # dpkg-source: error: unrepresentable changes to source
    # dpkg-buildpackage: error: dpkg-source -i.git -b . subprocess returned exit status 1

  fakeroot debian/rules binary
    # $ ls -lF ..
    # drwxr-xr-x 28 smart smart      4096 Dec 27 04:15 linux-6.1.119/
    # -rw-r--r--  1 smart smart   1696788 Nov 22 14:38 linux_6.1.119-1.debian.tar.xz
    # -rw-r--r--  1 smart smart    290930 Nov 22 14:38 linux_6.1.119-1.dsc
    # drwxr-xr-x 26 smart smart      4096 Dec 26 23:23 linux-6.1.119.orig/
    # -rw-r--r--  1 smart smart 137707144 Nov 22 14:38 linux_6.1.119.orig.tar.xz
    # -rw-r--r--  1 smart smart   8850292 Dec 27 04:20 linux-headers-6.1.119_6.1.119-1_amd64.deb
    # -rw-r--r--  1 smart smart  70316308 Dec 27 04:20 linux-image-6.1.119_6.1.119-1_amd64.deb
    # -rw-r--r--  1 smart smart 816257064 Dec 27 04:22 linux-image-6.1.119-dbg_6.1.119-1_amd64.deb
    # -rw-r--r--  1 smart smart   1275272 Dec 27 04:20 linux-libc-dev_6.1.119-1_amd64.deb
    # -rw-r--r--  1 smart smart   5971271 Dec 26 23:03 linux-upstream_6.1.119-1.diff.gz
    # -rw-r--r--  1 smart smart 226258708 Dec 26 23:02 linux-upstream_6.1.119.orig.tar.gz
    # $ ls -lF ../linux-*.deb
    # -rw-r--r-- 1 smart smart   8850292 Dec 27 04:20 linux-headers-6.1.119_6.1.119-1_amd64.deb
    # -rw-r--r-- 1 smart smart  70316308 Dec 27 04:20 linux-image-6.1.119_6.1.119-1_amd64.deb
    # -rw-r--r-- 1 smart smart 816257064 Dec 27 04:22 linux-image-6.1.119-dbg_6.1.119-1_amd64.deb
    # -rw-r--r-- 1 smart smart   1275272 Dec 27 04:20 linux-libc-dev_6.1.119-1_amd64.deb

    # -rw-r--r-- 1 rcpao rcpao      1108 Dec  5 00:10 linux-doc_6.12.57-1_all.deb
    # -rw-r--r-- 1 rcpao rcpao  39296788 Dec  5 00:09 linux-doc-6.12_6.12.57-1_all.deb
    # -rw-r--r-- 1 rcpao rcpao  11195268 Dec  5 00:10 linux-headers-6.12.57+deb13-common_6.12.57-1_all.deb
    # -rw-r--r-- 1 rcpao rcpao   9553336 Dec  5 00:10 linux-headers-6.12.57+deb13-common-rt_6.12.57-1_all.deb
    # -rw-r--r-- 1 rcpao rcpao   2691676 Dec  5 00:10 linux-libc-dev_6.12.57-1_all.deb
    # -rw-r--r-- 1 rcpao rcpao      1100 Dec  5 00:10 linux-source_6.12.57-1_all.deb
    # -rw-r--r-- 1 rcpao rcpao 152599108 Dec  5 00:11 linux-source-6.12_6.12.57-1_all.deb
    # -rw-r--r-- 1 rcpao rcpao   1178620 Dec  5 00:11 linux-support-6.12.57+deb13_6.12.57-1_all.deb

  # ? fakeroot debian/rules source

popd

ls -l linux-*.deb
sudo dpkg -i linux-headers-${UNAME_R_3}*_${UNAME_R_3}-1_*.deb linux-libc-dev_${UNAME_R_3}-1_*.deb
[ -f linux-image-6.12.57_6.12.57-1_*.deb ] && sudo dpkg -i linux-image-${UNAME_R_3}_${UNAME_R_3}-1_*.deb 


exit 0
