#!/bin/bash
set -euo pipefail

# Offline test for patches/v*/apply-secondary-mbox.py (no kernel build, no sudo).
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TAG=${1:-v7.0}
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

echo "== clone $TAG sparse CXL tree =="
git clone --depth 1 --branch "$TAG" --filter=blob:none --sparse \
	https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git "$WORKDIR/linux" >/dev/null 2>&1
(
	cd "$WORKDIR/linux"
	git sparse-checkout set drivers/cxl include/linux/cxl.h include/uapi/linux
)

apply_py="$ROOT/patches/${TAG}/apply-secondary-mbox.py"
if [ ! -f "$apply_py" ]; then
	apply_py="$ROOT/patches/v7.0/apply-secondary-mbox.py"
fi

echo "== apply $(basename "$apply_py") =="
python3 "$apply_py" "$WORKDIR/linux"

echo "== verify =="
python3 - "$WORKDIR/linux" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
text = (root / "drivers/cxl/core/regs.c").read_text()

def section(fn: str) -> str:
    parts = text.split(f"int {fn}(", 1)
    if len(parts) < 2:
        return ""
    return parts[1].split("EXPORT_SYMBOL_NS_GPL", 1)[0]

comp = section("cxl_map_component_regs")
dev = section("cxl_map_device_regs")
pci = (root / "drivers/cxl/pci.c").read_text()
mbox = (root / "drivers/cxl/core/mbox.c").read_text()
uapi = root / "include/uapi/linux/cxl_mem.h"

checks = {
    "probe maps mbox2": "rmap = &map->mbox2" in text,
    "component_regs: no mbox2 optional map": "Failed to map Secondary Mailbox" not in comp,
    "device_regs: has mbox2 optional map": "Failed to map Secondary Mailbox" in dev,
    "device_regs: mbox2 in mapinfo": "&map->device_map.mbox2, &regs->mbox2" in dev,
    "pci: setup_secondary_mailbox": "cxl_pci_setup_secondary_mailbox" in pci,
    "mbox: SECONDARY_MBOX flag": "CXL_MEM_SEND_FLAG_SECONDARY_MBOX" in mbox,
    "uapi: SECONDARY_MBOX flag": uapi.is_file()
    and "CXL_MEM_SEND_FLAG_SECONDARY_MBOX" in uapi.read_text(),
}
failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(f"{'PASS' if ok else 'FAIL'}: {name}")
if failed:
    raise SystemExit(f"FAILED: {failed}")
print("ALL PASS")
PY

echo "== idempotent re-apply =="
python3 "$apply_py" "$WORKDIR/linux" | grep -q 'secondary mailbox patch applied'
echo "PASS: idempotent re-apply"

echo "== done =="
