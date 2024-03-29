# ubuntu-kernel

http://gitlab-ub.memapd.internal/sgh/ubuntu-kernel

This bash script gets the source code for the currently running kernel,
enables CONFIG_CXL_MEM_RAW_COMMANDS=y, and creates bash scripts in
`/usr/lib/modules/$UNAME_R/kernel/drivers/`:

- cxl-raw.sh - enable CXL RAW modules
- cxl-original.sh - restore the original ubuntu kernel CXL modules
- cxl-lsmod.sh - list the loaded cxl modules
- cxl-insmod.sh - install the cxl modules
- cxl-rmmod.sh - remove the cxl modules

Ubuntu 22.04.4 LTS base installs kernel 6.5.0-18.
As of 2023-03-29, the latest kernel is 6.5.0-26.

Copy this script somewhere under your home directory such as ~/Documents/.
Your user account must be able to sudo.

```
$ cd ~/Documents/
$ chmod +x ubuntu-kernel-cxl_raw.sh
$ ./ubuntu-kernel-cxl_raw.sh

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
[sudo] password for user1:
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
