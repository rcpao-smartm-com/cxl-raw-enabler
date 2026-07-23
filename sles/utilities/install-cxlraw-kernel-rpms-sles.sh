#!/bin/bash
# Install pre-built cxlraw kernel RPMs on SLES 15 SP6 x86_64.
# Intended for curl | sudo bash on a target after RPMs are in /tmp (or RPM_URL_BASE).
set -euo pipefail

KVER="${KVER:-6.4.0-150600.23.81-cxlraw-default}"
RPM_DIR="${RPM_DIR:-/tmp}"
RPM_URL_BASE="${RPM_URL_BASE:-}"
AUTO_YES=false
NO_REBOOT=false
WITH_HEADERS=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [-y] [--no-reboot] [--with-headers]

Install unsigned cxlraw kernel RPM, enable unsupported modules, rebuild
initrd, and update GRUB.

By default only the kernel RPM is installed. The companion kernel-headers
RPM from make binrpm-pkg conflicts with SLES linux-glibc-devel
(/usr/include/linux/*); omit it unless you pass --with-headers.

Environment:
  KVER          Kernel release to boot (default: ${KVER})
  RPM_DIR       Directory with kernel RPMs (default: ${RPM_DIR})
  RPM_URL_BASE  If set, download kernel RPM from this URL prefix before
                install (filename derived from KVER). With --with-headers,
                also downloads kernel-headers.
  KERNEL_RPM    Optional explicit path to kernel-*.rpm
  HEADERS_RPM   Optional explicit path to kernel-headers-*.rpm

Options:
  -y, --yes         Reboot without prompting when install succeeds
  --no-reboot       Skip reboot (print reminder instead)
  --with-headers    Also install kernel-headers (may conflict with
                    linux-glibc-devel on SLES)
  -h, --help        Show this help

Examples:
  scp kernel-rpms-*/kernel-*cxlraw*.rpm \\
      utilities/install-cxlraw-kernel-rpms-sles.sh target:/tmp/
  ssh target 'chmod +x /tmp/install-cxlraw-kernel-rpms-sles.sh'
  ssh target 'sudo /tmp/install-cxlraw-kernel-rpms-sles.sh --no-reboot'

  curl -fsSL https://example/.../sles/utilities/install-cxlraw-kernel-rpms-sles.sh \\
    | sudo bash -s -- -y
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
    --with-headers)
      WITH_HEADERS=true
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

# Prefer highest RPM release N in kernel-...-N.x86_64.rpm
pick_newest_rpm() {
  local newest="" newest_n=-1 f base n
  for f in "$@"; do
    [ -f "$f" ] || continue
    base=$(basename "$f" .rpm)
    n="${base##*-}"
    n="${n%%.*}"
    if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -gt "$newest_n" ]; then
      newest_n=$n
      newest=$f
    elif [ -z "$newest" ]; then
      newest=$f
    fi
  done
  echo "$newest"
}

download_rpms() {
  default_rpm_names
  local base="${RPM_URL_BASE%/}"
  echo "==> Downloading kernel RPM from ${base}/"
  curl -fsSL -o "$KERNEL_RPM" "${base}/$(basename "$KERNEL_RPM")"
  if [ "$WITH_HEADERS" = true ]; then
    echo "==> Downloading kernel-headers RPM from ${base}/"
    curl -fsSL -o "$HEADERS_RPM" "${base}/$(basename "$HEADERS_RPM")"
  fi
}

