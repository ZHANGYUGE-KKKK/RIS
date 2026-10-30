#!/usr/bin/env bash
set -euo pipefail
ris_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ris_bin=${RIS_VIVADO_BIN:-/home/yyz/vivado2020.2/main/Vivado/2020.2/bin}
mkdir -p "$ris_root/build/fast_simulation" "$ris_root/reports/fast_toggle"
cd "$ris_root/build/fast_simulation"
"$ris_bin/xvlog" --sv "$ris_root/rtl/ris_fast_engine.v" "$ris_root/rtl/ris_mt_engine.v" "$ris_root/rtl/ris_fast_io.v" "$ris_root/tests/tb_ris_fast.sv"
"$ris_bin/xvlog" "$ris_bin/../data/verilog/src/glbl.v"
"$ris_bin/xelab" tb_ris_fast glbl -L unisims_ver -s tb_ris_fast -mt 2
"$ris_bin/xsim" tb_ris_fast -runall -log "$ris_root/reports/fast_toggle/simulation.log"
rg -q '^RIS_FAST_TEST_PASS' "$ris_root/reports/fast_toggle/simulation.log"
