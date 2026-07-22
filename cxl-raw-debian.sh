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

KERNELDIR=linux-${UNAME_R_3}


# https://www.debian.org/doc/manuals/debian-kernel-handbook/ch-common-tasks.html


# sudo apt-get -y install linux-source
# tar xaf /usr/src/linux-source-${UNAME_R_2}


sudo apt-get -y install build-essential fakeroot
sudo apt-get -y build-dep linux

apt-get source linux # gets the latest kernel version for this debian release, not the currently running kernel version, and no backports

pushd linux-${UNAME_R_3}

  # [ ! -f .config ] && cp /boot/config-${UNAME_R} .config
  #                     cp /boot/config-${UNAME_R} .config # 'make oldconfig' changes kernel version comment?
  # yes "" | make oldconfig # https://serverfault.com/a/116317/221343
  make olddefconfig # https://serverfault.com/a/538150/221343
  # make menuconfig # This is the text based menu config 
  # make xconfig # This is the GUI based menu config 
  #
  # Enable CONFIG_CXL_MEM_RAW_COMMANDS=y
  # Device Drivers > PCI support > CXL (Compute Express Link) Devices Support > 
  #   [*] RAW Command Interface for Memory Devices (default=[_])
  # Enable CONFIG_CXL_REGION_INVALIDATION_TEST=y
  # NVDIMM / DAX / PMEM and related options
  #
  # CFG=.config
  CFG=debian/config/config
  CFGBAK=${CFG}.bak
  [ ! -f ${CFGBAK} ] && cp ${CFG} ${CFGBAK}
  ./scripts/config --file ${CFG} --enable CONFIG_CXL_MEM_RAW_COMMANDS
  ./scripts/config --file ${CFG} --enable CONFIG_CXL_REGION_INVALIDATION_TEST
  ./scripts/config --file ${CFG} --enable CONFIG_ACPI_NFIT
  ./scripts/config --file ${CFG} --enable CONFIG_TRANSPARENT_HUGEPAGE
  ./scripts/config --file ${CFG} --enable CONFIG_TRANSPARENT_HUGEPAGE_ALWAYS
  ./scripts/config --file ${CFG} --disable CONFIG_TRANSPARENT_HUGEPAGE_MADVISE
  ./scripts/config --file ${CFG} --enable CONFIG_DEV_DAX
  ./scripts/config --file ${CFG} --enable CONFIG_ND_BTT
  ./scripts/config --file ${CFG} --enable CONFIG_NVDIMM_SECURITY_TEST
  ./scripts/config --file ${CFG} --enable CONFIG_BLK_DEV_PMEM
  ./scripts/config --file ${CFG} --enable CONFIG_IO_STRICT_DEVMEM
  #
  # diff /boot/config-${UNAME_R} ${CFG}${CFGBAK}
  diff ${CFG} ${CFGBAK}
  grep CONFIG_CXL_MEM_RAW_COMMANDS ${CFG}
  grep CONFIG_CXL_REGION_INVALIDATION_TEST ${CFG}
  grep CONFIG_ACPI_NFIT ${CFG}
  grep CONFIG_TRANSPARENT_HUGEPAGE ${CFG}
  grep CONFIG_DEV_DAX ${CFG}
  grep CONFIG_ND_BTT ${CFG}
  grep CONFIG_NVDIMM_SECURITY_TEST ${CFG}
  grep CONFIG_BLK_DEV_PMEM ${CFG}
  grep CONFIG_IO_STRICT_DEVMEM ${CFG}

  # Debian custom version suffix:
  Suffix="+cxlraw1"
  CurrVer=$(head -n 1 debian/changelog)
  if [[ $CurrVer != *"$Suffix"* ]]; then
    Char=")"
    NewVer="${CurrVer%%"${Char}"*}$Suffix$Char${CurrVer#*"$Char"}"
    echo $NewVer
    NewVer=
    sed -i "1s/^/$NewVer\n\n  [ Roger C. Pao ]\n  * CONFIG_CXL_MEM_RAW_COMMANDS=y and NVDIMM/DAX/PMEM options\n\n -- Roger C. Pao <roger.pao@smartm.com>  $(date +"%a, %d %b %Y %H:%M:%S %z")\n\n/" debian/changelog
    sed -i "1s/ trixie;/ local;/" debian/changelog
    head -n 10 debian/changelog
  fi

  make clean

  # make deb-pkg
    # dpkg-source: error: unrepresentable changes to source
    # dpkg-buildpackage: error: dpkg-source -i.git -b . subprocess returned exit status 1

  date
  time fakeroot debian/rules binary
  date

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

    # ls -l linux-*.deb
    # -rw-r--r-- 1 rcpao rcpao      1108 Dec  5 13:39 linux-doc_6.12.57-1_all.deb
    # -rw-r--r-- 1 rcpao rcpao  39297108 Dec  5 13:39 linux-doc-6.12_6.12.57-1_all.deb
    # -rw-r--r-- 1 rcpao rcpao   9176640 Dec  5 15:39 linux-headers-6.12.57_6.12.57-2_amd64.deb
    # -rw-r--r-- 1 rcpao rcpao  11195512 Dec  5 13:40 linux-headers-6.12.57+deb13-common_6.12.57-1_all.deb
    # -rw-r--r-- 1 rcpao rcpao   9553336 Dec  5 13:41 linux-headers-6.12.57+deb13-common-rt_6.12.57-1_all.deb
    # -rw-r--r-- 1 rcpao rcpao 109651524 Dec  5 15:39 linux-image-6.12.57_6.12.57-2_amd64.deb
    # -rw-r--r-- 1 rcpao rcpao 999674448 Dec  5 15:41 linux-image-6.12.57-dbg_6.12.57-2_amd64.deb
    # -rw-r--r-- 1 rcpao rcpao   2691676 Dec  5 13:39 linux-libc-dev_6.12.57-1_all.deb
    # -rw-r--r-- 1 rcpao rcpao   1395728 Dec  5 15:38 linux-libc-dev_6.12.57-2_amd64.deb
    # -rw-r--r-- 1 rcpao rcpao      1100 Dec  5 13:40 linux-source_6.12.57-1_all.deb
    # -rw-r--r-- 1 rcpao rcpao 152583840 Dec  5 13:41 linux-source-6.12_6.12.57-1_all.deb
    # -rw-r--r-- 1 rcpao rcpao   1178620 Dec  5 13:41 linux-support-6.12.57+deb13_6.12.57-1_all.deb

  # ? fakeroot debian/rules source

popd


ls -l linux-*.deb
sudo dpkg -i linux-image-${UNAME_R_3}_${UNAME_R_3}-[1-9]_amd64.deb \
             linux-headers-${UNAME_R_3}*-common_${UNAME_R_3}-[1-9]_all.deb \
             linux-libc-dev_${UNAME_R_3}-[1-9]_*.deb


TIMESTAMP=$(date +%Y%m%d-%H%M%S)

exit 0
