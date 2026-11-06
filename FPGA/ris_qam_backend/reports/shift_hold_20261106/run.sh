#!/usr/bin/env bash
set -euo pipefail
ris_diag=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ris_backend=$(cd -- "$ris_diag/../.." && pwd)
ris_runtime=${RIS_VALIDATION_RUNTIME:-/home/wenhan/SOFTWARE/RIS-Validation/runtime}
ris_vivado=${RIS_VIVADO_ROOT:-/home/wenhan/SOFTWARE/VIVADO2022.2/Vivado/2022.2}
cd "$ris_diag"
"$ris_runtime/usr/bin/iverilog" -B "$ris_runtime/usr/lib/x86_64-linux-gnu/ivl" \
    -g2012 -DRIS_VENDOR_ODDR -s tb_shift_hold -s glbl -o hold.vvp \
    "$ris_backend/tests/mt_sim_primitives.v" \
    "$ris_vivado/data/verilog/src/unisims/ODDR.v" \
    "$ris_vivado/data/verilog/src/glbl.v" \
    "$ris_backend/rtl/ris_fast_engine.v" "$ris_backend/rtl/ris_mt_engine.v" \
    "$ris_backend/rtl/ris_qam_player.v" "$ris_backend/rtl/ris_fast_io.v" \
    tb_shift_hold.sv
"$ris_runtime/usr/bin/vvp" -i hold.vvp | tee simulation.log
rg -q '^SHIFT_HOLD_DIAGNOSTIC_PASS$' simulation.log
