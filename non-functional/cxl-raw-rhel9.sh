#!/bin/bash -x


# WARNING: git repo does not tag kernel versions and the branches do not match any specific kernel versions.
#          The sources to build the kernel version you want may be difficult to find / acquire.

# $UNAME_R is the currently running kernel or the kernel you wish to build
# UNAME_R=5.14.0-427.22.1.el9_4.x86_64
# UNAME_R=6.8.7-100.fc38.x86_64
# UNAME_R=6.8.7-200.fc39.x86_64
# UNAME_R=6.8.7-300.fc40.x86_64
BUILDID=".cxlraw"
UNAME_R=$(uname -r) # 6.11.5-200${BUILDID}.fc40.x86_64
UNAME_R=${UNAME_R//"$BUILDID"/} # 5.14.0-427.22.1.el9_4.x86_64
UNAME_R_NO_DASH=${UNAME_R%-*} # 5.14.0
UNAME_R_NO_ARCH=${UNAME_R%.x86_64} # 5.14.0-427.22.1.el9_4
UNAME_R_NO_EL_ARCH=${UNAME_R%.el*} # 5.14.0-427.22.1
UNAME_R_EL_ARCH=${UNAME_R#*.*.*-*.*.*.} # el9_4.x86_64


source /etc/os-release
# NAME="Red Hat Enterprise Linux"
# VERSION="9.4 (Plow)"
# ID="rhel"
# ID_LIKE="fedora"
# VERSION_ID="9.4"
# PLATFORM_ID="platform:el9"
# PRETTY_NAME="Red Hat Enterprise Linux 9.4 (Plow)"
# ANSI_COLOR="0;31"
# LOGO="fedora-logo-icon"
# CPE_NAME="cpe:/o:redhat:enterprise_linux:9::baseos"
# HOME_URL="https://www.redhat.com/"
# DOCUMENTATION_URL="https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9"
# BUG_REPORT_URL="https://bugzilla.redhat.com/"
# 
# REDHAT_BUGZILLA_PRODUCT="Red Hat Enterprise Linux 9"
# REDHAT_BUGZILLA_PRODUCT_VERSION=9.4
# REDHAT_SUPPORT_PRODUCT="Red Hat Enterprise Linux"
# REDHAT_SUPPORT_PRODUCT_VERSION="9.4"


# fc https://www.faschingbauer.me/trainings/material/soup/kernel/fedora-kernel-build/screenplay.html#building-from-the-rpm-source
# fc https://fedoraproject.org/wiki/Building_a_custom_kernel#Building_a_Kernel_from_the_Fedora_source_tree

# https://wiki.centos.org/HowTos(2f)Custom_Kernel.html


sudo yum groupinstall "Development Tools"
sudo yum install ncurses-devel
sudo yum install qt3-devel # (This is only necessary if you wish to use make xconfig instead of make gconfig or make menuconfig.)
sudo yum install hmaccalc zlib-devel binutils-devel elfutils-libelf-devel 
sudo yum install kernel-devel
exit

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
  sudo dnf -y install --nogpgcheck \
     ./x86_64/kernel-modules-core-${KVERSTR}.rpm \
     ./x86_64/kernel-core-${KVERSTR}.rpm \
     ./x86_64/kernel-modules-${KVERSTR}.rpm \
     ./x86_64/kernel-${KVERSTR}.rpm

  echo "To uninstall after booting into a different kernel (untested):"
  echo "sudo dnf -y remove kernel-core-${KVERSTR}"


popd # kernel


exit 0
