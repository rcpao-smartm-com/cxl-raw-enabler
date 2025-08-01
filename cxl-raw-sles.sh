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
#sudo SUSEConnect -r 95FA7263714A0E84 # 15.7
#sudo SUSEConnect -r 24716629f4906d25 # 16beta4 = 16.0; expires Nov 10, 2025
source sles-registration-key
sudo SUSEConnect -r $SLES_REGISTRATION_KEY # 16beta4 = 16.0; expires Nov 10, 2025

#sudo SUSEConnect -p sle-module-desktop-applications/15.7/x86_64
#sudo SUSEConnect -p sle-module-development-tools/15.7/x86_64
source /etc/os-release
# sudo SUSEConnect -p sle-module-desktop-applications/$VERSION_ID/x86_64
# sudo SUSEConnect -p sle-module-development-tools/$VERSION_ID/x86_64

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
  cd certs
    # Generate a new X.509 certificate and private key in PEM format
    # openssl req -new -x509 -newkey rsa:2048 -keyout certs/signing_key.pem -out certs/signing_key.x509 -nodes -days 36500 \
    #   -subj "/CN=Custom Kernel Signing/"
 
    [ ! -f MOK.key.pem ] && openssl req -new -x509 -newkey rsa:4096 -keyout MOK.key.pem -out MOK.crt.pem -nodes -days 36524 -subj "/CN=cxl-raw-sles.sh Custom Kernel Signing/"

    utilities/prepare-mok-signing.sh # from Copilot AI

: <<'COMMENT'
    file MOK.key.pem 
    cat MOK.key.pem 
    openssl rsa -in MOK.key.pem -outform PEM -out MOK.key.txt
    file MOK.key.txt
    cat MOK.key.txt
    diff -s MOK.key.pem MOK.key.txt

    file MOK.crt.pem
    cat MOK.crt.pem
    openssl x509 -in MOK.crt.pem -outform DER -out MOK.crt.der
    file MOK.crt.der
    xxd -g1 MOK.crt.der

    echo "Note: sudo mokutil --import MOK.crt.der" # ToDo: MOK enrollment

    # pushd /usr/src/linux/certs
    # ln -sf signing_key.pem .kernel_signing_key.pem
    #[ -L /usr/src/linux/.kernel_signing_key.pem ] && rm /usr/src/linux/.kernel_signing_key.pem
    #ln -sf /usr/src/linux/certs/MOK.key.pem /usr/src/linux/.kernel_signing_key.pem
    # ln -sf /usr/src/linux/certs/MOK.key.pem /usr/src/linux/certs/signing_key.x509
    # popd

COMMENT

  cd ..


  # make clean
  make prepare
  make modules_prepare

  make -j$(nproc)


  CMD="sudo make modules_install; \
sudo make install; \
sudo grub2-mkconfig -o /boot/grub2/grub.cfg; \
sudo make rpm-pkg"
  # ToDo install rpms

  while true; do
    read -n 1 -p "Press y to install the newly built kernel, or n to skip: " YN
    case $YN in
        [y] ) break;;
        [n] ) break;;
        * ) echo "Press y or n: ";;
    esac
  done

  echo "\$YN=\"$YN\""
  if [ "$YN" == "y" ]; then
    #sudo dnf -y install --nogpgcheck \
    #  ./x86_64/kernel-modules-core-${KVERSTR}.rpm \
    #  ./x86_64/kernel-core-${KVERSTR}.rpm \
    #  ./x86_64/kernel-modules-${KVERSTR}.rpm \
    #  ./x86_64/kernel-${KVERSTR}.rpm
    echo "Running: \"$CMD\""
    $CMD
  else
    echo "Skipped: \"$CMD\""
  fi


  # sudo reboot

popd


TIMESTAMP=$(date +%Y%m%d-%H%M%S)

exit 0
