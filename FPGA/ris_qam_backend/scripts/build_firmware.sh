#!/usr/bin/env bash
# Build matching network ELF only. Does not connect to or program hardware.
set -euo pipefail
ris_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ris_xsct=${RIS_XSCT:-/home/wenhan/SOFTWARE/VIVADO2022.2/Vitis/2022.2/bin/xsct}
export PATH="${RIS_MAKE_BIN:-/home/wenhan/SOFTWARE/RIS-Validation/runtime/usr/bin}:$PATH"
cd "$ris_root"
mkdir -p reports/firmware
sha256sum --check reports/qam/source_sha256.txt
RIS_NETWORK_WORKSPACE="$ris_root/vitis_qam" RIS_NETWORK_PLATFORM=ris_qam_platform \
RIS_NETWORK_APP=ris_qam_network RIS_XSA="$ris_root/export_qam/ris_ctrl_unit.xsa" \
RIS_EXPORT_DIR="$ris_root/export_qam" RIS_FAST_TOGGLE=1 RIS_MT_TABLE=1 \
RIS_QAM_TABLE=1 RIS_LWIP_VERSION=1.8 \
"$ris_xsct" -nodisp scripts/build_network_application.tcl \
    2>&1 | tee reports/firmware/build.log
rg -q '^RIS_NETWORK_APPLICATION_BUILD_PASS$' reports/firmware/build.log
python3 scripts/record_build.py
python3 scripts/record_firmware.py
