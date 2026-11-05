#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
vivado_root=${VIVADO_ROOT:-/home/yyz/vivado2020.2/main/Vivado/2020.2}
build=${BUILD_DIR:-$(mktemp -d /tmp/mig_cpu_window.XXXXXX)}
mkdir -p "$build"
cd "$build"
"$vivado_root/bin/xvlog" --sv "$root/PZ_UART.srcs/sources_1/new/mig_cpu_window.v" "$root/tests/tb_mig_cpu_window.sv" > compile.log 2>&1
"$vivado_root/bin/xelab" tb_mig_cpu_window --debug typical --mt 2 -s window_tb > elaborate.log 2>&1
"$vivado_root/bin/xsim" window_tb -runall -log simulate.log > console.log 2>&1
cat console.log
if rg -q 'ERROR:|FATAL:' console.log; then exit 1; fi
rg -q 'PASS: AXI3' console.log
