#!/usr/bin/env bash
set -euo pipefail
capture_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
capture_vivado_bin=${CAPTURE_VIVADO_BIN:-/home/yyz/vivado2020.2/main/Vivado/2020.2/bin}
capture_sim_dir=$(mktemp -d /tmp/rfmc_rtl_tests.XXXXXX)
trap 'rm -rf "$capture_sim_dir"' EXIT
mkdir -p "$capture_root/reports"
cd "$capture_sim_dir"
"$capture_vivado_bin/xvlog" --sv \
    "$capture_root/PZ_UART.srcs/sources_1/new/rfmc_capture_axis.v" \
    "$capture_root/PZ_UART.srcs/sources_1/new/rfmc_rx_pack.v" \
    "$capture_root/tests/tb_rfmc_capture.v" \
    "$capture_root/tests/tb_rfmc_rx_pack.v"
for capture_tb in tb_rfmc_capture tb_rfmc_rx_pack; do
    "$capture_vivado_bin/xelab" "$capture_tb" -s "$capture_tb"
    "$capture_vivado_bin/xsim" "$capture_tb" -runall -log "$capture_tb.log"
    cp "$capture_tb.log" "$capture_root/reports/$capture_tb.log"
    if [[ "$capture_tb" == tb_rfmc_capture ]]; then
        rg -q '^CAPTURE_AXIS_TEST_PASS$' "$capture_tb.log"
    else
        rg -q '^RX_PACK_TEST_PASS$' "$capture_tb.log"
    fi
done