find_local_rpms() {
  shopt -s nullglob
  local tag
  tag="$(rpm_tag_from_kver "$KVER")"
  # Names look like: kernel-6.4.0_150600.23.81_cxlraw_default-3.x86_64.rpm
  local kernel_rpms=( "$RPM_DIR"/kernel-"${tag}"-*.rpm )
  local headers_rpms=( "$RPM_DIR"/kernel-headers-"${tag}"-*.rpm )

  if [ -n "${KERNEL_RPM:-}" ] && [ -f "$KERNEL_RPM" ]; then
    echo "==> Using KERNEL_RPM=${KERNEL_RPM}"
  elif [ "${#kernel_rpms[@]}" -ge 1 ]; then
    echo "==> Found ${#kernel_rpms[@]} kernel RPM(s) for ${tag}:"
    printf '    %s\n' "${kernel_rpms[@]}"
    KERNEL_RPM="$(pick_newest_rpm "${kernel_rpms[@]}")"
    echo "==> Selected newest: ${KERNEL_RPM}"
  else
    default_rpm_names
  fi

  if [ ! -f "$KERNEL_RPM" ]; then
    echo "error: kernel RPM not found: ${KERNEL_RPM}" >&2
    echo "       copy kernel-${tag}-*.rpm to ${RPM_DIR} or set RPM_URL_BASE / KERNEL_RPM" >&2
    exit 1
  fi

  if [ "$WITH_HEADERS" = true ]; then
    if [ -n "${HEADERS_RPM:-}" ] && [ -f "$HEADERS_RPM" ]; then
      echo "==> Using HEADERS_RPM=${HEADERS_RPM}"
    elif [ "${#headers_rpms[@]}" -ge 1 ]; then
      echo "==> Found ${#headers_rpms[@]} kernel-headers RPM(s) for ${tag}:"
      printf '    %s\n' "${headers_rpms[@]}"
      HEADERS_RPM="$(pick_newest_rpm "${headers_rpms[@]}")"
      echo "==> Selected newest headers: ${HEADERS_RPM}"
    else
      default_rpm_names
    fi
    if [ ! -f "$HEADERS_RPM" ]; then
      echo "error: kernel-headers RPM not found: ${HEADERS_RPM}" >&2
      echo "       omit --with-headers, or copy headers RPM / set HEADERS_RPM" >&2
      exit 1
    fi
  else
    HEADERS_RPM=""
  fi
}

install_rpms() {
  echo "==> Installing ${KERNEL_RPM}"
  rpm -Uvh --replacepkgs --nosignature "$KERNEL_RPM"
  if [ "$WITH_HEADERS" = true ]; then
    echo "==> Installing ${HEADERS_RPM}"
    echo "    note: may conflict with linux-glibc-devel on SLES"
    rpm -Uvh --replacepkgs --nosignature "$HEADERS_RPM"
  else
    echo "==> Skipping kernel-headers (conflicts with linux-glibc-devel on SLES)."
    echo "    Pass --with-headers only if you need those userspace headers."
  fi
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
  local grub_cfg=/boot/grub2/grub.cfg
  echo "==> Updating GRUB (${grub_cfg})"
  grub2-mkconfig -o "$grub_cfg"
  if command -v update-bootloader >/dev/null; then
    echo "==> Refreshing bootloader (update-bootloader --refresh)"
    update-bootloader --refresh
  fi
  if grep -qF "$KVER" "$grub_cfg" 2>/dev/null; then
    echo "==> GRUB lists ${KVER}"
  else
    echo "warning: ${KVER} not found in ${grub_cfg}; check /boot/vmlinuz-${KVER}" >&2
  fi
}

verify_boot_files() {
  local moddir="/lib/modules/${KVER}"

  if [ ! -f "/boot/vmlinuz-${KVER}" ]; then
    echo "error: /boot/vmlinuz-${KVER} not found after install" >&2
    exit 1
  fi
  if [ ! -d "$moddir/kernel" ]; then
    echo "error: ${moddir}/kernel not found after install" >&2
    exit 1
  fi
  if [ ! -d "$moddir/kernel/drivers/net" ]; then
    echo "error: ${moddir}/kernel/drivers/net missing; kernel RPM install looks incomplete" >&2
    echo "       re-run after fixing RPM install (do not install conflicting kernel-headers)" >&2
    exit 1
  fi

  echo ""
  echo "Boot images in /boot:"
  ls -1 /boot/vmlinuz-* 2>/dev/null || true
  echo ""
  echo "Module tree: ${moddir}/kernel/drivers/ (sample):"
  ls "$moddir/kernel/drivers" | head -20
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
