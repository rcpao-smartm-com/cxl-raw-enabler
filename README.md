# cxl-raw-enabler

https://github.com/rcpao-smartm-com/cxl-raw-enabler

## cxl-raw-ubuntu.sh

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
[This statement may not be strictly true any longer.]

Note: To (re-)install 6.5.0-28: sudo apt install linux-image-6.5.0-28-generic


### Make Ubuntu GRUB2 remember the last choice

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
# GRUB_CMDLINE_LINUX="efi=nosoftreserve" # 8-DIMM requires this?
# GRUB_CMDLINE_LINUX="efi=nosoftreserve"

$ sudo update-grub
```

Source: https://askubuntu.com/a/149572


### Disable automatic upgrades in Ubuntu

To disable automatic software and kernel upgrades:

`sudo apt-get remove unattended-upgrades`

To enable them again:

`sudo apt-get install unattended-upgrades`

Source: https://askubuntu.com/a/1322357


## cxl-raw-fedora.sh

cxl-raw-fedora.sh gets the latest kernel source code:
```
/etc/os-release/$NAME="Fedora Linux"
/etc/os-release/$VERSION_ID=40

$ fedpkg clone -a kernel # -a = anonymous
$ pushd kernel/
$ git checkout --track remotes/origin/f$VERSION_ID
```

Unfortunately, it is not possible to checkout the source code of the
currently running kernel version. [If you figure out how, please let me
know, and I will modify this script!]

This script enables the following:
CONFIG_CXL_MEM_RAW_COMMANDS=y
CONFIG_CXL_REGION_INVALIDATION_TEST=y

This script will build and install the new kernel RPMs.

On reboot, select the new kernel in GRUB, "6.11.5-200.local.fc40.x86_64"
for example.


## el9-kernel.sh

el9-kernel.sh installs kernel 6.1 (long term) or kernel 6.9 (main line)
in elrepo9 RPM systems such as RedHat9, AlmaLinux9, RockyLinux9, etc.
elrepo9 build with CONFIG_CXL_MEM_RAW_COMMANDS=n.

This script does not get the source code of the el9 kernel to be able to
enable CONFIG_CXL_MEM_RAW_COMMANDS.


## World readable /dev/cxl/mem0

```
sudo -s
echo 'KERNEL=="mem*", MODE="0777"' > /etc/udev/rules.d/10-local.rules
udevadm control --reload-rules
udevadm trigger /dev/cxl/mem0
```


## Ignore 
Ignore the other (non-functional) scripts in this repository.
