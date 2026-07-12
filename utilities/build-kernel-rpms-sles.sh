#!/bin/bash
# Build installable kernel RPMs from an existing out-of-tree kernel build.
# Uses "make binrpm-pkg" (prebuilt tree; does not require a git checkout).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNAME_R="${UNAME_R:-$(uname -r)}"
KVERS="${KVERS:-${UNAME_R%-*}}"
KERNEL_SRC="${KERNEL_SRC:-/usr/src/linux}"
BUILDDIR="${BUILDDIR:-${SCRIPT_DIR}/kernel-build-${KVERS}}"
KERNEL_RELEASE="${KERNEL_RELEASE:-$(make -C "$KERNEL_SRC" O="$BUILDDIR" -s kernelrelease 2>/dev/null || echo "${KVERS}-default")}"
RPM_OUT="${RPM_OUT:-${SCRIPT_DIR}/kernel-rpms-${KERNEL_RELEASE}}"

format_elapsed() {
  local secs=$1
  if [ "$secs" -ge 3600 ]; then
    printf '%dh %dm %ds' $((secs / 3600)) $((secs % 3600 / 60)) $((secs % 60))
  elif [ "$secs" -ge 60 ]; then
    printf '%dm %ds' $((secs / 60)) $((secs % 60))
  else
    printf '%ds' "$secs"
  fi
}

run_timed() {
  local label="$1"
  shift
  local start end secs
  start=$(date +%s)
  echo "==> ${label} (started $(date +%H:%M:%S))"
  "$@"
  end=$(date +%s)
  secs=$((end - start))
  echo "==> ${label}: finished in $(format_elapsed "$secs")"
}

run_timed_with_heartbeat() {
  local label="$1"
  local interval="${2:-300}"
  shift 2
  local start end secs pid status heartbeat
  start=$(date +%s)
  echo "==> ${label} (started $(date +%H:%M:%S))"
  (
    while true; do
      sleep "$interval" || exit 0
      echo "==> ${label}: still running... ($(date +%H:%M:%S), elapsed $(format_elapsed "$(( $(date +%s) - start ))"))"
    done
  ) &
  heartbeat=$!
  "$@" &
  pid=$!
  if wait "$pid"; then
    status=0
  else
    status=$?
  fi
  kill "$heartbeat" 2>/dev/null
  wait "$heartbeat" 2>/dev/null || true
  end=$(date +%s)
  secs=$((end - start))
  if [ "$status" -ne 0 ]; then
    echo "==> ${label}: failed after $(format_elapsed "$secs")"
    return "$status"
  fi
  echo "==> ${label}: finished in $(format_elapsed "$secs")"
}

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

  echo ""
  echo "Warning: kernel RPM packaging (make binrpm-pkg) typically takes 30-45+ minutes."
  echo "         rpmbuild may spew ksym/kmod lines then go quiet for long stretches."
  echo "         Status updates print every 5 minutes while this step runs."
  run_timed_with_heartbeat "Build kernel RPMs (make binrpm-pkg)" 300 \
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
