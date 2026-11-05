#!/usr/bin/env bash
set -eo pipefail
source "${RIS_VIVADO_SETTINGS:-/home/yyz/vivado2020.2/main/Vivado/2020.2/settings64.sh}"
set -u
ris_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ris_sim_dir=$(mktemp -d /tmp/ad9361_rx_stage1.XXXXXX)
ris_data=$(dirname "$(dirname "$(command -v xvlog)")")/data
ris_vendor="$ris_root/PZ_UART.srcs/sources_1/adi_hdl"
printf 'Stage 1 simulation logs: %s\n' "$ris_sim_dir"
cd "$ris_sim_dir"
xvlog --sv "$ris_vendor/library/xilinx/common/ad_data_clk.v" \
 "$ris_vendor/library/xilinx/common/ad_data_in.v" \
 "$ris_vendor/library/xilinx/common/ad_data_out.v" \
 "$ris_vendor/library/axi_ad9361/xilinx/axi_ad9361_lvds_if.v" \
 "$ris_root/PZ_UART.srcs/sources_1/new/ad9361_rx_lvds_if.v" \
 "$ris_root/tests/tb_ad9361_rx_lvds_if.sv" "$ris_data/verilog/src/glbl.v" > compile.log 2>&1
for ris_case in '0 8.138' '1 8.138' '0 2.0345' '1 4.069'; do
  read -r ris_r1 ris_half <<< "$ris_case"
  ris_snapshot="stage1_${ris_r1}_${ris_half//./_}"
  xelab -L unisims_ver -L unimacro_ver -L secureip tb_ad9361_rx_lvds_if glbl \
   -generic_top "RX_HALF_PERIOD_NS=$ris_half" -generic_top "R1_MODE=$ris_r1" \
   -s "$ris_snapshot" -debug typical -timescale 1ns/1ps > "$ris_snapshot.elab.log" 2>&1
  xsim "$ris_snapshot" -runall -log "$ris_snapshot.log" > "$ris_snapshot.run.log" 2>&1
  if rg 'Fatal:|Error:|ERROR:' "$ris_snapshot.run.log"; then exit 1; fi
  rg 'AD9361_RX_STAGE1_PASS' "$ris_snapshot.run.log"
done
