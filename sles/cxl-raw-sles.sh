#!/bin/bash -vx
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

AUTO_YES=false
while [ $# -gt 0 ]; do
  case $1 in
    -y|--yes)
      AUTO_YES=true
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") [-y]"
      echo "  -y, --yes  auto-confirm install and RPM build prompts"
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      echo "Try '$(basename "$0") --help'." >&2
      exit 1
      ;;
  esac
  shift
done

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

prompt_yn() {
  local msg="$1"
  if [ "$AUTO_YES" = true ]; then
    YN=y
    echo "${msg}y (auto)"
    return
  fi
  while true; do
    read -n 1 -p "$msg" YN
    case $YN in
      [yn] ) break;;
      * ) echo "Press y or n: ";;
    esac
  done
}

SCRIPT_START=$(date +%s)

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
if [ -f "${SCRIPT_DIR}/sles-registration-key" ]; then
  source "${SCRIPT_DIR}/sles-registration-key"
  sudo SUSEConnect -r "$SLES_REGISTRATION_KEY"
else
  echo "sles-registration-key not found; skipping SUSEConnect -r (using existing registration)"
fi

#sudo SUSEConnect -p sle-module-desktop-applications/15.7/x86_64
#sudo SUSEConnect -p sle-module-development-tools/15.7/x86_64
source /etc/os-release
# sudo SUSEConnect -p sle-module-desktop-applications/$VERSION_ID/x86_64
# sudo SUSEConnect -p sle-module-development-tools/$VERSION_ID/x86_64

run_timed "Install build dependencies (zypper)" bash -c '
  sudo zypper -n install kernel-default-devel gcc make ncurses-devel bc libopenssl-devel dwarves flex bison openssl patch
  sudo zypper -n install -f kernel-devel kernel-default-devel
  sudo zypper -n source-install kernel-source
'

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
KERNEL_LOCALVERSION_TAG="cxlraw"
KERNEL_RELEASE="${KVERS}-default"

KERNEL_SRC=/usr/src/linux
BUILDDIR="${SCRIPT_DIR}/kernel-build-${KVERS}"
SUSE_SOURCEDIR=/usr/src/packages/SOURCES

