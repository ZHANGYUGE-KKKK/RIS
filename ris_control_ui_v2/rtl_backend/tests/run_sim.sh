#!/usr/bin/env bash
set -euo pipefail
ris_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ris_mode=${1:-icarus}
ris_bin=${RIS_VIVADO_BIN:-/home/wenhan/SOFTWARE/VIVADO2022.2/Vivado/2022.2/bin}
mkdir -p "$ris_root/build/simulation" "$ris_root/reports/simulation"
python3 "$ris_root/tests/make_codebook_fixture.py"
cd "$ris_root/build/simulation"
ris_sources=("$ris_root/rtl/ris_fast_engine.v" "$ris_root/rtl/ris_mt_engine.v"
             "$ris_root/rtl/ris_qam_player.v" "$ris_root/rtl/ris_fast_io.v")
if [[ "$ris_mode" == icarus || "$ris_mode" == vendor ]]; then
    ris_runtime=${RIS_VALIDATION_RUNTIME:-/home/wenhan/SOFTWARE/RIS-Validation/runtime}
    ris_vendor=(-DRIS_VENDOR_ODDR -s glbl "$ris_bin/../data/verilog/src/unisims/ODDR.v"
                "$ris_bin/../data/verilog/src/glbl.v")
    ris_extra=()
    if [[ "$ris_mode" == vendor ]]; then ris_extra=("${ris_vendor[@]}"); fi
    for ris_tb in tb_ris_qam tb_ris_mt tb_ris_fast tb_ris_595; do
        if [[ "$ris_tb" == tb_ris_595 ]]; then
            ris_compile=("$ris_root/rtl/ris_595_byte.v" "$ris_root/rtl/ris_595_timing.v"
                         "$ris_root/rtl/ris_595_single.v" "$ris_root/rtl/ris_595_bringup.v")
        else
            ris_compile=("${ris_sources[@]}")
        fi
        "$ris_runtime/usr/bin/iverilog" -B "$ris_runtime/usr/lib/x86_64-linux-gnu/ivl" \
            -g2012 -s "$ris_tb" -o "$ris_tb.vvp" "$ris_root/tests/mt_sim_primitives.v" \
            "${ris_extra[@]}" "${ris_compile[@]}" "$ris_root/tests/$ris_tb.sv"
        "$ris_runtime/usr/bin/vvp" -i "$ris_tb.vvp" \
            "+FIXTURE=$ris_root/build/codebook_fixture/retimed" \
            | tee "$ris_root/reports/simulation/${ris_tb}_${ris_mode}.log"
        rg -q 'RIS_.*TEST_PASS' "$ris_root/reports/simulation/${ris_tb}_${ris_mode}.log"
    done
    python3 "$ris_root/tests/portable_core.py"
    for ris_fast in 0 1; do
        # The integrated fast IO test includes the vendor's global startup reset.
        "$ris_runtime/usr/bin/iverilog" -B "$ris_runtime/usr/lib/x86_64-linux-gnu/ivl" \
            -g2012 -s tb_ris_controller -P"tb_ris_controller.FAST=$ris_fast" \
            "${ris_vendor[@]}" -o "tb_axi_f$ris_fast.vvp" \
            "$ris_root/tests/mt_sim_primitives.v" "$ris_root"/rtl/*.v \
            "$ris_root/build/simulation/ris_controller_core_icarus.sv" \
            "$ris_root/tests/tb_ris_controller.sv"
        "$ris_runtime/usr/bin/vvp" -i "tb_axi_f$ris_fast.vvp" \
            | tee "$ris_root/reports/simulation/axi_f${ris_fast}_${ris_mode}.log"
        rg -q '^RIS_AXI_TEST_PASS' "$ris_root/reports/simulation/axi_f${ris_fast}_${ris_mode}.log"
    done
elif [[ "$ris_mode" == unisim || "$ris_mode" == xsim ]]; then
    "$ris_bin/xvlog" --sv "${ris_sources[@]}" "$ris_root/tests/tb_ris_qam.sv" \
        "$ris_root/tests/tb_ris_mt.sv" "$ris_root/tests/tb_ris_fast.sv"
    "$ris_bin/xvlog" "$ris_bin/../data/verilog/src/glbl.v"
    for ris_tb in tb_ris_qam tb_ris_mt tb_ris_fast; do
        "$ris_bin/xelab" "$ris_tb" glbl -L unisims_ver -s "${ris_tb}_unisim" -mt 2
        "$ris_bin/xsim" "${ris_tb}_unisim" -runall \
            -testplusarg "FIXTURE=$ris_root/build/codebook_fixture/retimed" \
            -log "$ris_root/reports/simulation/${ris_tb}_unisim.log"
        rg -q 'RIS_.*TEST_PASS' "$ris_root/reports/simulation/${ris_tb}_unisim.log"
    done
else
    echo 'usage: run_sim.sh [icarus|vendor|xsim]' >&2
    exit 2
fi
