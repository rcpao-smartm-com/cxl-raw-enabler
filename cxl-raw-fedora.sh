#!/bin/bash -x

# Fedora 41+ is equivalent to ELRepo for RHEL-10

# Note: The previous cxl-raw-fedora.sh stopped working with kernel 6.17.0.
#       I now recommend installing elrepo's precompiled kernels.
#       There is no need to compile anything, just install and reboot.
#
#       Ref: https://elrepo.org/bugs/view.php?id=1498#bugnotes
#       elrepo.org is precompiled with CONFIG_CXL_MEM_RAW_COMMANDS=y


# https://elrepo.org/wiki/doku.php?id=start

sudo rpm --import https://www.elrepo.org/RPM-GPG-KEY-v2-elrepo.org
sudo dnf install -y https://www.elrepo.org/elrepo-release-10.el10.elrepo.noarch.rpm

# Pick one of -lt or -ml below:
# sudo dnf --enablerepo=elrepo-kernel install -y kernel-lt # "long term support"
sudo dnf --enablerepo=elrepo-kernel install -y kernel-ml # "mainline stable"


: <<'COMMENT'

# Works in Fedora 43:
# https://github.com/sigmaSd/Stimulator
# https://nginx-flathub.apps.openshift.gnome.org/lt/apps/io.github.sigmasd.stimulator

# Fails in Fedora 43:
# Prevent Fedora 38-41 "The system will suspend now!" by GNOME when only using ssh sessions
# https://discussion.fedoraproject.org/t/system-suspends/81666/3
sudo -u gdm dbus-run-session gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type  nothing
sudo -u gdm dbus-run-session gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type  nothing
COMMENT


echo "You may now reboot to run your newly installed kernel."