# source-install drops the SRPM into /usr/src/packages; SLES has no installable
# kernel-source binary RPM. Unpack vanilla sources and apply SUSE patches locally.
prepare_suse_kernel_source() {
  local target="/usr/src/linux-${KVERS}"
  local prepdir="${SCRIPT_DIR}/.suse-kernel-prep"
  local patchdir="${prepdir}/patchroot"
  local srcversion
  local linux_tar

  srcversion=$(basename "$(ls -1 "${SUSE_SOURCEDIR}"/linux-*.tar.xz | head -1)" .tar.xz)
  srcversion=${srcversion#linux-}
  linux_tar="${SUSE_SOURCEDIR}/linux-${srcversion}.tar.xz"

  rm -rf "${prepdir}"
  mkdir -p "${patchdir}" "${prepdir}/extract"

  for ball in config.tar.bz2 config.addon.tar.bz2 patches.arch.tar.bz2 patches.drivers.tar.bz2 \
              patches.fixes.tar.bz2 patches.rpmify.tar.bz2 patches.suse.tar.bz2 patches.addon.tar.bz2 \
              patches.kernel.org.tar.bz2 patches.apparmor.tar.bz2 patches.rt.tar.bz2 \
              patches.kabi.tar.bz2 patches.drm.tar.bz2 kabi.tar.bz2 sysctl.tar.bz2; do
    tar -xjf "${SUSE_SOURCEDIR}/${ball}" -C "${patchdir}"
  done

  tar -xf "${linux_tar}" -C "${prepdir}/extract"
  mv "${prepdir}/extract/linux-${srcversion}" "${prepdir}/linux-${KVERS}"

  pushd "${prepdir}/linux-${KVERS}"
    "${SUSE_SOURCEDIR}/apply-patches" "${SUSE_SOURCEDIR}/series.conf" "${patchdir}"
  popd

  sudo rm -rf "${target}"
  sudo mv "${prepdir}/linux-${KVERS}" "${target}"
  sudo ln -sfn "linux-${KVERS}" /usr/src/linux
  rm -rf "${prepdir}"
}

apply_custom_kernel_localversion() {
  local cfg="$1"
  local current new_lv

  current=$(grep '^CONFIG_LOCALVERSION=' "$cfg" | sed -n 's/^CONFIG_LOCALVERSION="\(.*\)"$/\1/p')
  if [[ "$current" == *-default ]]; then
    new_lv="${current%-default}-${KERNEL_LOCALVERSION_TAG}-default"
  else
    new_lv="${current}-${KERNEL_LOCALVERSION_TAG}"
  fi
  "${KERNEL_SRC}/scripts/config" --file "$cfg" --set-str LOCALVERSION "$new_lv"
  echo "Kernel LOCALVERSION set to ${new_lv}"
}

resolve_kernel_release() {
  KERNEL_RELEASE=$(make -C "$KERNEL_SRC" O="$BUILDDIR" -s kernelrelease)
}

# Custom kernels lack SUSE "supported" module signatures; without this, boot
# fails (e.g. vfat/btrfs modules blocked → emergency mode). See:
# https://support.scc.suse.com/s/kb/Enable-loading-of-unsupported-kernel-modules
allow_unsupported_modules() {
  local src=/lib/modprobe.d/10-unsupported-modules.conf
  local dst=/etc/modprobe.d/10-unsupported-modules.conf

  if [ ! -f "$src" ]; then
    echo "error: ${src} not found"
    exit 1
  fi

  if [ ! -f "$dst" ]; then
    echo "Installing ${dst} from ${src}..."
    sudo cp "$src" "$dst"
  fi

  if grep -qE '^[[:space:]]*allow_unsupported_modules[[:space:]]+0' "$dst"; then
    echo "Enabling allow_unsupported_modules in ${dst}..."
    sudo sed -i 's/^\([[:space:]]*allow_unsupported_modules[[:space:]]*\)0/\11/' "$dst"
  elif grep -qE '^[[:space:]]*allow_unsupported_modules[[:space:]]+1' "$dst"; then
    echo "allow_unsupported_modules already enabled in ${dst}"
  else
    echo "allow_unsupported_modules 1" | sudo tee -a "$dst" >/dev/null
  fi
}

rebuild_initrd_for_built_kernel() {
  resolve_kernel_release
  local kver="$KERNEL_RELEASE"
  local initrd="/boot/initrd-${kver}"

  if ! command -v dracut >/dev/null; then
    sudo zypper -n install dracut
  fi

  echo "Rebuilding initrd ${initrd} (dracut; initrd may load unsupported modules)..."
  sudo dracut -f "$initrd" "$kver"
}

verify_dual_kernel_boot_setup() {
  resolve_kernel_release
  local stock_kver="${KVERS}-default"
  local custom_kver="$KERNEL_RELEASE"

  echo ""
  echo "Boot images in /boot:"
  ls -1 /boot/vmlinuz-* 2>/dev/null || true

  if [ ! -f "/boot/vmlinuz-${custom_kver}" ]; then
    echo "error: custom kernel /boot/vmlinuz-${custom_kver} not found after install"
    exit 1
  fi

  if [ "${custom_kver}" = "${stock_kver}" ]; then
    echo "error: custom kernel version matches stock (${stock_kver}); LOCALVERSION tag missing"
    exit 1
  fi

  if [ -f "/boot/vmlinuz-${stock_kver}" ]; then
    echo "Stock SLES kernel preserved: /boot/vmlinuz-${stock_kver}"
  else
    echo "warning: stock kernel /boot/vmlinuz-${stock_kver} not found"
    echo "         (install kernel-default from SUSE if you need a fallback entry)"
  fi

  if [ -d /boot/loader/entries ]; then
    echo ""
    echo "BLS loader entries:"
    ls -1 /boot/loader/entries/*.conf 2>/dev/null || true
  fi

  echo ""
  echo "GRUB should list both kernels. Boot ${custom_kver} for CXL raw commands;"
  echo "boot ${stock_kver} to fall back to the original SUSE kernel."
  echo "The script does not remove the kernel-default RPM or stock /boot files."
}

install_versioned_vmlinuz() {
  resolve_kernel_release
  local vmlinuz="/boot/vmlinuz-${KERNEL_RELEASE}"

  echo "Installing versioned vmlinuz ${vmlinuz}..."
  sudo cp "${BUILDDIR}/arch/x86/boot/bzImage" "$vmlinuz"
  sudo chmod 644 "$vmlinuz"
}

install_built_kernel() {
  if findmnt -no OPTIONS / | grep -q '\bro\b'; then
    echo "error: root filesystem is read-only; fix storage I/O then: sudo mount -o remount,rw /"
    exit 1
  fi

  sudo make -C "$KERNEL_SRC" O="$BUILDDIR" modules_install
  sudo make -C "$KERNEL_SRC" O="$BUILDDIR" install
  install_versioned_vmlinuz
  allow_unsupported_modules
  rebuild_initrd_for_built_kernel
  sudo grub2-mkconfig -o /boot/grub2/grub.cfg
  verify_dual_kernel_boot_setup
}

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
  resolve_kernel_release
  RPM_OUT="${SCRIPT_DIR}/kernel-rpms-${KERNEL_RELEASE}"
  echo ""
  echo "Warning: kernel RPM packaging (make binrpm-pkg) typically takes 30-45+ minutes."
  echo "         rpmbuild may spew ksym/kmod lines then go quiet for long stretches."
  echo "         Status updates print every 5 minutes while this step runs."
  ensure_rpm_build
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
  echo "Kernel RPMs written to ${RPM_OUT}:"
  ls -lh "$RPM_OUT"/*.rpm
}

if [ ! -f "${KERNEL_SRC}/arch/x86/entry/syscalls/syscall_32.tbl" ]; then
  run_timed "Prepare patched kernel source at /usr/src/linux-${KVERS}" prepare_suse_kernel_source
fi

if [ ! -f "${KERNEL_SRC}/arch/x86/entry/syscalls/syscall_32.tbl" ]; then
  echo "error: failed to install full kernel source in ${KERNEL_SRC}"
  exit 1
fi

sudo mkdir -p "${KERNEL_SRC}/certs"
sudo chown -R $USER:users "${KERNEL_SRC}/certs"

if [ -f "${BUILDDIR}/arch/x86/boot/bzImage" ] && \
   grep -q "^CONFIG_LOCALVERSION=.*${KERNEL_LOCALVERSION_TAG}" "${BUILDDIR}/.config" 2>/dev/null; then
  resolve_kernel_release
  echo "Using existing kernel build in ${BUILDDIR} (${KERNEL_RELEASE})"
else
  if [ -f "${BUILDDIR}/arch/x86/boot/bzImage" ]; then
    echo "Existing build lacks ${KERNEL_LOCALVERSION_TAG} LOCALVERSION; reconfiguring and rebuilding..."
  fi
  mkdir -p "$BUILDDIR"
  sudo chown -R $USER:users "$BUILDDIR"

  cp /boot/config-${UNAME_R} "$BUILDDIR/.config" # 'make olddefconfig' changes kernel version comment?

  #scripts/config --disable CONFIG_MODULE_SIG
  "${KERNEL_SRC}/scripts/config" --file "$BUILDDIR/.config" --disable SYSTEM_TRUSTED_KEYS
  "${KERNEL_SRC}/scripts/config" --file "$BUILDDIR/.config" --disable SYSTEM_REVOCATION_KEYS

  # Enable CONFIG_CXL_MEM_RAW_COMMANDS=y
  # Device Drivers > PCI support > CXL (Compute Express Link) Devices Support >
  #   [*] RAW Command Interface for Memory Devices (default=[_])
  # Enable CONFIG_CXL_REGION_INVALIDATION_TEST=y
  "${KERNEL_SRC}/scripts/config" --file "$BUILDDIR/.config" --enable CONFIG_CXL_MEM_RAW_COMMANDS
  "${KERNEL_SRC}/scripts/config" --file "$BUILDDIR/.config" --enable CONFIG_CXL_REGION_INVALIDATION_TEST

  apply_custom_kernel_localversion "$BUILDDIR/.config"

  #make oldconfig
  # yes "" | make oldconfig # https://serverfault.com/a/116317/221343
  make -C "$KERNEL_SRC" O="$BUILDDIR" olddefconfig # https://serverfault.com/a/538150/221343
  # make -C "$KERNEL_SRC" O="$BUILDDIR" menuconfig
  # make -C "$KERNEL_SRC" O="$BUILDDIR" xconfig

  resolve_kernel_release
  echo "Building kernel ${KERNEL_RELEASE}..."

  diff /boot/config-${UNAME_R} "$BUILDDIR/.config" || true
  grep CONFIG_CXL_MEM_RAW_COMMANDS "$BUILDDIR/.config"
  grep CONFIG_CXL_REGION_INVALIDATION_TEST "$BUILDDIR/.config"
  grep CONFIG_LOCALVERSION "$BUILDDIR/.config"

  pushd "${KERNEL_SRC}/certs"
    if [[ ! -f MOK.key.pem || ! -f MOK.crt.pem ]]; then
      openssl req -new -x509 -newkey rsa:2048 \
        -keyout MOK.key.pem -out MOK.crt.pem -nodes -days 36500 \
        -subj "/CN=cxl-raw-sles.sh Custom Kernel Signing"
    fi

    bash -vx "${SCRIPT_DIR}/utilities/prepare-mok-signing-sles.sh"

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

  popd

  # make -C "$KERNEL_SRC" O="$BUILDDIR" clean
  run_timed "Kernel build prepare" make -C "$KERNEL_SRC" O="$BUILDDIR" prepare
  run_timed "Kernel modules_prepare" make -C "$KERNEL_SRC" O="$BUILDDIR" modules_prepare
  run_timed "Kernel compile (make -j$(nproc))" make -C "$KERNEL_SRC" O="$BUILDDIR" -j"$(nproc)"
fi

prompt_yn "Press y to install the newly built kernel, or n to skip: "

echo "\$YN=\"$YN\""
if [ "$YN" == "y" ]; then
  run_timed "Install built kernel (modules + vmlinuz + initrd + grub)" install_built_kernel
else
  echo "Skipped kernel install"
fi

echo ""
echo "Note: building kernel RPMs can take 30-45+ minutes; status updates print every 5 minutes."
prompt_yn "Press y to build kernel RPMs for other systems, or n to skip: "

echo "\$YN=\"$YN\""
if [ "$YN" == "y" ]; then
  build_kernel_rpms
  echo "Install on target: sudo rpm -Uvh --replacepkgs ${SCRIPT_DIR}/kernel-rpms-${KERNEL_RELEASE}/*.rpm"
else
  echo "Skipped: kernel RPM build"
fi

# sudo reboot

echo ""
echo "==> Script total elapsed time: $(format_elapsed "$(( $(date +%s) - SCRIPT_START ))")"

exit 0
