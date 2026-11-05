#!/usr/bin/env bash
set -euo pipefail
test_root=$(cd -- "$(dirname -- "$0")/.." && pwd)
vivado_tool=/home/yyz/vivado2020.2/main/Vivado/2020.2/bin/vivado
xsct_tool=/home/yyz/vivado2020.2/main/Vitis/2020.2/bin/xsct
cd "$test_root"
mkdir -p reports export
for step in create_project simulate build_hardware inspect_routed; do
    step_log=$step
    if [[ $step == simulate ]]; then step_log=simulation; fi
    "$vivado_tool" -mode batch -notrace -nojournal -nolog -source "scripts/$step.tcl" > "reports/$step_log.log" 2>&1
done
bash scripts/build_software.sh > reports/build_software.log 2>&1
"$xsct_tool" scripts/prepare_vitis.tcl > reports/prepare_vitis.log 2>&1
python3 scripts/verify_release.py > reports/verify_release.log
echo "DDR2G_OFFLINE_BUILD_READY: export/ddr2g_test.{bit,xsa,elf}; no board connection performed"
