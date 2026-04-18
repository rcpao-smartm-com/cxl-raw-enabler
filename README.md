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
2024-12-16: 22.04.4 and 24.04 kernel = 6.8.0-47  

cxl-raw-ubuntu.sh builds correctly in Ubuntu 22.04.4:
kernel 6.5.0 (apt source and git)
kernel 6.8.0 (git only)
Ubuntu 24.04:
kernel 6.8.0 (apt source and git)
kernel 6.14.0

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

To (re-)install 6.5.0-28: sudo apt install linux-image-6.5.0-28-generic

To install HWE kernel (6.8.0-##-generic) for Ubuntu 24.04: sudo apt install linux-generic-hwe-24.04


### Make Ubuntu GRUB2 remember the last choice

```
$ sudo nano /etc/default/grub
# GRUB_DEFAULT=0
GRUB_DEFAULT=saved
GRUB_SAVEDEFAULT=true
# GRUB_TIMEOUT_STYLE=hidden
# GRUB_TIMEOUT=0
GRUB_TIMEOUT=30
GRUB_DISTRIBUTOR=`lsb_release -i -s 2> /dev/null || echo Debian`
# GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_CMDLINE_LINUX_DEFAULT=""
# GRUB_CMDLINE_LINUX="mem=32G"
# GRUB_CMDLINE_LINUX="mem=32G memhp_default_state=offline"
# GRUB_CMDLINE_LINUX="memhp_default_state=offline"
# GRUB_CMDLINE_LINUX="iommu=pt"
# GRUB_CMDLINE_LINUX="efi=nosoftreserve" # 8-DIMM requires this?

$ sudo update-grub
```

Source: https://askubuntu.com/a/149572


### World readable and writable /dev/cxl/mem0 in Ubuntu

```
sudo -s
echo 'KERNEL=="mem*", MODE="0777"' > /etc/udev/rules.d/10-local.rules
udevadm control --reload-rules
udevadm trigger /dev/cxl/mem0
```

### Disable automatic upgrades in Ubuntu

To disable automatic software and kernel upgrades:

`sudo apt-get remove unattended-upgrades`

To enable them again:

`sudo apt-get install unattended-upgrades`

Source: https://askubuntu.com/a/1322357


## ub24-6.17.0.sh

Ubuntu 24.04.4 mainline kernel 6.17.0 

Run to install mainline kernel 6.17.0.
Reboot.
Re-run to compile the cxl-raw kernel drivers.
Reboot.
Test cxl raw drivers: e.g. mchip_cxl_cci --sss_get


## cxl-raw-fedora.sh

Fedora 41-43: 
Installs elrepo kernel-ml.


Fedora 38-41:
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


### Show the GRUB menu in Fedora

/etc/default/grub:
```
GRUB_TIMEOUT=30
GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_DEFAULT=saved
GRUB_SAVEDEFAULT=true
# GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL_OUTPUT="console"
# GRUB_CMDLINE_LINUX="rhgb quiet"
# GRUB_CMDLINE_LINUX="memhp_default_state=offline"
GRUB_CMDLINE_LINUX=""
# GRUB_DISABLE_RECOVERY="true"
GRUB_ENABLE_BLSCFG=true

# https://unix.stackexchange.com/a/639039/325763
# sudo grub2-mkconfig -o /boot/grub2/grub.cfg
# https://discussion.fedoraproject.org/t/how-to-get-grub-menu-to-show/91947/2
# sudo grub2-editenv - unset menu_auto_hide

# https://forums.almalinux.org/t/changes-to-etc-default-grub-not-taking-effect/3389 
# sudo grubby --remove-args="rhgb quiet" --update-kernel=ALL 
```

### World readable and writable /dev/cxl/mem0 in Fedora

```
$ echo 'KERNEL=="mem*", MODE="0777"' | sudo tee /etc/udev/rules.d/10-local.rules
$ ls -al /etc/udev/rules.d/10-local.rules
-rw-r--r--. 1 root root 28 Nov 19 22:11 /etc/udev/rules.d/10-local.rules
$ cat /etc/udev/rules.d/10-local.rules
KERNEL=="mem*", MODE="0777"
$ sudo udevadm control --reload # reload the udev rules
$ sudo shutdown -r now # reboot for the change to take effect
```

### Disable automatic kernel removal in Fedora

https://bugzilla.redhat.com/show_bug.cgi?id=1767904#c1

/etc/dnf/dnf.conf:
```
# see `man dnf.conf` for defaults and possible options

[main]
installonly_limit=0
```
Default installonly_limit = 3 when not specified


### Fedora Server 41-43 Extend 15G / to End of Disk

[rcpao@fs42-067x mchip_cxl_cci-rcpao]$ lsblk
NAME                                  MAJ:MIN RM   SIZE RO TYPE  MOUNTPOINTS
zram0                                 251:0    0     8G  0 disk  [SWAP]
nvme0n1                               259:0    0 838.4G  0 disk
├─nvme0n1p1                           259:1    0   600M  0 part  /boot/efi
├─nvme0n1p2                           259:2    0     1G  0 part  /boot
└─nvme0n1p3                           259:3    0 836.8G  0 part
  └─luks-36b2d615-b1f5-4b56-8a75-ddc6126d8e74
    │                                 252:0    0 836.8G  0 crypt
    └─fedora_ub24d--05dx-root         252:1    0    15G  0 lvm   /
[rcpao@fs42-067x mchip_cxl_cci-rcpao]$ df -h
Filesystem                           Size  Used Avail Use% Mounted on
/dev/mapper/fedora_ub24d--05dx-root   15G  3.2G   12G  21% /
devtmpfs                             4.0M     0  4.0M   0% /dev
tmpfs                                 32G     0   32G   0% /dev/shm
efivarfs                             256K  117K  135K  47% /sys/firmware/efi/efivars
tmpfs                                 13G  1.8M   13G   1% /run
tmpfs                                1.0M     0  1.0M   0% /run/credentials/systemd-cryptsetup@luks\x2d36b2d615\x2db1f5\x2d4b56\x2d8a75\x2dddc6126d8e74.service
tmpfs                                1.0M     0  1.0M   0% /run/credentials/systemd-journald.service
tmpfs                                 32G     0   32G   0% /tmp
/dev/nvme0n1p2                       849M  262M  587M  31% /boot
/dev/nvme0n1p1                       599M  7.5M  592M   2% /boot/efi
tmpfs                                1.0M     0  1.0M   0% /run/credentials/systemd-resolved.service
tmpfs                                1.0M     0  1.0M   0% /run/credentials/getty@tty1.service
tmpfs                                6.3G  4.0K  6.3G   1% /run/user/1000
[rcpao@fs42-067x mchip_cxl_cci-rcpao]$ sudo vgs
[sudo] password for rcpao:
  VG                #PV #LV #SN Attr   VSize    VFree
  fedora_ub24d-05dx   1   1   0 wz--n- <836.76g <821.76g
[rcpao@fs42-067x mchip_cxl_cci-rcpao]$ sudo lvs
  LV   VG                Attr       LSize  Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  root fedora_ub24d-05dx -wi-ao---- 15.00g                                      
[rcpao@fs42-067x mchip_cxl_cci-rcpao]$
[rcpao@fs42-067x mchip_cxl_cci-rcpao]$ sudo lvextend -l +100%FREE /dev/mapper/fedora_ub24d--05dx-root
[sudo] password for rcpao:
  Size of logical volume fedora_ub24d-05dx/root changed from 15.00 GiB (3840 extents) to <836.76 GiB (214210 extents).
  Logical volume fedora_ub24d-05dx/root successfully resized.
[rcpao@fs42-067x mchip_cxl_cci-rcpao]$ df -T / # verify filesystem is xfs
Filesystem                          Type 1K-blocks    Used Available Use% Mounted on
/dev/mapper/fedora_ub24d--05dx-root xfs   15523440 3257340  12266100  21% /
[rcpao@fs42-067x mchip_cxl_cci-rcpao]$ sudo xfs_growfs /
meta-data=/dev/mapper/fedora_ub24d--05dx-root isize=512    agcount=4, agsize=983040 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=1, sparse=1, rmapbt=1
         =                       reflink=1    bigtime=1 inobtcount=1 nrext64=1
         =                       exchange=0
data     =                       bsize=4096   blocks=3932160, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0, ftype=1, parent=0
log      =internal log           bsize=4096   blocks=51300, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
data blocks changed from 3932160 to 219351040
[rcpao@fs42-067x mchip_cxl_cci-rcpao]$

Ref: https://copilot.microsoft.com/chats/Mkxx7FmzoCCkyaAzfBYaF


## el9-kernel.sh

el9-kernel.sh installs kernel 6.1 (long term) or kernel 6.12 (main line)
in elrepo9 RPM systems such as RedHat9, AlmaLinux9, RockyLinux9, etc.
elrepo9 build with CONFIG_CXL_MEM_RAW_COMMANDS=n.

elrepo.org kernels enable CONFIG_CXL_MEM_RAW_COMMANDS=y starting 2024-12-27:

- kernel-ml-6.12.7-1.el8.elrepo
- kernel-ml-6.12.7-1.el9.elrepo
- kernel-lt-6.1.122-1.el9.elrepo 

See https://elrepo.org/bugs/view.php?id=1498#c10236
toracat
2024-12-27 20:37
administrator   ~0010236
	The requested config change is now in the kernels released today:
kernel-ml-6.12.7-1.el9.elrepo
kernel-ml-6.12.7-1.el8.elrepo
kernel-lt-6.1.122-1.el9.elrepo 


## cxl-raw-debian.sh

cxl-raw-debian.sh gets and compiles the latest kernel (currently 6.1.0-28-amd64 for debian-12.8.0):
Linux deb12-8-0-067x 6.1.0-28-amd64 #1 SMP PREEMPT_DYNAMIC Debian 6.1.119-1 (2024-11-22) x86_64 GNU/Linux


## cxl-raw-sles.sh

rcpao@sles15sp7-06fx:~> cat /etc/os-release 
NAME="SLES"
VERSION="15-SP7"
VERSION_ID="15.7"
PRETTY_NAME="SUSE Linux Enterprise Server 15 SP7"
ID="sles"
ID_LIKE="suse"
ANSI_COLOR="0;32"
CPE_NAME="cpe:/o:suse:sles:15:sp7"
DOCUMENTATION_URL="https://documentation.suse.com/"
rcpao@sles15sp7-06fx:~> uname -r
6.4.0-150700.51-default
rcpao@sles15sp7-06fx:~> 


## Ignore 
Ignore the other (non-functional) scripts in this repository.


# Non-Volatile Memory Modules
CONFIG_STRICT_DEVMEM is required.
"nopat" on the command line is also required.
