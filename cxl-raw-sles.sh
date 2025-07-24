#!/bin/bash -vx


# Allow incoming SSH connections through the firewall
# sudo firewall-cmd --permanent --add-service=ssh
# sudo firewall-cmd --reload


# script cxl-raw-sles_$(date +%Y%m%d-%H%M%S)_$(hostname)_$(uname -r).txt
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOGFILE=cxl-raw-sles_${TIMESTAMP}_$(hostname)_$(uname -r).txt


# NAME="SLES"
# VERSION="15-SP7"
# VERSION_ID="15.7"
# PRETTY_NAME="SUSE Linux Enterprise Server 15 SP7"
# ID="sles"
# ID_LIKE="suse"
# ANSI_COLOR="0;32"
# CPE_NAME="cpe:/o:suse:sles:15:sp7"
# DOCUMENTATION_URL="https://documentation.suse.com/"


# https://chatgpt.com/
# "for sles16 ,change a kernel config variable and recompile"
#sudo zypper install -y -t pattern devel_kernel # chatgpt, copilot
# 'devel_kernel' not found in package names. Trying capabilities.
# No provider of 'devel_kernel' found.
#sudo zypper install -y ncurses-devel bc make gcc # chatgpt
#sudo zypper install -y ncurses-devel bc libopenssl-devel dwarves # copilot

#
#pushd /usr/src # chatgpt
#  sudo zypper source-install -d kernel-default # chatgpt, copilot
#popd

# cd /usr/src/linux-* # chatgpt
# cd /usr/src/packages/SOURCES # copilot


# copilot

sudo SUSEConnect --status
# sudo SUSEConnect -r <your_registration_code>
sudo SUSEConnect -p sle-module-desktop-applications/15.7/x86_64 -r 95FA7263714A0E84
sudo SUSEConnect -p sle-module-development-tools/15.7/x86_64
sudo zypper install -y kernel-default-devel gcc make ncurses-devel bc libopenssl-devel dwarves
sudo zypper install -y -f kernel-source kernel-devel 

#git clone https://github.com/openSUSE/kernel-source -b SLE15-SP7
#cd kernel-source


#sudo zypper install -t pattern devel_basis
# 'devel_basis' not found in package names. Trying capabilities.
# No provider of 'devel_basis' found.
#sudo zypper install ncurses-devel bc libopenssl-devel dwarves rpm-build


# $UNAME_R is the currently running kernel or the kernel you wish to build
# UNAME_R=6.1.0-28-amd64
# UNAME_R_3=6.1.0
# UNAME_R_2=6.1
# KVERS=6.1.0-28
UNAME_R=$(uname -r)
UNAME_R_3=${UNAME_R%%-*} # "6.1.0" remove first/greedy "-##-amd64"
UNAME_R_2=${UNAME_R%.*} # "6.1" remove last ".*"
KVERS=${UNAME_R%-*} # "6.1.0-28" remove "-amd64"


pushd /usr/src/linux/
  sudo chown -R $USER:users .

  scripts/config --disable SYSTEM_TRUSTED_KEYS
  scripts/config --disable SYSTEM_REVOCATION_KEYS

  make mrproper

  # [ ! -f .config ] && cp /boot/config-${UNAME_R} .config
  cp /boot/config-${UNAME_R} .config # 'make oldconfig' changes kernel version comment?
  #make oldconfig
  # yes "" | make oldconfig # https://serverfault.com/a/116317/221343
  make olddefconfig # https://serverfault.com/a/538150/221343
  # make menuconfig # This is the text based menu config 
  # make xconfig # This is the GUI based menu config 

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


  mkdir -p certs
  openssl req -new -x509 -newkey rsa:2048 -keyout certs/signing_key.pem -out certs/signing_key.x509 -days 36500 -nodes -subj "/CN=Dummy Kernel Signing Key/"
  # pushd /usr/src/linux/certs
  # ln -sf signing_key.pem .kernel_signing_key.pem
  ln -sf /usr/src/linux/certs/signing_key.pem /usr/src/linux/.kernel_signing_key.pem
  # popd


  # make clean
  make prepare
  make modules_prepare

  make -j$(nproc)
  sudo make modules_install
  sudo make install
  sudo make rpm-pkg

  sudo grub2-mkconfig -o /boot/grub2/grub.cfg

  # sudo reboot

popd


exit 0
