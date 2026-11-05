#!/usr/bin/env bash
set -eo pipefail
source "${RIS_VIVADO_SETTINGS:-/home/yyz/vivado2020.2/main/Vivado/2020.2/settings64.sh}"
set -u
ris_project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ris_sim_dir=$(mktemp -d /tmp/rfmc6000_iq_axis.XXXXXX)
ris_vivado_data=$(dirname "$(dirname "$(command -v xvlog)")")/data
printf 'Simulation logs: %s\n' "$ris_sim_dir"
cd "$ris_sim_dir"
xvlog --sv \
    "$ris_vivado_data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
    "$ris_vivado_data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \
    "$ris_vivado_data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv" \
    "$ris_project_dir/tests/reference/axi_ad9361_dev_if_idelay.v" \
    "$ris_project_dir/PZ_UART.srcs/sources_1/new/rfmc6000_iq_axis.v" \
    "$ris_project_dir/tests/tb_rfmc6000_iq_axis.sv" \
    "$ris_vivado_data/verilog/src/glbl.v" > compile.log 2>&1
for ris_case in 1:7:0:1 0:1:0:1 1:4096:0:1 1:7:1:1 1:7:0:0 0:1:0:0; do
    IFS=: read -r ris_edge ris_packet ris_skew ris_fall_delay <<< "$ris_case"
    ris_snapshot="iq_axis_${ris_edge}_${ris_packet}_${ris_skew}_${ris_fall_delay}"
    xelab -L unisims_ver -L secureip tb_rfmc6000_iq_axis glbl \
        -generic_top "I_FALLING=$ris_edge" \
        -generic_top "PACKET_WORDS=$ris_packet" \
        -generic_top "SKEW_TAPS=$ris_skew" \
        -generic_top "FALL_DELAY=$ris_fall_delay" \
        -s "$ris_snapshot" -debug typical -timescale 1ns/1ps \
        > "$ris_snapshot.elab.log" 2>&1
    xsim "$ris_snapshot" -runall -log "$ris_snapshot.log" \
        > "$ris_snapshot.run.log" 2>&1
    if rg -n 'Fatal:|Error:|ERROR:' "$ris_snapshot.run.log"; then
        exit 1
    fi
    rg 'RFMC6000_IQ_AXIS_TEST_PASS' "$ris_snapshot.run.log"
done
