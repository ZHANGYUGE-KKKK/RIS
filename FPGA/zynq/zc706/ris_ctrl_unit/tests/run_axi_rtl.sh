#!/usr/bin/env bash
set -euo pipefail
ris_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ris_vivado_bin=${RIS_VIVADO_BIN:-/home/yyz/vivado2020.2/main/Vivado/2020.2/bin}
ris_frames=${RIS_TEST_FRAME_SLOTS:-16}
if [[ ! "$ris_frames" =~ ^[0-9]+$ ]] || (( ris_frames < 16 || ris_frames > 256 )); then
    echo 'RIS_TEST_FRAME_SLOTS must be 16..256' >&2
    exit 1
fi
ris_suffix=""
if [[ "$ris_frames" != 16 ]]; then ris_suffix="_$ris_frames"; fi
mkdir -p "$ris_root/build/axi_simulation$ris_suffix" "$ris_root/reports"
cd "$ris_root/build/axi_simulation$ris_suffix"
"$ris_vivado_bin/xvlog" --sv \
    "$ris_root/rtl/ris_595_byte.v" "$ris_root/rtl/ris_595_array.v" "$ris_root/rtl/ris_frame_ram.v" \
    "$ris_root/rtl/ris_axi4_slave.v" "$ris_root/rtl/ris_controller_core.sv" \
    "$ris_root/rtl/ris_controller_axi.v" "$ris_root/tests/tb_ris_controller.sv"
"$ris_vivado_bin/xelab" tb_ris_controller -generic_top "FRAME_SLOTS=$ris_frames" -s tb_ris_controller -mt 4
"$ris_vivado_bin/xsim" tb_ris_controller -runall -log "$ris_root/reports/tb_ris_controller$ris_suffix.log"
rg -q '^RIS_AXI_TEST_PASS' "$ris_root/reports/tb_ris_controller$ris_suffix.log"
