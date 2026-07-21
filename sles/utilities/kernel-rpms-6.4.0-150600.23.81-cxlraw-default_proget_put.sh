#!/usr/bin/env bash
set -vx # -euo pipefail

# zip_proget_get.sh -> zip_proget_put.sh
# Usage: zip_proget_{get,put}.sh NAME1 NAME2 SEMVER file1 [file2 ...]
./zip_proget_put.sh SLES15SP6 kernel-rpms 6.4.0-150600.23.81-cxlraw kernel-rpms-6.4.0-150600.23.81-cxlraw-default/*
# ./zip_proget_get.sh SLES15SP6 kernel-rpms 6.4.0-150600.23.81-cxlraw kernel-rpms-6.4.0-150600.23.81-cxlraw-default/*
