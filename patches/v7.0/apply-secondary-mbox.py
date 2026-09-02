#!/usr/bin/env python3
"""Apply Secondary Mailbox CCI send support to a Linux v7.0 CXL tree.

Usage:
  python3 apply-secondary-mbox.py /path/to/linux

Idempotent: safe to re-run. Exits 0 if already applied or after a successful
apply. Targets the v7.0 CXL layout used by ub26-7.0.0.sh.
"""
from __future__ import annotations

import sys
from pathlib import Path


class ApplyError(RuntimeError):
    pass


def read(path: Path) -> str:
    if not path.is_file():
        raise ApplyError(f"missing {path}")
    return path.read_text(encoding="utf-8")


def write(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8")
    print(f"updated {path}")


def once(text: str, old: str, new: str, label: str) -> str:
    if new.strip() and new in text and old not in text:
        return text
    if old not in text:
        raise ApplyError(f"{label}: expected snippet not found")
    return text.replace(old, new, 1)


def apply_uapi(root: Path) -> None:
    path = root / "include/uapi/linux/cxl_mem.h"
    text = read(path)
    if "CXL_MEM_SEND_FLAG_SECONDARY_MBOX" in text:
        print(f"already applied {path}")
        return
    old = "#define CXL_MEM_SEND_COMMAND _IOWR(0xCE, 2, struct cxl_send_command)\n"
    new = old + (
        "\n"
        "/*\n"
        " * cxl_send_command.flags: send on the device Secondary Mailbox\n"
        " * (CXL 2.0 8.2.8.2.1 capability ID 0x3) instead of the OS primary\n"
        " * mailbox. Returns -ENODEV if that mailbox is not present.\n"
        " */\n"
        "#define CXL_MEM_SEND_FLAG_SECONDARY_MBOX\t(1U << 16)\n"
    )
    write(path, once(text, old, new, str(path)))


def apply_cxl_h(root: Path) -> None:
    path = root / "drivers/cxl/cxl.h"
    text = read(path)
    if "*mbox2" in text or "mbox2;" in text:
        print(f"already applied {path}")
        return
    text = once(
        text,
        "\t\tvoid __iomem *status, *mbox, *memdev;\n",
        "\t\tvoid __iomem *status, *mbox, *memdev, *mbox2;\n",
        f"{path} device_regs",
    )
    text = once(
        text,
        "\tstruct cxl_reg_map status;\n"
        "\tstruct cxl_reg_map mbox;\n"
        "\tstruct cxl_reg_map memdev;\n",
        "\tstruct cxl_reg_map status;\n"
        "\tstruct cxl_reg_map mbox;\n"
        "\tstruct cxl_reg_map mbox2;\n"
        "\tstruct cxl_reg_map memdev;\n",
        f"{path} device_reg_map",
    )
    write(path, text)


def apply_cxlmem_h(root: Path) -> None:
    path = root / "drivers/cxl/cxlmem.h"
    text = read(path)
    if "cxl_mbox2" in text:
        print(f"already applied {path}")
        return
    text = once(
        text,
        '#include "cxl.h"\n',
        '#include "cxl.h"\n'
        "\n"
        "/*\n"
        " * Fallback when building against stock uapi headers that lack the\n"
        " * secondary-mailbox send flag (BIT(16) on cxl_send_command.flags).\n"
        " */\n"
        "#ifndef CXL_MEM_SEND_FLAG_SECONDARY_MBOX\n"
        "#define CXL_MEM_SEND_FLAG_SECONDARY_MBOX BIT(16)\n"
        "#endif\n",
        f"{path} flag fallback",
    )
    text = once(
        text,
        "\tstruct cxl_mailbox cxl_mbox;\n"
        "#ifdef CONFIG_CXL_FEATURES\n",
        "\tstruct cxl_mailbox cxl_mbox;\n"
        "\tstruct cxl_mailbox cxl_mbox2;\n"
        "#ifdef CONFIG_CXL_FEATURES\n",
        f"{path} cxl_mbox2",
    )
    write(path, text)


def apply_regs_c(root: Path) -> None:
    path = root / "drivers/cxl/core/regs.c"
    text = read(path)
    device_regs = text.split("int cxl_map_device_regs(", 1)
    device_regs_ok = (
        len(device_regs) > 1
        and "Failed to map Secondary Mailbox" in device_regs[1].split("EXPORT_SYMBOL_NS_GPL(cxl_map_device_regs", 1)[0]
    )
    if "rmap = &map->mbox2" in text and device_regs_ok:
        print(f"already applied {path}")
        return
    if "rmap = &map->mbox2" not in text:
        text = once(
            text,
            "\t\tcase CXLDEV_CAP_CAP_ID_SECONDARY_MAILBOX:\n"
            '\t\t\tdev_dbg(dev, "found Secondary Mailbox capability (0x%x)\\n", offset);\n'
            "\t\t\tbreak;\n",
            "\t\tcase CXLDEV_CAP_CAP_ID_SECONDARY_MAILBOX:\n"
            '\t\t\tdev_info(dev, "found Secondary Mailbox capability (0x%x)\\n", offset);\n'
            "\t\t\trmap = &map->mbox2;\n"
            "\t\t\tbreak;\n",
            f"{path} probe secondary",
        )
    if "&map->device_map.mbox2, &regs->mbox2" not in text:
        text = once(
            text,
            "\t\t{ &map->device_map.status, &regs->status, },\n"
            "\t\t{ &map->device_map.mbox, &regs->mbox, },\n"
            "\t\t{ &map->device_map.memdev, &regs->memdev, },\n",
            "\t\t{ &map->device_map.status, &regs->status, },\n"
            "\t\t{ &map->device_map.mbox, &regs->mbox, },\n"
            "\t\t{ &map->device_map.mbox2, &regs->mbox2, },\n"
            "\t\t{ &map->device_map.memdev, &regs->memdev, },\n",
            f"{path} mapinfo",
        )
    # An earlier version of this script patched the first matching loop in
    # cxl_map_component_regs by mistake; undo that if present.
    text = text.replace(
        "\t\t*(mi->addr) = devm_cxl_iomap_block(host, addr, length);\n"
        "\t\tif (!*(mi->addr)) {\n"
        "\t\t\tif (mi->rmap == &map->device_map.mbox2) {\n"
        '\t\t\t\tdev_warn(host, "Failed to map Secondary Mailbox\\n");\n'
        "\t\t\t\tcontinue;\n"
        "\t\t\t}\n"
        "\t\t\treturn -ENOMEM;\n"
        "\t\t}\n",
        "\t\t*(mi->addr) = devm_cxl_iomap_block(host, addr, length);\n"
        "\t\tif (!*(mi->addr))\n"
        "\t\t\treturn -ENOMEM;\n",
        1,
    )
    text = once(
        text,
        "\t\taddr = phys_addr + mi->rmap->offset;\n"
        "\t\tlength = mi->rmap->size;\n"
        "\t\t*(mi->addr) = devm_cxl_iomap_block(host, addr, length);\n"
        "\t\tif (!*(mi->addr))\n"
        "\t\t\treturn -ENOMEM;\n",
        "\t\taddr = phys_addr + mi->rmap->offset;\n"
        "\t\tlength = mi->rmap->size;\n"
        "\t\t*(mi->addr) = devm_cxl_iomap_block(host, addr, length);\n"
        "\t\tif (!*(mi->addr)) {\n"
        "\t\t\tif (mi->rmap == &map->device_map.mbox2) {\n"
        '\t\t\t\tdev_warn(host, "Failed to map Secondary Mailbox\\n");\n'
        "\t\t\t\tcontinue;\n"
        "\t\t\t}\n"
        "\t\t\treturn -ENOMEM;\n"
        "\t\t}\n",
        f"{path} optional map",
    )
    write(path, text)


def apply_mbox_c(root: Path) -> None:
    path = root / "drivers/cxl/core/mbox.c"
    text = read(path)
    if "CXL_MEM_SEND_FLAG_SECONDARY_MBOX" in text:
        print(f"already applied {path}")
        return
    old = (
        "\tif (copy_from_user(&send, s, sizeof(send)))\n"
        "\t\treturn -EFAULT;\n"
        "\n"
        "\trc = cxl_validate_cmd_from_user(&mbox_cmd, cxl_mbox, &send);\n"
    )
    new = (
        "\tif (copy_from_user(&send, s, sizeof(send)))\n"
        "\t\treturn -EFAULT;\n"
        "\n"
        "\tif (send.flags & CXL_MEM_SEND_FLAG_SECONDARY_MBOX) {\n"
        "\t\tstruct cxl_dev_state *cxlds = mbox_to_cxlds(cxl_mbox);\n"
        "\n"
        "\t\tif (!cxlds || !cxlds->regs.mbox2 || !cxlds->cxl_mbox2.mbox_send)\n"
        "\t\t\treturn -ENODEV;\n"
        "\n"
        "\t\tsend.flags &= ~CXL_MEM_SEND_FLAG_SECONDARY_MBOX;\n"
        "\t\tcxl_mbox = &cxlds->cxl_mbox2;\n"
        '\t\tdev_dbg(dev, "Send IOCTL -> Secondary Mailbox\\n");\n'
        "\t}\n"
        "\n"
        "\trc = cxl_validate_cmd_from_user(&mbox_cmd, cxl_mbox, &send);\n"
    )
    write(path, once(text, old, new, str(path)))


def apply_memdev_c(root: Path) -> None:
    path = root / "drivers/cxl/core/memdev.c"
    text = read(path)
    if "secondary_payload_max" in text:
        print(f"already applied {path}")
        return
    old = "static DEVICE_ATTR_RO(payload_max);\n"
    new = (
        "static DEVICE_ATTR_RO(payload_max);\n"
        "\n"
        "static ssize_t secondary_payload_max_show(struct device *dev,\n"
        "\t\t\t\t\t struct device_attribute *attr,\n"
        "\t\t\t\t\t char *buf)\n"
        "{\n"
        "\tstruct cxl_memdev *cxlmd = to_cxl_memdev(dev);\n"
        "\tstruct cxl_dev_state *cxlds = cxlmd->cxlds;\n"
        "\n"
        "\tif (!cxlds->regs.mbox2 || !cxlds->cxl_mbox2.payload_size)\n"
        '\t\treturn sysfs_emit(buf, "0\\n");\n'
        '\treturn sysfs_emit(buf, "%zu\\n", cxlds->cxl_mbox2.payload_size);\n'
        "}\n"
        "static DEVICE_ATTR_RO(secondary_payload_max);\n"
    )
    text = once(text, old, new, f"{path} show")
    text = once(
        text,
        "\t&dev_attr_payload_max.attr,\n"
        "\t&dev_attr_label_storage_size.attr,\n",
        "\t&dev_attr_payload_max.attr,\n"
        "\t&dev_attr_secondary_payload_max.attr,\n"
        "\t&dev_attr_label_storage_size.attr,\n",
        f"{path} attrs",
    )
    write(path, text)


def apply_pci_c(root: Path) -> None:
    path = root / "drivers/cxl/pci.c"
    text = read(path)
    if "cxl_pci_setup_secondary_mailbox" in text:
        print(f"already applied {path}")
        return

    text = once(
        text,
        "#define cxl_doorbell_busy(cxlds)                                                \\\n"
        "\t(readl((cxlds)->regs.mbox + CXLDEV_MBOX_CTRL_OFFSET) &                  \\\n"
        "\t CXLDEV_MBOX_CTRL_DOORBELL)\n\n",
        "#define cxl_mbox_doorbell_busy(mbox)\t\t\t\t\t\\\n"
        "\t(readl((mbox) + CXLDEV_MBOX_CTRL_OFFSET) & CXLDEV_MBOX_CTRL_DOORBELL)\n"
        "\n"
        "static void __iomem *cxl_pci_mbox_regs(struct cxl_mailbox *cxl_mbox)\n"
        "{\n"
        "\tstruct cxl_dev_state *cxlds = mbox_to_cxlds(cxl_mbox);\n"
        "\n"
        "\tif (!cxlds)\n"
        "\t\treturn NULL;\n"
        "\tif (cxl_mbox == &cxlds->cxl_mbox2)\n"
        "\t\treturn cxlds->regs.mbox2;\n"
        "\treturn cxlds->regs.mbox;\n"
        "}\n",
        f"{path} doorbell helper",
    )

    text = once(
        text,
        "static int cxl_pci_mbox_wait_for_doorbell(struct cxl_dev_state *cxlds)\n"
        "{\n"
        "\tconst unsigned long start = jiffies;\n"
        "\tunsigned long end = start;\n"
        "\n"
        "\twhile (cxl_doorbell_busy(cxlds)) {\n"
        "\t\tend = jiffies;\n"
        "\n"
        "\t\tif (time_after(end, start + CXL_MAILBOX_TIMEOUT_MS)) {\n"
        "\t\t\t/* Check again in case preempted before timeout test */\n"
        "\t\t\tif (!cxl_doorbell_busy(cxlds))\n"
        "\t\t\t\tbreak;\n"
        "\t\t\treturn -ETIMEDOUT;\n"
        "\t\t}\n"
        "\t\tcpu_relax();\n"
        "\t}\n"
        "\n"
        '\tdev_dbg(cxlds->dev, "Doorbell wait took %dms",\n'
        "\t\tjiffies_to_msecs(end) - jiffies_to_msecs(start));\n"
        "\treturn 0;\n"
        "}\n",
        "static int cxl_pci_mbox_wait_for_doorbell(void __iomem *mbox, struct device *dev)\n"
        "{\n"
        "\tconst unsigned long start = jiffies;\n"
        "\tunsigned long end = start;\n"
        "\n"
        "\twhile (cxl_mbox_doorbell_busy(mbox)) {\n"
        "\t\tend = jiffies;\n"
        "\n"
        "\t\tif (time_after(end, start + CXL_MAILBOX_TIMEOUT_MS)) {\n"
        "\t\t\t/* Check again in case preempted before timeout test */\n"
        "\t\t\tif (!cxl_mbox_doorbell_busy(mbox))\n"
        "\t\t\t\tbreak;\n"
        "\t\t\treturn -ETIMEDOUT;\n"
        "\t\t}\n"
        "\t\tcpu_relax();\n"
        "\t}\n"
        "\n"
        '\tdev_dbg(dev, "Doorbell wait took %dms",\n'
        "\t\tjiffies_to_msecs(end) - jiffies_to_msecs(start));\n"
        "\treturn 0;\n"
        "}\n",
        f"{path} wait doorbell",
    )

    text = once(
        text,
        "static bool cxl_mbox_background_complete(struct cxl_dev_state *cxlds)\n"
        "{\n"
        "\tu64 reg;\n"
        "\n"
        "\treg = readq(cxlds->regs.mbox + CXLDEV_MBOX_BG_CMD_STATUS_OFFSET);\n"
        "\treturn FIELD_GET(CXLDEV_MBOX_BG_CMD_COMMAND_PCT_MASK, reg) == 100;\n"
        "}\n",
        "static bool cxl_mbox_background_complete(void __iomem *mbox)\n"
        "{\n"
        "\tu64 reg;\n"
        "\n"
        "\treg = readq(mbox + CXLDEV_MBOX_BG_CMD_STATUS_OFFSET);\n"
        "\treturn FIELD_GET(CXLDEV_MBOX_BG_CMD_COMMAND_PCT_MASK, reg) == 100;\n"
        "}\n",
        f"{path} bg complete",
    )

    text = text.replace(
        "cxl_mbox_background_complete(cxlds)",
        "cxl_mbox_background_complete(cxlds->regs.mbox)",
    )

    text = once(
        text,
        "\tstruct cxl_memdev_state *mds = to_cxl_memdev_state(cxlds);\n"
        "\tvoid __iomem *payload = cxlds->regs.mbox + CXLDEV_MBOX_PAYLOAD_OFFSET;\n"
        "\tstruct device *dev = cxlds->dev;\n",
        "\tstruct cxl_memdev_state *mds = to_cxl_memdev_state(cxlds);\n"
        "\tvoid __iomem *mbox = cxl_pci_mbox_regs(cxl_mbox);\n"
        "\tvoid __iomem *payload;\n"
        "\tstruct device *dev = cxlds->dev;\n",
        f"{path} send locals",
    )
    text = once(
        text,
        "\tint rc;\n"
        "\n"
        "\tlockdep_assert_held(&cxl_mbox->mbox_mutex);\n",
        "\tint rc;\n"
        "\n"
        "\tpayload = mbox + CXLDEV_MBOX_PAYLOAD_OFFSET;\n"
        "\tlockdep_assert_held(&cxl_mbox->mbox_mutex);\n",
        f"{path} payload init",
    )

    replacements = [
        (
            "\tif (cxl_doorbell_busy(cxlds)) {\n",
            "\tif (cxl_mbox_doorbell_busy(mbox)) {\n",
        ),
        (
            "\twriteq(cmd_reg, cxlds->regs.mbox + CXLDEV_MBOX_CMD_OFFSET);\n",
            "\twriteq(cmd_reg, mbox + CXLDEV_MBOX_CMD_OFFSET);\n",
        ),
        (
            "\twritel(CXLDEV_MBOX_CTRL_DOORBELL,\n"
            "\t       cxlds->regs.mbox + CXLDEV_MBOX_CTRL_OFFSET);\n",
            "\twritel(CXLDEV_MBOX_CTRL_DOORBELL,\n"
            "\t       mbox + CXLDEV_MBOX_CTRL_OFFSET);\n",
        ),
        (
            "\trc = cxl_pci_mbox_wait_for_doorbell(cxlds);\n",
            "\trc = cxl_pci_mbox_wait_for_doorbell(mbox, dev);\n",
        ),
        (
            "\tstatus_reg = readq(cxlds->regs.mbox + CXLDEV_MBOX_STATUS_OFFSET);\n",
            "\tstatus_reg = readq(mbox + CXLDEV_MBOX_STATUS_OFFSET);\n",
        ),
        (
            "\tif (mbox_cmd->opcode == CXL_MBOX_OP_SANITIZE) {\n",
            "\tif (mbox_cmd->opcode == CXL_MBOX_OP_SANITIZE &&\n"
            "\t    cxl_mbox != &cxlds->cxl_mbox2) {\n",
        ),
        (
            "\t\t\t\t\t       cxl_mbox_background_complete(cxlds->regs.mbox),\n",
            "\t\t\t\t\t       cxl_mbox_background_complete(mbox),\n",
        ),
        (
            "\t\tif (!cxl_mbox_background_complete(cxlds->regs.mbox)) {\n",
            "\t\tif (!cxl_mbox_background_complete(mbox)) {\n",
        ),
        (
            "\t\tbg_status_reg = readq(cxlds->regs.mbox +\n"
            "\t\t\t\t      CXLDEV_MBOX_BG_CMD_STATUS_OFFSET);\n",
            "\t\tbg_status_reg = readq(mbox + CXLDEV_MBOX_BG_CMD_STATUS_OFFSET);\n",
        ),
        (
            "\tcmd_reg = readq(cxlds->regs.mbox + CXLDEV_MBOX_CMD_OFFSET);\n",
            "\tcmd_reg = readq(mbox + CXLDEV_MBOX_CMD_OFFSET);\n",
        ),
        (
            "\tif (cxl_pci_mbox_wait_for_doorbell(cxlds) != 0) {\n",
            "\tif (cxl_pci_mbox_wait_for_doorbell(cxlds->regs.mbox, dev) != 0) {\n",
        ),
    ]
    for old, new in replacements:
        if old not in text:
            raise ApplyError(f"{path}: missing snippet:\n{old}")
        text = text.replace(old, new, 1)

    setup_fn = r'''
/*
 * Optional Secondary Mailbox. Poll-only (no background-command IRQ).
 * Missing or unusable secondary mailbox is not a probe failure.
 */
static int cxl_pci_setup_secondary_mailbox(struct cxl_dev_state *cxlds)
{
	struct cxl_mailbox *mbox2 = &cxlds->cxl_mbox2;
	struct device *dev = cxlds->dev;
	size_t payload_size;
	u32 cap;
	int rc;

	if (!cxlds->regs.mbox2)
		return 0;

	rc = cxl_mailbox_init(mbox2, cxlds->dev);
	if (rc)
		return rc;

	if (cxl_pci_mbox_wait_for_doorbell(cxlds->regs.mbox2, dev) != 0) {
		dev_warn(dev, "Secondary mailbox doorbell busy; not enabling\n");
		cxlds->regs.mbox2 = NULL;
		return 0;
	}

	cap = readl(cxlds->regs.mbox2 + CXLDEV_MBOX_CAPS_OFFSET);
	payload_size = 1 << FIELD_GET(CXLDEV_MBOX_CAP_PAYLOAD_SIZE_MASK, cap);
	payload_size = min_t(size_t, payload_size, SZ_1M);
	if (payload_size < 256) {
		dev_warn(dev, "Secondary mailbox too small (%zub); not enabling\n",
			 payload_size);
		cxlds->regs.mbox2 = NULL;
		return 0;
	}

	mbox2->mbox_send = cxl_pci_mbox_send;
	mbox2->payload_size = payload_size;
	dev_info(dev, "Secondary mailbox enabled, payload %zu bytes\n",
		 payload_size);
	return 0;
}

'''
    text = once(
        text,
        "static bool is_cxl_restricted(struct pci_dev *pdev)\n",
        setup_fn + "static bool is_cxl_restricted(struct pci_dev *pdev)\n",
        f"{path} setup secondary fn",
    )

    text = once(
        text,
        "\trc = cxl_pci_setup_mailbox(mds, irq_avail);\n"
        "\tif (rc)\n"
        "\t\treturn rc;\n"
        "\n"
        "\trc = cxl_enumerate_cmds(mds);\n"
        "\tif (rc)\n"
        "\t\treturn rc;\n"
        "\n"
        "\trc = cxl_set_timestamp(mds);\n",
        "\trc = cxl_pci_setup_mailbox(mds, irq_avail);\n"
        "\tif (rc)\n"
        "\t\treturn rc;\n"
        "\n"
        "\trc = cxl_pci_setup_secondary_mailbox(cxlds);\n"
        "\tif (rc)\n"
        "\t\treturn rc;\n"
        "\n"
        "\trc = cxl_enumerate_cmds(mds);\n"
        "\tif (rc)\n"
        "\t\treturn rc;\n"
        "\n"
        "\tif (cxlds->regs.mbox2 && cxlds->cxl_mbox2.mbox_send)\n"
        "\t\tbitmap_copy(cxlds->cxl_mbox2.enabled_cmds,\n"
        "\t\t\t    cxlds->cxl_mbox.enabled_cmds,\n"
        "\t\t\t    CXL_MEM_COMMAND_ID_MAX);\n"
        "\n"
        "\trc = cxl_set_timestamp(mds);\n",
        f"{path} probe hook",
    )
    leftovers = [
        "cxl_doorbell_busy(",
        "cxl_pci_mbox_wait_for_doorbell(cxlds)",
        "cxl_mbox_background_complete(cxlds)",
        "cxlds->regs.mbox + CXLDEV_MBOX_CMD_OFFSET",
    ]
    for leftover in leftovers:
        if leftover in text:
            raise ApplyError(f"{path}: leftover {leftover!r} after apply")
    if text.count("cxl_mbox_background_complete(mbox)") < 2:
        raise ApplyError(
            f"{path}: send path still polling the primary mailbox"
        )
    write(path, text)


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    root = Path(sys.argv[1]).resolve()
    if not (root / "drivers/cxl/pci.c").is_file():
        raise ApplyError(f"{root} does not look like a kernel tree with drivers/cxl")

    apply_cxl_h(root)
    apply_cxlmem_h(root)
    apply_regs_c(root)
    apply_mbox_c(root)
    apply_memdev_c(root)
    apply_pci_c(root)
    uapi = root / "include/uapi/linux/cxl_mem.h"
    if uapi.is_file():
        apply_uapi(root)
    else:
        print(f"skip missing {uapi} (module fallback define is enough)")
    print("secondary mailbox patch applied")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ApplyError as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1)
