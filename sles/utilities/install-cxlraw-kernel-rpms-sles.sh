#!/bin/bash
# Install pre-built cxlraw kernel RPMs on SLES 15 SP6 x86_64.
# Intended for curl | sudo bash on a target after RPMs are in /tmp (or RPM_URL_BASE).
set -euo pipefail

KVER="${KVER:-6.4.0-150600.23.81-cxlraw-default}"
RPM_DIR="${RPM_DIR:-/tmp}"
RPM_URL_BASE="${RPM_URL_BASE:-}"
AUTO_YES=false
NO_REBOOT=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [-y] [--no-reboot]

Install unsigned cxlraw kernel RPMs, enable unsupported modules, rebuild
initrd, and update GRUB.

Environment:
  KVER          Kernel release to boot (default: ${KVER})
  RPM_DIR       Directory with kernel RPMs (default: ${RPM_DIR})
  RPM_URL_BASE  If set, download kernel + kernel-headers RPMs from this URL
                prefix before install (filenames derived from KVER)

Options:
  -y, --yes       Reboot without prompting when install succeeds
  --no-reboot     Skip reboot (print reminder instead)
  -h, --help      Show this help

Examples:
  scp kernel-rpms-*/*.rpm target:/tmp/
  curl -fsSL https://example/cxl-raw-enabler/raw/main/sles/utilities/install-cxlraw-kernel-rpms-sles.sh | sudo bash

  curl -fsSL https://example/.../sles/utilities/install-cxlraw-kernel-rpms-sles.sh | sudo bash -s -- -y

  RPM_URL_BASE=https://files.example/kernel-rpms \\
    curl -fsSL https://example/.../sles/utilities/install-cxlraw-kernel-rpms-sles.sh | sudo bash
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes)
      AUTO_YES=true
      ;;
    --no-reboot)
      NO_REBOOT=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "error: run as root (e.g. curl -fsSL URL | sudo bash)" >&2
    exit 1
  fi
}

check_sles() {
  if [ ! -f /etc/os-release ]; then
    echo "error: /etc/os-release not found" >&2
    exit 1
  fi
  # shellcheck source=/dev/null
  source /etc/os-release
  if [ "${ID:-}" != "sles" ]; then
    echo "warning: expected SLES (ID=sles), found ID=${ID:-unknown}"
  fi
}

check_root_rw() {
  if findmnt -no OPTIONS / | grep -q '\bro\b'; then
    echo "error: root filesystem is read-only; fix storage I/O then: mount -o remount,rw /" >&2
    exit 1
  fi
}

rpm_tag_from_kver() {
  echo "$1" | tr '-' '_'
}

default_rpm_names() {
  local tag
  tag="$(rpm_tag_from_kver "$KVER")"
  KERNEL_RPM="${RPM_DIR}/kernel-${tag}-1.x86_64.rpm"
  HEADERS_RPM="${RPM_DIR}/kernel-headers-${tag}-1.x86_64.rpm"
}

download_rpms() {
  default_rpm_names
  local base="${RPM_URL_BASE%/}"
  echo "==> Downloading RPMs from ${base}/"
  curl -fsSL -o "$KERNEL_RPM" "${base}/$(basename "$KERNEL_RPM")"
  curl -fsSL -o "$HEADERS_RPM" "${base}/$(basename "$HEADERS_RPM")"
}

find_local_rpms() {
  shopt -s nullglob
  local kernel_rpms=( "$RPM_DIR"/kernel-[0-9]*_"${KVER//-/_}"*.rpm )
  local headers_rpms=( "$RPM_DIR"/kernel-headers-[0-9]*_"${KVER//-/_}"*.rpm )

  if [ -n "${KERNEL_RPM:-}" ] && [ -f "$KERNEL_RPM" ]; then
    :
  elif [ "${#kernel_rpms[@]}" -ge 1 ]; then
    KERNEL_RPM="${kernel_rpms[0]}"
  else
    default_rpm_names
  fi

  if [ -n "${HEADERS_RPM:-}" ] && [ -f "$HEADERS_RPM" ]; then
    :
  elif [ "${#headers_rpms[@]}" -ge 1 ]; then
    HEADERS_RPM="${headers_rpms[0]}"
  elif [ -z "${HEADERS_RPM:-}" ]; then
    default_rpm_names
  fi

  if [ ! -f "$KERNEL_RPM" ]; then
    echo "error: kernel RPM not found: ${KERNEL_RPM}" >&2
    echo "       copy RPMs to ${RPM_DIR} or set RPM_URL_BASE" >&2
    exit 1
  fi
  if [ ! -f "$HEADERS_RPM" ]; then
    echo "error: kernel-headers RPM not found: ${HEADERS_RPM}" >&2
    echo "       copy RPMs to ${RPM_DIR} or set RPM_URL_BASE" >&2
    exit 1
  fi
}

install_rpms() {
  echo "==> Installing ${KERNEL_RPM} ${HEADERS_RPM}"
  rpm -Uvh --replacepkgs --nosignature "$KERNEL_RPM" "$HEADERS_RPM"
}

allow_unsupported_modules() {
  local src=/lib/modprobe.d/10-unsupported-modules.conf
  local dst=/etc/modprobe.d/10-unsupported-modules.conf

  if [ ! -f "$src" ]; then
    echo "error: ${src} not found" >&2
    exit 1
  fi

  if [ ! -f "$dst" ]; then
    echo "==> Installing ${dst} from ${src}"
    cp "$src" "$dst"
  fi

  if grep -qE '^[[:space:]]*allow_unsupported_modules[[:space:]]+0' "$dst"; then
    echo "==> Enabling allow_unsupported_modules in ${dst}"
    sed -i 's/^\([[:space:]]*allow_unsupported_modules[[:space:]]*\)0/\11/' "$dst"
  elif grep -qE '^[[:space:]]*allow_unsupported_modules[[:space:]]+1' "$dst"; then
    echo "==> allow_unsupported_modules already enabled in ${dst}"
  else
    echo "allow_unsupported_modules 1" >> "$dst"
  fi
}

ensure_dracut() {
  if ! command -v dracut >/dev/null; then
    echo "==> Installing dracut"
    zypper -n install dracut
  fi
}

rebuild_initrd() {
  local initrd="/boot/initrd-${KVER}"
  ensure_dracut
  echo "==> Rebuilding initrd ${initrd}"
  dracut -f "$initrd" "$KVER"
}

update_grub() {
  echo "==> Updating GRUB"
  grub2-mkconfig -o /boot/grub2/grub.cfg
}

verify_boot_files() {
  if [ ! -f "/boot/vmlinuz-${KVER}" ]; then
    echo "error: /boot/vmlinuz-${KVER} not found after install" >&2
    exit 1
  fi
  echo ""
  echo "Boot images in /boot:"
  ls -1 /boot/vmlinuz-* 2>/dev/null || true
  echo ""
  echo "GRUB should list ${KVER} for CXL raw commands."
  grep -q "CONFIG_CXL_MEM_RAW_COMMANDS=y" "/boot/config-${KVER}" 2>/dev/null \
    && echo "CONFIG_CXL_MEM_RAW_COMMANDS=y confirmed in /boot/config-${KVER}" \
    || echo "warning: CONFIG_CXL_MEM_RAW_COMMANDS not found in /boot/config-${KVER}"
}

maybe_reboot() {
  if [ "$NO_REBOOT" = true ]; then
    echo ""
    echo "Install complete. Reboot manually and select ${KVER} in GRUB."
    return
  fi

  if [ "$AUTO_YES" = false ]; then
    read -r -p "Reboot now? [y/N] " ans
    case "$ans" in
      y|Y|yes|Yes|YES) ;;
      *) echo "Skipped reboot. Select ${KVER} in GRUB after you reboot."; return ;;
    esac
  fi

  echo "==> Rebooting..."
  reboot
}

main() {
  require_root
  check_sles
  check_root_rw

  if [ -n "$RPM_URL_BASE" ]; then
    download_rpms
  else
    find_local_rpms
  fi

  install_rpms
  allow_unsupported_modules
  rebuild_initrd
  update_grub
  verify_boot_files
  maybe_reboot
}

main
