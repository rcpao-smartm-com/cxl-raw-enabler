#!/usr/bin/env bash
set -vx # -euo pipefail

# zip_proget_get.sh -> zip_proget_put.sh
# Usage: zip_proget_{get,put}.sh NAME1 NAME2 SEMVER file1 [file2 ...]
./utilities/zip_proget_put.sh --sha256sum test-configuration-assets SLES15SP6 kernel-rpms 6.4.0-150600.23.81-cxlraw kernel-rpms-6.4.0-150600.23.81-cxlraw-default/*.rpm utilities/sles-kernel-cxlraw-install.sh # must not include SHA256SUM
# ./utilities/zip_proget_get.sh --sha256sum test-configuration-assets SLES15SP6 kernel-rpms 6.4.0-150600.23.81-cxlraw kernel-rpms-6.4.0-150600.23.81-cxlraw-default/*
