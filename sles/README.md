# cxl-raw-enabler

https://github.com/rcpao-smartm-com/cxl-raw-enabler


## SLES (`sles/`)

SLES 15 SP6 (x86_64) tested with kernel 6.4.0-150600.23.81-default.

`sles/cxl-raw-sles.sh` rebuilds the running SUSE kernel with:

- `CONFIG_ACPI_NFIT=y`
- `CONFIG_TRANSPARENT_HUGEPAGE_ALWAYS=y`
- `# CONFIG_TRANSPARENT_HUGEPAGE_MADVISE is not set`
- `CONFIG_CXL_MEM_RAW_COMMANDS=y`
- `CONFIG_CXL_REGION_INVALIDATION_TEST=y`
- `CONFIG_DEV_DAX=y`
- `CONFIG_ND_BTT=y`
- `CONFIG_NVDIMM_SECURITY_TEST=y`
- `CONFIG_BLK_DEV_PMEM=y`
- `CONFIG_IO_STRICT_DEVMEM=y`
- `CONFIG_LOCALVERSION` suffixed with `cxlraw` (e.g., 
  `6.4.0-150600.23.81-cxlraw-default`)

### Build and install on this system

Run `sudo -v` first so install steps (`make modules_install`, `dracut`,
`grub2-mkconfig`, …) do not hang waiting for a password.

```
$ cd ~/Documents/job/sgh/git-repo/cxl-raw-enabler/sles
$ chmod +x cxl-raw-sles.sh
$ sudo -v
$ ./cxl-raw-sles.sh -y
```

`cxl-raw-sles.sh -y` already enables unsupported modules, rebuilds the
initrd, and updates GRUB. On reboot, GRUB should show **both** the stock
SUSE kernel and the custom build as separate entries, for example:

- `6.4.0-150600.23.81-default` — original SUSE `kernel-default` (fallback)
- `6.4.0-150600.23.81-cxlraw-default` — custom build with CXL raw commands

Manual fallback (only if the script did not finish install steps):

```
sudo cp /lib/modprobe.d/10-unsupported-modules.conf /etc/modprobe.d/
sudo sed -i 's/allow_unsupported_modules 0/allow_unsupported_modules 1/' \
  /etc/modprobe.d/10-unsupported-modules.conf
sudo dracut -f /boot/initrd-6.4.0-150600.23.81-cxlraw-default 6.4.0-150600.23.81-cxlraw-default
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
sudo reboot
```

Verify after reboot:

```
$ uname -r
$ grep -E 'CONFIG_(CXL_MEM_RAW_COMMANDS|ACPI_NFIT|TRANSPARENT_HUGEPAGE_ALWAYS|DEV_DAX|ND_BTT|NVDIMM_SECURITY_TEST|BLK_DEV_PMEM|IO_STRICT_DEVMEM)=' /boot/config-$(uname -r)
# Warning: /boot/config may not reflect the running kernel's actual settings
```

### Build RPMs for another system

Use `make binrpm-pkg` (packaged in `sles/utilities/build-kernel-rpms-sles.sh`).

After a successful kernel build on the build host (from the repo root):

```
$ ./sles/utilities/build-kernel-rpms-sles.sh
```

Or from `sles/`:

```
$ ./utilities/build-kernel-rpms-sles.sh
```

Built RPMs are copied to `sles/kernel-rpms-6.4.0-150600.23.81-cxlraw-default/` (version
varies), for example:

- `kernel-6.4.0_150600.23.81_cxlraw_default-1.x86_64.rpm`
- `kernel-headers-6.4.0_150600.23.81_cxlraw_default-1.x86_64.rpm`

### Install RPMs on another system (quick / short)

Copy the kernel RPM and `utilities/sles-kernel-cxlraw-install.sh` into the
**same directory** on the target (the script installs the RPM from cwd).
Does **not** reboot — reboot manually when ready.

```
$ cd sles/
$ rsync -av \
    kernel-rpms-6.4.0-150600.23.81-cxlraw-default/kernel-6.4.0_150600.23.81_cxlraw_default-1.x86_64.rpm \
    utilities/sles-kernel-cxlraw-install.sh \
    username@sles15sp6:
$ ssh username@sles15sp6
$ sudo ./sles-kernel-cxlraw-install.sh
$ sudo reboot
```

### Install RPMs on another system (interactive / long)

Install on another **SLES 15 SP6 x86_64** system with the same architecture.
Copy the **kernel** RPM (not kernel-headers) to `/tmp` on the target, then run
`sles/utilities/install-cxlraw-kernel-rpms-sles.sh` (unsigned local `make binrpm-pkg`
output).

`kernel-headers-*.rpm` from `make binrpm-pkg` conflicts with SLES
`linux-glibc-devel` (`/usr/include/linux/*`). The installer skips headers by
default so the kernel RPM can install fully (modules under
`/lib/modules/.../kernel/drivers/net`, etc.). Pass `--with-headers` only if you
intentionally need those userspace headers.

```
$ scp sles/kernel-rpms-*/kernel-*cxlraw*.rpm target:/tmp/
$ ssh target 'curl -fsSL https://gitlab-ub.memapd.internal/sgh/cxl-raw-enabler/raw/main/sles/utilities/install-cxlraw-kernel-rpms-sles.sh | sudo bash -s -- -y'
```

Or on the target directly after `scp`:

```
$ sudo -v
$ curl -fsSL https://gitlab-ub.memapd.internal/sgh/cxl-raw-enabler/raw/main/sles/utilities/install-cxlraw-kernel-rpms-sles.sh | sudo bash -s -- -y
```

The script installs the kernel RPM (`rpm --nosignature`), enables unsupported
modules, rebuilds initrd with `dracut`, updates GRUB, and reboots. Options:
`-y` to reboot without prompting, `--no-reboot` to skip reboot,
`--with-headers` to also install kernel-headers. Override `KVER`, `RPM_DIR`,
or `KERNEL_RPM` if needed; set `RPM_URL_BASE` to download RPMs instead of
using `/tmp`.

Manual equivalent:

```
$ sudo rpm -Uvh --replacepkgs --nosignature /tmp/kernel-*cxlraw*_default-*.x86_64.rpm
# Do not install kernel-headers-*.rpm on SLES (conflicts with linux-glibc-devel).
# or: sudo zypper install --allow-unsigned-rpm /tmp/kernel-*cxlraw*.rpm
$ sudo cp /lib/modprobe.d/10-unsupported-modules.conf /etc/modprobe.d/
$ sudo sed -i 's/allow_unsupported_modules 0/allow_unsupported_modules 1/' /etc/modprobe.d/10-unsupported-modules.conf
$ sudo dracut -f /boot/initrd-6.4.0-150600.23.81-cxlraw-default 6.4.0-150600.23.81-cxlraw-default
$ sudo grub2-mkconfig -o /boot/grub2/grub.cfg
$ sudo reboot
```

If Secure Boot is enabled on the
target, you may also need MOK enrollment for module signing (see
`sles/utilities/prepare-mok-signing-sles.sh`).

### Example system

```
$ cat /etc/os-release
NAME="SLES"
VERSION="15-SP6"
VERSION_ID="15.6"
PRETTY_NAME="SUSE Linux Enterprise Server 15 SP6"
ID="sles"

$ uname -r
6.4.0-150600.23.81-cxlraw-default
```

