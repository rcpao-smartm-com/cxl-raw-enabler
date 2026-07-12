#!/bin/bash
# Build installable kernel RPMs from an existing out-of-tree kernel build.
# Uses "make binrpm-pkg" (prebuilt tree; does not require a git checkout).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNAME_R="${UNAME_R:-$(uname -r)}"
KVERS="${KVERS:-${UNAME_R%-*}}"
KERNEL_SRC="${KERNEL_SRC:-/usr/src/linux}"
BUILDDIR="${BUILDDIR:-${SCRIPT_DIR}/kernel-build-${KVERS}}"
RPM_OUT="${RPM_OUT:-${SCRIPT_DIR}/kernel-rpms-${KVERS}}"

source /etc/os-release

ensure_rpm_build() {
  if command -v rpmbuild >/dev/null; then
    return 0
  fi
  echo "rpm-build not found; enabling Development Tools module..."
  sudo SUSEConnect -p "sle-module-desktop-applications/${VERSION_ID}/x86_64" || true
  sudo SUSEConnect -p "sle-module-development-tools/${VERSION_ID}/x86_64" || true
  sudo zypper -n ref
  sudo zypper -n install rpm-build
}

build_kernel_rpms() {
  if [ ! -f "${BUILDDIR}/arch/x86/boot/bzImage" ]; then
    echo "error: no built kernel in ${BUILDDIR}; run cxl-raw-sles.sh first"
    exit 1
  fi

  ensure_rpm_build

  echo "Building kernel RPMs from ${BUILDDIR}..."
  make -C "$KERNEL_SRC" O="$BUILDDIR" binrpm-pkg

  mkdir -p "$RPM_OUT"
  shopt -s nullglob
  for rpm in "${HOME}/rpmbuild/RPMS/"*/*.rpm; do
    case "$(basename "$rpm")" in
      kernel-*|kernel-devel-*|kernel-headers-*)
        cp -a "$rpm" "$RPM_OUT/"
        ;;
    esac
  done

  if [ -z "$(ls -A "$RPM_OUT"/*.rpm 2>/dev/null)" ]; then
    echo "error: no kernel RPMs found under ${HOME}/rpmbuild/RPMS/"
    exit 1
  fi

  echo "Kernel RPMs written to ${RPM_OUT}:"
  ls -lh "$RPM_OUT"/*.rpm
  cat <<EOF

Install on another SLES 15 SP6 x86_64 system (same architecture):

  scp ${RPM_OUT}/*.rpm target:/tmp/
  ssh target 'sudo rpm -Uvh --replacepkgs /tmp/kernel-*.rpm /tmp/kernel-devel-*.rpm /tmp/kernel-headers-*.rpm'
  ssh target 'sudo grub2-mkconfig -o /boot/grub2/grub.cfg && sudo reboot'

EOF
}

build_kernel_rpms
