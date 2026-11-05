#!/usr/bin/env bash
set -euo pipefail
ris_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ris_vivado_bin=${RIS_VIVADO_BIN:-/home/yyz/vivado2020.2/main/Vivado/2020.2/bin}
mkdir -p "$ris_root/build/simulation" "$ris_root/reports"
cd "$ris_root/build/simulation"
"$ris_vivado_bin/xvlog" --sv \
    "$ris_root/rtl/ris_595_byte.v" \
    "$ris_root/rtl/ris_595_timing.v" \
    "$ris_root/rtl/ris_595_single.v" \
    "$ris_root/rtl/ris_595_bringup.v" \
    "$ris_root/tests/tb_ris_595.sv"
for ris_half in 1 5; do
    ris_snapshot="tb_ris_595_h${ris_half}"
    "$ris_vivado_bin/xelab" tb_ris_595 -generic_top "HALF=$ris_half" -s "$ris_snapshot"
    "$ris_vivado_bin/xsim" "$ris_snapshot" -runall -log "$ris_root/reports/$ris_snapshot.log"
    rg -q '^RIS_595_TEST_PASS' "$ris_root/reports/$ris_snapshot.log"
done
