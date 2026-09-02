#!/bin/bash -vx
set -euo pipefail

# Run this in a terminal where sudo works (password prompt OK).
# Prerequisites: ~/kernel-work/linux checked out at v7.0 with patches/v7.0 applied.

UNAME_R=$(uname -r)
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LINUX_SRC="${HOME}/kernel-work/linux"

[ -d "${LINUX_SRC}/drivers/cxl" ] || {
	echo "error $0:$LINENO: ${LINUX_SRC}/drivers/cxl not found; run ub26-7.0.0.sh through git checkout + patch first" >&2
	exit $LINENO
}

# A prior out-of-tree build (make M=~/kernel-work/.../drivers/cxl) can corrupt
# drivers/cxl/Makefile and leave source -> . plus arch/; that makes make loop.
git -C "${LINUX_SRC}" checkout --force -- drivers/cxl/Makefile drivers/cxl/core/Makefile 2>/dev/null || true
rm -rf "${LINUX_SRC}/drivers/cxl/arch" "${LINUX_SRC}/drivers/cxl/source" "${LINUX_SRC}/drivers/cxl/.tmp_"*
sudo rm -rf "/lib/modules/${UNAME_R}/build/drivers/cxl/arch" \
	"/lib/modules/${UNAME_R}/build/drivers/cxl/source" \
	"/lib/modules/${UNAME_R}/build/drivers/cxl/.tmp_"*

# Copy patched sources only (skip out-of-tree build junk from ~/kernel-work).
sudo rsync -a --delete \
	--exclude='.*' --exclude='*.o' --exclude='*.ko' --exclude='*.mod' \
	--exclude='*.cmd' --exclude='Module.symvers' --exclude='modules.order' \
	--exclude='arch/' --exclude='source' \
	"${LINUX_SRC}/drivers/cxl/" "/lib/modules/${UNAME_R}/build/drivers/cxl/"
if [ -f "${LINUX_SRC}/include/uapi/linux/cxl_mem.h" ]; then
	sudo cp "${LINUX_SRC}/include/uapi/linux/cxl_mem.h" \
		"/lib/modules/${UNAME_R}/build/include/uapi/linux/cxl_mem.h"
fi

cd "/lib/modules/${UNAME_R}/build"

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

sudo make olddefconfig
sudo make include/generated/autoconf.h

sudo make M=drivers/cxl clean
sudo make M=drivers/cxl modules
find drivers/cxl -name '*.ko'

sudo mkdir -p "/lib/modules/${UNAME_R}/updates/drivers/cxl/core"
sudo mkdir -p "/lib/modules/${UNAME_R}/updates/drivers/cxl/"

sudo cp drivers/cxl/core/cxl_core.ko "/lib/modules/${UNAME_R}/updates/drivers/cxl/core/"
sudo cp drivers/cxl/cxl_*.ko "/lib/modules/${UNAME_R}/updates/drivers/cxl/"
sudo depmod -a

sudo lsmod | grep cxl | awk '{print $1}' | xargs -r -n1 sudo modprobe -r || true

sudo modprobe cxl_acpi && sudo modprobe cxl_pci && sudo modprobe cxl_mem

sudo update-initramfs -u

lsmod | grep cxl
ls -la /dev/cxl/ || true

mount | grep debugfs
sudo ls -la /sys/kernel/debug/cxl/mbox/
sudo cat /sys/kernel/debug/cxl/mbox/raw_allow_all
echo Y | sudo tee /sys/kernel/debug/cxl/mbox/raw_allow_all
sudo cat /sys/kernel/debug/cxl/mbox/raw_allow_all

echo "Done. Built from ${LINUX_SRC} for kernel ${UNAME_R}."
