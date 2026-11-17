#!/usr/bin/env bash
set -euo pipefail

# No behavioural stubs: use the installed Vivado UNISIM and XPM libraries.
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
project_dir=$(cd -- "$test_dir/.." && pwd)
vivado_root=${VIVADO_ROOT:-/home/yyz/vivado2020.2/main/Vivado/2020.2}
build_dir=${BUILD_DIR:-$(mktemp -d /tmp/ad9361_rx_axis_rewrite.XXXXXX)}
mkdir -p "$build_dir"
cd "$build_dir"
printf 'Simulation artifacts: %s\n' "$build_dir"

adi_dir="$project_dir/PZ_UART.srcs/sources_1/adi_hdl/library"
sources=(
  "$vivado_root/data/verilog/src/glbl.v"
  "$vivado_root/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv"
  "$vivado_root/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv"
  "$vivado_root/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv"
)
for module in up_axi up_adc_common up_adc_channel up_delay_cntrl up_xfer_cntrl \
              up_xfer_status up_clock_mon ad_rst ad_pnmon ad_datafmt ad_iqcor \
              ad_pps_receiver; do
  sources+=("$adi_dir/common/$module.v")
done
for module in ad_mul ad_dcfilter; do
  sources+=("$adi_dir/xilinx/common/$module.v")
done
for module in axi_ad9361_rx axi_ad9361_rx_channel axi_ad9361_rx_pnmon; do
  sources+=("$adi_dir/axi_ad9361/$module.v")
done
sources+=("$project_dir/PZ_UART.srcs/sources_1/new/ad9361_rx_axis.v")
sources+=("$test_dir/tb_ad9361_rx_axis_rewrite.sv")
verilog_sources=()
systemverilog_sources=()
for source_file in "${sources[@]}"; do
  if [[ "$source_file" == *.sv ]]; then
    systemverilog_sources+=("$source_file")
  else
    verilog_sources+=("$source_file")
  fi
done
"$vivado_root/bin/xvlog" "${verilog_sources[@]}" >compile.log 2>&1 || {
  cat compile.log
  exit 1
}
"$vivado_root/bin/xvlog" --sv "${systemverilog_sources[@]}" >>compile.log 2>&1 || {
  cat compile.log
  exit 1
}

run_case() {
  local packet_samples=$1 clock_invert=$2
  local snapshot="rx_rewrite_p${packet_samples}_c${clock_invert}"
  "$vivado_root/bin/xelab" tb_ad9361_rx_axis_rewrite glbl \
    -L unisims_ver -L unimacro_ver -L secureip --debug typical --mt 2 \
    --generic_top "PACKET_SAMPLES=$packet_samples" \
    --generic_top "RX_CLOCK_INVERT=$clock_invert" -s "$snapshot" \
    >"${snapshot}_elaborate.log" 2>&1 || {
      cat "${snapshot}_elaborate.log"
      exit 1
    }
  "$vivado_root/bin/xsim" "$snapshot" -runall -log "${snapshot}_simulate.log" \
    >"${snapshot}_console.log" 2>&1 || {
      cat "${snapshot}_console.log"
      exit 1
    }
  cat "${snapshot}_console.log"
  if grep -Eiq 'ERROR:|FATAL:|assertion.*fail' "${snapshot}_console.log"; then
    printf 'Simulator reported an error for %s\n' "$snapshot" >&2
    exit 1
  fi
  if ! grep -q "PASS rewrite PACKET_SAMPLES=$packet_samples CLOCK_INVERT=$clock_invert" \
      "${snapshot}_console.log"; then
    printf 'Missing PASS result for %s\n' "$snapshot" >&2
    exit 1
  fi
}

run_case 17 0
run_case 1 0
run_case 17 1
run_case 4096 0
printf 'PASS all rewrite simulation configurations\n'
