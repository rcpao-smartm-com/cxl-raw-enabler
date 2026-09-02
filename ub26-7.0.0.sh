#!/bin/bash -vx
set -euo pipefail

# https://customer-jira.microchip.com/projects/DCSCMCSMART/issues/DCSCMCSMART-264

cat /etc/os-release
source /etc/os-release
# PRETTY_NAME="Ubuntu 26.04.1 LTS"
# NAME="Ubuntu"
# VERSION_ID="26.04"
# VERSION="26.04.1 LTS (Resolute Raccoon)"
# VERSION_CODENAME=resolute
# ID=ubuntu
# ID_LIKE=debian
# HOME_URL="https://www.ubuntu.com/"
# SUPPORT_URL="https://help.ubuntu.com/"
# BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
# PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
# UBUNTU_CODENAME=resolute
# LOGO=ubuntu-logo
[[ "$NAME" != "Ubuntu" ]] && echo "error $0:$LINENO: only Ubuntu is supported by this script." && exit $LINENO
[[ "$VERSION_ID" != "26.04" ]] && echo "error $0:$LINENO: only Ubuntu 26.04 is supported by this script." && exit $LINENO

UNAME_R=$(uname -r)

# Prerequisites
sudo apt-get -y --fix-broken install
sudo apt-get -y install libncurses-dev gawk flex bison openssl libssl-dev dkms libelf-dev libudev-dev libpci-dev libiberty-dev autoconf llvm
sudo apt-get -y install zstd
sudo apt-get -y install rustc

sudo apt-get update
sudo apt-get -y install linux-headers-${UNAME_R}
sudo apt-get -y --fix-broken install

# Match the compiler used to build the running kernel.
GCCVERSTR=$(grep -Eo 'gcc-[0-9]+' /boot/config-${UNAME_R})
GCCVERNUM=${GCCVERSTR#gcc-}
sudo apt-get -y install ${GCCVERSTR}
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/${GCCVERSTR} ${GCCVERNUM}
yes "" | sudo update-alternatives --config gcc
gcc --version

[ -d /lib/modules/${UNAME_R}/build ] || {
	echo "error $0:$LINENO: /lib/modules/${UNAME_R}/build not found; install linux-headers-${UNAME_R}" >&2
	exit $LINENO
}

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

mkdir -p ~/kernel-work && cd ~/kernel-work

[ ! -d linux ] && git clone --no-checkout https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
cd linux
git sparse-checkout init --cone
git sparse-checkout set drivers/cxl include/linux/cxl.h include/uapi/linux

git checkout v7.0
# Start from clean v7.0 CXL sources if this script is re-run.
git checkout --force -- drivers/cxl include/uapi/linux/cxl_mem.h 2>/dev/null || true

# Map Secondary Mailbox and allow CXL_MEM_SEND_COMMAND to target it.
python3 "${SCRIPT_DIR}/patches/v7.0/apply-secondary-mbox.py" "$(pwd)"

git checkout --force -- drivers/cxl/Makefile drivers/cxl/core/Makefile
rm -rf drivers/cxl/arch drivers/cxl/source drivers/cxl/.tmp_*
sudo rm -rf /lib/modules/${UNAME_R}/build/drivers/cxl/arch \
	/lib/modules/${UNAME_R}/build/drivers/cxl/source \
	/lib/modules/${UNAME_R}/build/drivers/cxl/.tmp_*

sudo rsync -a --delete \
	--exclude='.*' --exclude='*.o' --exclude='*.ko' --exclude='*.mod' \
	--exclude='*.cmd' --exclude='Module.symvers' --exclude='modules.order' \
	--exclude='arch/' --exclude='source' \
	drivers/cxl/ /lib/modules/${UNAME_R}/build/drivers/cxl/
if [ -f include/uapi/linux/cxl_mem.h ]; then
  sudo cp include/uapi/linux/cxl_mem.h /lib/modules/${UNAME_R}/build/include/uapi/linux/cxl_mem.h
fi

cd /lib/modules/${UNAME_R}/build/drivers/cxl
ls -la

cd /lib/modules/${UNAME_R}/build
grep CONFIG_CXL_MEM_RAW_COMMANDS .config

sudo scripts/config --file .config --set-val CONFIG_CXL_MEM_RAW_COMMANDS y
sudo scripts/config --file .config --enable CONFIG_ACPI_NFIT
sudo scripts/config --file .config --enable CONFIG_TRANSPARENT_HUGEPAGE
sudo scripts/config --file .config --enable CONFIG_TRANSPARENT_HUGEPAGE_ALWAYS
sudo scripts/config --file .config --disable CONFIG_TRANSPARENT_HUGEPAGE_MADVISE
sudo scripts/config --file .config --enable CONFIG_DEV_DAX
sudo scripts/config --file .config --enable CONFIG_ND_BTT
sudo scripts/config --file .config --enable CONFIG_NVDIMM_SECURITY_TEST
sudo scripts/config --file .config --enable CONFIG_BLK_DEV_PMEM
sudo scripts/config --file .config --enable CONFIG_IO_STRICT_DEVMEM
grep CONFIG_CXL_MEM_RAW_COMMANDS .config
grep CONFIG_ACPI_NFIT .config
grep CONFIG_TRANSPARENT_HUGEPAGE .config
grep CONFIG_DEV_DAX .config
grep CONFIG_ND_BTT .config
grep CONFIG_NVDIMM_SECURITY_TEST .config
grep CONFIG_BLK_DEV_PMEM .config
grep CONFIG_IO_STRICT_DEVMEM .config

sudo make olddefconfig

sudo make include/generated/autoconf.h

grep CONFIG_CXL_MEM_RAW_COMMANDS include/generated/autoconf.h
grep CONFIG_ACPI_NFIT include/generated/autoconf.h
grep CONFIG_DEV_DAX include/generated/autoconf.h
grep CONFIG_BLK_DEV_PMEM include/generated/autoconf.h

cd /lib/modules/${UNAME_R}/build
sudo make M=drivers/cxl clean
sudo make M=drivers/cxl modules
find drivers/cxl -name "*.ko"

sudo mkdir -p /lib/modules/${UNAME_R}/updates/drivers/cxl/core
sudo mkdir -p /lib/modules/${UNAME_R}/updates/drivers/cxl/

cd /lib/modules/${UNAME_R}/build

sudo cp drivers/cxl/core/cxl_core.ko /lib/modules/${UNAME_R}/updates/drivers/cxl/core/
sudo cp drivers/cxl/cxl_*.ko /lib/modules/${UNAME_R}/updates/drivers/cxl/
# Update module dependencies
sudo depmod -a

sudo lsmod | grep cxl | awk '{print $1}' | xargs -r -n1 sudo modprobe -r

sudo modprobe cxl_acpi && sudo modprobe cxl_pci && sudo modprobe cxl_mem

sudo update-initramfs -u

lsmod | grep cxl

ls -la /dev/cxl/

hexdump -C /lib/modules/${UNAME_R}/updates/drivers/cxl/core/cxl_core.ko | grep -A 3 -B 3 "02 00 00 00.*ff ff ff ff.*ff ff ff ff"

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
