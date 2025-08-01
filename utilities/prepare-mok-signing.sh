#!/bin/bash

# Fri Aug  1 01:44:39 PM PDT 2025
# This is a Copilot generated script!
# https://m365.cloud.microsoft/chat/?fromCode=cmcv2&redirectId=D2348CFAF8D14A2DA91B179344E20031&internalredirect=CCM&auth=2

# Variables
KEY_NAME="MOK.key.pem"
CRT_NAME="MOK.crt.pem"
COMBINED_PEM=".kernel_signing_key.pem"
KERNEL_SRC="/usr/src/linux"

# Paths
KEY_PATH="${KERNEL_SRC}/certs/${KEY_NAME}"
CRT_PATH="${KERNEL_SRC}/certs/${CRT_NAME}"
COMBINED_PATH="${KERNEL_SRC}/${COMBINED_PEM}"

# Check if key and cert exist
if [[ ! -f "$KEY_PATH" || ! -f "$CRT_PATH" ]]; then
    echo "Error: Key or certificate file not found in ${KERNEL_SRC}/certs"
    exit 1
fi

# Create combined PEM for kernel build
echo "Creating combined PEM for kernel build..."
cat "$KEY_PATH" "$CRT_PATH" > "$COMBINED_PATH"

# Create symlinks for kernel build
ln -sf "$KEY_PATH" "${KERNEL_SRC}/certs/signing_key.pem"
ln -sf "$CRT_PATH" "${KERNEL_SRC}/certs/signing_key.x509"

echo "Combined PEM and symlinks created successfully."

# Optional: Sign a module manually
if [[ -n "$1" ]]; then
    MODULE="$1"
    SIGN_SCRIPT="${KERNEL_SRC}/scripts/sign-file"
    echo "Signing module $MODULE..."
    sudo "$SIGN_SCRIPT" sha256 "$KEY_PATH" "$CRT_PATH" "$MODULE"
    echo "Module signed."
fi

