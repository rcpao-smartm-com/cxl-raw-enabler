#!/bin/bash
# Minimal non-interactive install of the cxlraw kernel RPM in this directory.
# Run as root from this directory (or with paths adjusted).
set -euo pipefail

# SLES 15 SP6 kernel version with cxlraw support (as of 2026-07-30)
KVER=6.4.0-150600.23.81-cxlraw-default
KERNEL_RPM=kernel-6.4.0_150600.23.81_cxlraw_default-1.x86_64.rpm

rpm -Uvh --replacepkgs --nosignature "$KERNEL_RPM"

[ -f /etc/modprobe.d/10-unsupported-modules.conf ] || \
  cp /lib/modprobe.d/10-unsupported-modules.conf /etc/modprobe.d/10-unsupported-modules.conf
if grep -qE '^[[:space:]]*allow_unsupported_modules[[:space:]]+' /etc/modprobe.d/10-unsupported-modules.conf; then
  sed -i 's/^\([[:space:]]*allow_unsupported_modules[[:space:]]*\)0/\11/' /etc/modprobe.d/10-unsupported-modules.conf
else
  echo 'allow_unsupported_modules 1' >> /etc/modprobe.d/10-unsupported-modules.conf
fi
grep -qF 'cxlraw: required for cxl_mem' /etc/modprobe.d/10-unsupported-modules.conf || \
  sed -i '/^[[:space:]]*allow_unsupported_modules[[:space:]]/i# cxlraw: required for cxl_mem / cxl_* modules' \
    /etc/modprobe.d/10-unsupported-modules.conf

command -v dracut >/dev/null || zypper -n install dracut
dracut -f "/boot/initrd-${KVER}" "$KVER"

grub2-mkconfig -o /boot/grub2/grub.cfg
command -v update-bootloader >/dev/null && update-bootloader --refresh
