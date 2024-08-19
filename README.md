# cxl-raw-enabler

http://gitlab-ub.memapd.internal/sgh/cxl-raw-enabler

The bash script, cxl-raw-ubuntu.sh, gets the source code for 
the currently running kernel, enables CONFIG_CXL_MEM_RAW_COMMANDS=y, 
and creates bash scripts in 
`/usr/lib/modules/$UNAME_R/kernel/drivers/`:

- cxl-raw.sh - enable CXL RAW modules
- cxl-original.sh - restore the original ubuntu kernel CXL modules
- cxl-lsmod.sh - list the loaded cxl modules
- cxl-insmod.sh - install the cxl modules
- cxl-rmmod.sh - remove the cxl modules

Ubuntu 22.04.4 LTS desktop installer installs kernel 6.5.0-18.
As of 2024-08-07, the latest 22.04.4 kernel is 6.5.0-45, 
and the latest 24.04 kernel is 6.8.0-39.

cxl-raw-ubuntu.sh builds correctly with Ubuntu 22.04.4 and 23.10.1 
with kernel 6.5.0 and Ubuntu 24.04 with kernel 6.8.0.

Copy cxl-raw-ubuntu.sh somewhere under your home directory 
such as ~/Documents/.
Your user account must be able to sudo.

```
$ cd ~/Documents/
$ chmod +x cxl-raw-ubuntu.sh
$ ./cxl-raw-ubuntu.sh
[sudo] password for user1:
...
$ cd /usr/lib/modules/$UNAME_R/kernel/drivers/
$ ls -F cxl*
cxl@            cxl-lsmod.sh*     cxl-raw-6.5.0-26-generic@  cxl-rmmod.sh*
cxl-insmod.sh*  cxl-original.sh*  cxl-raw.sh*
cxl:
core/  cxl_acpi.ko  cxl_mem.ko  cxl_pci.ko  cxl_pmem.ko  cxl_port.ko
cxl-raw-6.5.0-21-generic:
core/  cxl_acpi.ko  cxl_mem.ko  cxl_pci.ko  cxl_pmem.ko  cxl_port.ko

$ ./cxl-raw.sh
$ ls -Fl cxl
lrwxrwxrwx 1 root root 73 Mar 29 15:52 cxl -> /usr/lib/modules/6.5.0-21-generic/kernel/drivers/cxl-raw-6.5.0-21-generic/

$ ./cxl-lsmod.sh
$ ./cxl-insmod.sh
$ ./cxl-lsmod.sh
cxl_port               16384  0
cxl_pmem               24576  0
cxl_pci                28672  0
cxl_mem                12288  0
cxl_acpi               24576  0
cxl_core              270336  5 cxl_pmem,cxl_port,cxl_mem,cxl_pci,cxl_acpi
$ ./cxl-rmmod.sh
$ ./cxl-lsmod.sh

$ ./cxl-original.sh
$ ls -Fl cxl
lrwxrwxrwx 1 root root 61 Mar 29 16:55 cxl -> /usr/lib/modules/6.5.0-21-generic/kernel/drivers/cxl-original/

```
Note: The last Ubuntu 22.04.4 kernel version that works with CXL memory 
is 6.7.6.  Version 6.7.7 and Ubuntu 24.04 kernel version 6.8.0-39 do not.


## Make Ubuntu GRUB2 remember the last choice (from https://askubuntu.com/a/149572)

$ sudo nano /etc/default/grub
# GRUB_DEFAULT=0
GRUB_DEFAULT=saved
GRUB_SAVEDEFAULT=true
# GRUB_TIMEOUT_STYLE=hidden
# GRUB_TIMEOUT=0
GRUB_TIMEOUT=60
GRUB_DISTRIBUTOR=`lsb_release -i -s 2> /dev/null || echo Debian`
# GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_CMDLINE_LINUX_DEFAULT=""
# GRUB_CMDLINE_LINUX="mem=32G"
# GRUB_CMDLINE_LINUX="mem=32G memhp_default_state=offline"
# GRUB_CMDLINE_LINUX="memhp_default_state=offline"
# GRUB_CMDLINE_LINUX="iommu=pt"
# GRUB_CMDLINE_LINUX="efi=nosoftreserve" # AsteraLabs requires this
# GRUB_CMDLINE_LINUX="efi=nosoftreserve"

$ sudo update-grub


## Disable automatic upgrades in Ubuntu

To prevent the mysterious kernel upgrade from 6.5.0 to 6.8.0:

$ sudo apt-get remove unattended-upgrades

If you want to enable them again, replace "remove" with "install".


# el9-kernel.sh

el9-kernel.sh installs kernel 6.1 (long term) or kernel 6.9 (main line)
in elrepo9 RPM systems such as RedHat9, AlmaLinux9, RockyLinux9, etc.
elrepo9 build with CONFIG_CXL_MEM_RAW_COMMANDS=n.

---
# Ignore 
Ignore the other (non-functional) scripts in this repository.
