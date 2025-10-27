#!/bin/bash -x


# $ rpm -qa kernel-core # list installed kernels
# kernel-core-6.14.9-200.cxlraw.fc41.x86_64
# kernel-core-6.15.3-100.cxlraw.fc41.x86_64
# kernel-core-6.16.9-100.cxlraw.fc41.x86_64
# kernel-core-6.17.5-100.cxlraw.fc41.x86_64
# $ sudo dnf remove kernel-core-6.16.9-100.fc41.x86_64 # remove an old kernel


# DBG : <<'COMMENT'


# WARNING: git repo does not tag kernel versions and the branches do not match any specific kernel versions.
#          The sources to build the specific kernel version you want may be difficult to find / acquire.

# $UNAME_R is the currently running kernel or the kernel you wish to build
# UNAME_R=6.8.7-100.fc38.x86_64
# UNAME_R=6.8.7-200.fc39.x86_64
# UNAME_R=6.8.7-300.fc40.x86_64
BUILDID=".cxlraw"
UNAME_R=$(uname -r) # 6.11.5-200${BUILDID}.fc40.x86_64
UNAME_R=${UNAME_R//"$BUILDID"/} # 6.11.5-200.fc40.x86_64
UNAME_R_NO_DASH=${UNAME_R%-*} # 6.11.5
UNAME_R_NO_ARCH=${UNAME_R%.x86_64} # 6.11.5-200.fc40
UNAME_R_NO_FC_ARCH=${UNAME_R%.fc*} # 6.11.3-200
UNAME_R_FC_ARCH=${UNAME_R#*.*.*-*.} # fc40.x86_64


source /etc/os-release
# NAME="Fedora Linux"
# VERSION="40 (Workstation Edition)"
# ID=fedora
# VERSION_ID=40
# VERSION_CODENAME=""
# PLATFORM_ID="platform:f40"
# PRETTY_NAME="Fedora Linux 40 (Workstation Edition)"
# ANSI_COLOR="0;38;2;60;110;180"
# LOGO=fedora-logo-icon
# CPE_NAME="cpe:/o:fedoraproject:fedora:40"
# DEFAULT_HOSTNAME="fedora"
# HOME_URL="https://fedoraproject.org/"
# DOCUMENTATION_URL="https://docs.fedoraproject.org/en-US/fedora/f40/system-administrators-guide/"
# SUPPORT_URL="https://ask.fedoraproject.org/"
# BUG_REPORT_URL="https://bugzilla.redhat.com/"
# REDHAT_BUGZILLA_PRODUCT="Fedora"
# REDHAT_BUGZILLA_PRODUCT_VERSION=40
# REDHAT_SUPPORT_PRODUCT="Fedora"
# REDHAT_SUPPORT_PRODUCT_VERSION=40
# SUPPORT_END=2025-05-13
# VARIANT="Workstation Edition"
# VARIANT_ID=workstation


# https://www.faschingbauer.me/trainings/material/soup/kernel/fedora-kernel-build/screenplay.html#building-from-the-rpm-source
# https://fedoraproject.org/wiki/Building_a_custom_kernel#Building_a_Kernel_from_the_Fedora_source_tree


sudo dnf -y install fedpkg fedora-packager rpmdevtools ncurses-devel pesign grubby

[ -d kernel/ ] && rm -rf kernel/
git config --global core.compression 0
fedpkg clone -a kernel # -a = anonymous

[ ! -d kernel/ ] && echo "Error: kernel/ does not exist" && exit 1
pushd kernel/
  git checkout --track remotes/origin/f$VERSION_ID
  # WARNING: This git repo does not tag kernel versions and the branches do not match any specific kernel versions.
  #          The kernel source may not match your currently running kernel.
  #          Fedora is similar to Ubuntu in this respect.

  # Modify kernel version, append ${BUILDID}
  ls -l kernel.spec
  [ ! -f kernel.spec.original ] && cp kernel.spec kernel.spec.original
  # sed -e 's/^# define buildid .local/%define buildid .local/'     kernel.spec > kernel.spec.local
    sed -e "s/^# define buildid .local/%define buildid ${BUILDID}/" kernel.spec > kernel.spec${BUILDID}
  cp kernel.spec${BUILDID} kernel.spec
  grep "define buildid" kernel.spec

  sudo dnf -y builddep kernel.spec
  sudo dnf -y install rustfmt

  sudo dnf -y install capstone-devel libpfm-devel

  # Add $USER to /etc/pesign/users
  sudo grep $USER /etc/pesign/users 
  [ $? -ne 0 ] && sudo sh -c "echo $USER >> /etc/pesign/users" && sudo /usr/libexec/pesign/pesign-authorize


  pwd
  ls -FC
  echo "CONFIG_CXL_MEM_RAW_COMMANDS=y" > kernel-local
  echo "CONFIG_CXL_REGION_INVALIDATION_TEST=y" >> kernel-local
  cat kernel-local 


  # Build!
  time fedpkg local


  grep "define buildid" kernel.spec
  cat kernel-local 


  pwd # kernel
  ls -l ./kernel-*.src.rpm
  KERNEL_KVERSTR=$(basename $(ls -1 ./kernel-*.src.rpm) .src.rpm) # kernel-6.11.6-200.cxlraw.fc40 <- ./kernel-6.11.6-200.cxlraw.fc40.src.rpm
  KVERSTR=${KERNEL_KVERSTR//kernel-/}.$(uname -m) # 6.11.6-200.cxlraw.fc40.x86_64
  ls ./x86_64/
  ls -l \
     ./x86_64/kernel-modules-core-${KVERSTR}.rpm \
     ./x86_64/kernel-core-${KVERSTR}.rpm \
     ./x86_64/kernel-modules-${KVERSTR}.rpm \
     ./x86_64/kernel-${KVERSTR}.rpm
# DBG COMMENT
  CMD="sudo dnf -y install --nogpgcheck \
./x86_64/kernel-modules-core-${KVERSTR}.rpm \
./x86_64/kernel-core-${KVERSTR}.rpm \
./x86_64/kernel-modules-${KVERSTR}.rpm \
./x86_64/kernel-${KVERSTR}.rpm"

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
    $CMD
  else
    echo "Skipped: \"$CMD\""
  fi


  echo ""
  echo "To list installed kernels:"
  echo "dnf list installed kernel"
  echo ""
  echo "To uninstall after booting into a different kernel (untested):"
  echo "sudo dnf -y remove kernel-core-${KVERSTR}"


popd # kernel


exit 0
