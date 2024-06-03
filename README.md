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
As of 2023-06-02, the latest kernel is 6.5.0-35.

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
# el9-kernel.sh

el9-kernel.sh installs kernel 6.1 (long term) or kernel 6.9 (main line) in elrepo9 RPM systems such as
AlmaLinux9, RockyLinux9, etc.

--

Ignore the other scripts in this repository as they are non-functional.
