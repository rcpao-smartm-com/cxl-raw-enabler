# cxl-raw-enabler

http://gitlab-ub.memapd.internal/sgh/cxl-raw-enabler

The bash script, cxl-raw-ubuntu.sh, gets the source code for 
the currently running kernel, enables CONFIG_CXL_MEM_RAW_COMMANDS=y, 
and creates bash scripts in 
`/usr/lib/modules/$(uname -r)/kernel/drivers/`:

- cxl-raw.sh - enable CXL RAW modules
- cxl-original.sh - restore the original ubuntu kernel CXL modules
- cxl-lsmod.sh - list the loaded cxl modules
- cxl-insmod.sh - install the cxl modules
- cxl-rmmod.sh - remove the cxl modules

Ubuntu 22.04.4 LTS desktop installer installs kernel 6.5.0-18.
2024-08-07: 22.04.4 kernel = 6.5.0-45, 24.04 kernel = 6.8.0-39
2024-08-28: 22.04.4 and 24.04 kernel = 6.8.0-40

cxl-raw-ubuntu.sh builds correctly in Ubuntu 22.04.4 
with kernel 6.5.0 (apt source and git)and 6.8.0 (git only), 
in Ubuntu 24.04 with kernel 6.8.0 (apt source and git).

Copy cxl-raw-ubuntu.sh somewhere under your home directory 
such as ~/Documents/.
Your user account must be able to sudo.

```
$ cd ~/Documents/
$ chmod +x cxl-raw-ubuntu.sh
$ ./cxl-raw-ubuntu.sh
[sudo] password for user1:
...
$ cd /usr/lib/modules/$(uname -r)/kernel/drivers/
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

Note: To (re-)install 6.5.0-28: sudo apt install linux-image-6.5.0-28-generic


## Make Ubuntu GRUB2 remember the last choice

```
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
```

Source: https://askubuntu.com/a/149572


## Disable automatic upgrades in Ubuntu

To disable automatic software and kernel upgrades:

`sudo apt-get remove unattended-upgrades`

To enable them again:

`sudo apt-get install unattended-upgrades`

Source: https://askubuntu.com/a/1322357


# el9-kernel.sh

el9-kernel.sh installs kernel 6.1 (long term) or kernel 6.9 (main line)
in elrepo9 RPM systems such as RedHat9, AlmaLinux9, RockyLinux9, etc.
elrepo9 build with CONFIG_CXL_MEM_RAW_COMMANDS=n.

---
# Ignore 
Ignore the other (non-functional) scripts in this repository.
