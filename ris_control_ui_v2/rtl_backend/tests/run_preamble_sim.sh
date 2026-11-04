#!/usr/bin/env bash
set -euo pipefail
ris_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ris_runtime=${RIS_VALIDATION_RUNTIME:-/home/wenhan/SOFTWARE/RIS-Validation/runtime}
ris_vivado=${RIS_VIVADO_BIN:-/home/wenhan/SOFTWARE/VIVADO2022.2/Vivado/2022.2/bin}
cd "$ris_root"
mkdir -p build/simulation reports/preamble
python3 tests/make_preamble_fixture.py
"$ris_runtime/usr/bin/iverilog" -B "$ris_runtime/usr/lib/x86_64-linux-gnu/ivl" \
  -g2012 -s tb_ris_qam -s glbl -DRIS_VENDOR_ODDR -o build/simulation/preamble.vvp \
  tests/mt_sim_primitives.v "$ris_vivado/../data/verilog/src/unisims/ODDR.v" \
  "$ris_vivado/../data/verilog/src/glbl.v" rtl/ris_fast_engine.v rtl/ris_mt_engine.v \
  rtl/ris_qam_player.v rtl/ris_fast_io.v tests/tb_ris_qam.sv
"$ris_runtime/usr/bin/vvp" -i build/simulation/preamble.vvp \
  "+FIXTURE=$ris_root/build/preamble_fixture/retimed" +CHECK_PREAMBLE \
  | tee reports/preamble/rtl_simulation.log
rg -q '^RIS_PREAMBLE_TEST_PASS' reports/preamble/rtl_simulation.log
rg -q '^RIS_QAM_TEST_PASS' reports/preamble/rtl_simulation.log
