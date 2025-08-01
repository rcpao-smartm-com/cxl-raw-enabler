#!/bin/bash

set -e

# Step 1: Install required packages
echo "Installing required packages..."
sudo zypper install -y efikeygen mokutil openssl kernel-devel

# Step 2: Create working directory
WORKDIR="$HOME/secureboot-signing"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Step 3: Generate MOK key and certificate
echo "Generating MOK key and certificate..."
efikeygen --dbdir . \
  --nickname "Custom MOK Key" \
  --common-name "Custom MOK" \
  --out-cert MOK.crt \
  --out-key MOK.key

# Step 4: Sign a sample kernel module (replace with your actual module path)
MODULE_PATH="/lib/modules/$(uname -r)/kernel/drivers/net/dummy.ko"
SIGNED_MODULE="$WORKDIR/dummy.ko.signed"

echo "Signing kernel module..."
/usr/src/linux-$(uname -r)/scripts/sign-file sha256 MOK.key MOK.crt "$MODULE_PATH" "$SIGNED_MODULE"

# Step 5: Enroll the certificate using mokutil
echo "Preparing certificate for enrollment..."
sudo mokutil --import MOK.crt

echo "✅ Done. Reboot your system and follow the MOK enrollment prompt in UEFI."


