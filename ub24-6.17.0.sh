#!/bin/bash -vx
set -euo pipefail

# https://customer-jira.microchip.com/projects/DCSCMCSMART/issues/DCSCMCSMART-264

cat /etc/os-release
source /etc/os-release
# PRETTY_NAME="Ubuntu 24.04.4 LTS"
# NAME="Ubuntu"
# VERSION_ID="24.04"
# VERSION="24.04.4 LTS (Noble Numbat)"
# VERSION_CODENAME=noble
# ID=ubuntu
# ID_LIKE=debian
# HOME_URL="https://www.ubuntu.com/"
# SUPPORT_URL="https://help.ubuntu.com/"
# BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
# PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
# UBUNTU_CODENAME=noble
# LOGO=ubuntu-logo
[[ "$NAME" != "Ubuntu" ]] && echo "error $0:$LINENO: only Ubuntu is supported by this script." && exit $LINENO
[[ "$VERSION_ID" != "24.04" ]] && echo "error $0:$LINENO: only Ubuntu 24.04 is supported by this script." && exit $LINENO

# Prerequisites
sudo apt-get -y --fix-broken install
# sudo apt-get -y install build-essential
sudo apt-get -y install libncurses-dev gawk flex bison openssl libssl-dev dkms libelf-dev libudev-dev libpci-dev libiberty-dev autoconf llvm
sudo apt-get -y install zstd
sudo apt-get -y install rustc

# sudo add-apt-repository universe
sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
sudo apt-get update
sudo apt-get -y install gcc-14 g++-14

# https://kernel.ubuntu.com/mainline/v6.17/amd64/
wget --no-clobber https://kernel.ubuntu.com/mainline/v6.17/amd64/linux-headers-6.17.0-061700-generic_6.17.0-061700.202509282239_amd64.deb
wget --no-clobber https://kernel.ubuntu.com/mainline/v6.17/amd64/linux-headers-6.17.0-061700_6.17.0-061700.202509282239_all.deb
wget --no-clobber https://kernel.ubuntu.com/mainline/v6.17/amd64/linux-image-unsigned-6.17.0-061700-generic_6.17.0-061700.202509282239_amd64.deb
wget --no-clobber https://kernel.ubuntu.com/mainline/v6.17/amd64/linux-modules-6.17.0-061700-generic_6.17.0-061700.202509282239_amd64.deb
sudo dpkg -i *.deb
# sudo reboot
# uname -r

cd /lib/modules/$(uname -r)/build

sudo apt-get update
sudo apt-get -y install linux-headers-$(uname -r)
sudo apt-get -y --fix-broken install

mkdir -p ~/kernel-work && cd ~/kernel-work

[ ! -d linux ] && git clone --no-checkout https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
cd linux
git sparse-checkout init --cone
git sparse-checkout set drivers/cxl include/linux/cxl.h

git checkout v6.17

sudo cp -r drivers/cxl/* /lib/modules/$(uname -r)/build/drivers/cxl/

cd /lib/modules/$(uname -r)/build/drivers/cxl
ls -la

cd /lib/modules/$(uname -r)/build
grep CONFIG_CXL_MEM_RAW_COMMANDS .config

sudo scripts/config --file .config --set-val CONFIG_CXL_MEM_RAW_COMMANDS y
grep CONFIG_CXL_MEM_RAW_COMMANDS .config

sudo make olddefconfig

sudo make include/generated/autoconf.h

grep CONFIG_CXL_MEM_RAW_COMMANDS include/generated/autoconf.h

cd /lib/modules/$(uname -r)/build
sudo make M=drivers/cxl modules
find drivers/cxl -name "*.ko"

sudo mkdir -p /lib/modules/$(uname -r)/updates/drivers/cxl/core
sudo mkdir -p /lib/modules/$(uname -r)/updates/drivers/cxl/

cd /lib/modules/$(uname -r)/build

sudo cp drivers/cxl/core/cxl_core.ko /lib/modules/$(uname -r)/updates/drivers/cxl/core/
sudo cp drivers/cxl/cxl_*.ko /lib/modules/$(uname -r)/updates/drivers/cxl/
# Update module dependencies
sudo depmod -a

sudo lsmod | grep cxl | awk '{print $1}' | xargs -r -n1 sudo modprobe -r

sudo modprobe cxl_acpi && sudo modprobe cxl_pci && sudo modprobe cxl_mem

sudo update-initramfs -u

lsmod | grep cxl

ls -la /dev/cxl/

hexdump -C /lib/modules/$(uname -r)/updates/cxl_core.ko | grep -A 3 -B 3 "02 00 00 00.*ff ff ff ff.*ff ff ff ff"

# Verify debugfs is mounted
mount | grep debugfs
# Check for CXL RAW commands control
sudo ls -la /sys/kernel/debug/cxl/mbox/
# Should show: raw_allow_all
# Check current RAW commands status
sudo cat /sys/kernel/debug/cxl/mbox/raw_allow_all
# Shows: N (disabled) or Y (enabled)
# Enable RAW Commands (Optional)
# Enable RAW commands for testing
echo Y | sudo tee /sys/kernel/debug/cxl/mbox/raw_allow_all
# Verify enabled
sudo cat /sys/kernel/debug/cxl/mbox/raw_allow_all
# Should show: Y

