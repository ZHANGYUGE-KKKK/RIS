#!/usr/bin/env bash
set -eo pipefail
source "${RIS_VIVADO_SETTINGS:-/home/yyz/vivado2020.2/main/Vivado/2020.2/settings64.sh}"
set -u
ris_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ris_sim_dir=$(mktemp -d /tmp/ad9361_rx_axis.XXXXXX)
ris_data=$(dirname "$(dirname "$(command -v xvlog)")")/data
printf 'Simulation logs: %s\n' "$ris_sim_dir"
mapfile -t ris_vendor < <(rg --files "$ris_root/PZ_UART.srcs/sources_1/adi_hdl" -g '*.v' | sort)
cd "$ris_sim_dir"
xvlog --sv "$ris_data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
 "$ris_data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" "$ris_data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv" \
 "${ris_vendor[@]}" "$ris_root/PZ_UART.srcs/sources_1/new/ad9361_rx_lvds_if.v" \
 "$ris_root/PZ_UART.srcs/sources_1/new/ad9361_rx_axis.v" \
 "$ris_root/tests/tb_ad9361_rx_axis.sv" "$ris_data/verilog/src/glbl.v" > compile.log 2>&1
for ris_packet in 1 7 4096; do
 ris_snapshot="adi_rx_${ris_packet}"
 xelab -L unisims_ver -L unimacro_ver -L secureip tb_ad9361_rx_axis glbl \
  -generic_top "PACKET_WORDS=$ris_packet" -s "$ris_snapshot" -debug typical -timescale 1ns/1ps > "$ris_snapshot.elab.log" 2>&1
 xsim "$ris_snapshot" -runall -log "$ris_snapshot.log" > "$ris_snapshot.run.log" 2>&1
 if rg 'Fatal:|Error:|ERROR:' "$ris_snapshot.run.log"; then exit 1; fi
 rg 'PASS' "$ris_snapshot.run.log"
done
