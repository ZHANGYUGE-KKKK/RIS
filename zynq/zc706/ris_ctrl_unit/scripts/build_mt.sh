#!/usr/bin/env bash
# Build only: this script never connects to or programs a board.
set -euo pipefail
ris_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ris_tools=${RIS_XILINX_ROOT:-/home/wenhan/SOFTWARE/VIVADO2022.2}
ris_vivado=${RIS_VIVADO_BIN:-$ris_tools/Vivado/2022.2/bin}
ris_xsct=${RIS_XSCT:-$ris_tools/Vitis/2022.2/bin/xsct}
cd "$ris_root"
mkdir -p reports/mt build/mt_hardware
if [[ ! -f vivado_mt/ris_ctrl_unit.xpr ]]; then
    RIS_PROJECT_DIR="$ris_root/vivado_mt" RIS_FRAME_SLOTS=16 RIS_FAST_TOGGLE=1 \
    RIS_QSPI_ENABLE=1 RIS_REPORT_DIR="$ris_root/reports/mt" \
    "$ris_vivado/vivado" -mode batch -source scripts/create_project.tcl \
        -log build/mt_hardware/create.log -journal build/mt_hardware/create.jou
fi
"$ris_vivado/vivado" -mode batch -source scripts/build_mt.tcl \
    -log build/mt_hardware/build.log -journal build/mt_hardware/build.jou \
    2>&1 | tee reports/mt/hardware_build.log
rg -q '^RIS_MT_BUILD_PASS$' reports/mt/hardware_build.log
RIS_NETWORK_WORKSPACE="$ris_root/vitis_mt" RIS_NETWORK_PLATFORM=ris_mt_platform \
RIS_NETWORK_APP=ris_mt_network RIS_XSA="$ris_root/export_mt/ris_ctrl_unit.xsa" \
RIS_EXPORT_DIR="$ris_root/export_mt" RIS_FAST_TOGGLE=1 RIS_MT_TABLE=1 \
RIS_LWIP_VERSION=1.8 "$ris_xsct" -nodisp scripts/build_network_application.tcl \
    2>&1 | tee reports/mt/firmware_build.log
rg -q '^RIS_NETWORK_APPLICATION_BUILD_PASS$' reports/mt/firmware_build.log
