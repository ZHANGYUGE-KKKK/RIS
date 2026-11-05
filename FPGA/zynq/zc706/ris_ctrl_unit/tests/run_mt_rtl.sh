#!/usr/bin/env bash
set -euo pipefail
ris_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ris_bin=${RIS_VIVADO_BIN:-/home/wenhan/SOFTWARE/VIVADO2022.2/Vivado/2022.2/bin}
mkdir -p "$ris_root/build/mt_simulation" "$ris_root/reports/mt"
cd "$ris_root/build/mt_simulation"
"$ris_bin/xvlog" --sv "$ris_root/rtl/ris_fast_engine.v" "$ris_root/rtl/ris_mt_engine.v" \
    "$ris_root/rtl/ris_fast_io.v" "$ris_root/tests/tb_ris_mt.sv"
"$ris_bin/xvlog" "$ris_bin/../data/verilog/src/glbl.v"
"$ris_bin/xelab" tb_ris_mt glbl -L unisims_ver -s tb_ris_mt -mt 2
"$ris_bin/xsim" tb_ris_mt -runall -log "$ris_root/reports/mt/mt_unisim.log"
rg -q '^RIS_MT_TEST_PASS' "$ris_root/reports/mt/mt_unisim.log"
