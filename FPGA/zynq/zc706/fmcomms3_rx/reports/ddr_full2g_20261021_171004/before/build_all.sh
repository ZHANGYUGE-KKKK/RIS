#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
vivado_bin=/home/yyz/vivado2020.2/main/Vivado/2020.2/bin/vivado
xsct_bin=/home/yyz/vivado2020.2/main/Vitis/2020.2/bin/xsct
cd "$project_root"
"$vivado_bin" -mode batch -source scripts/build_zc706.tcl > reports/build.log 2>&1
"$vivado_bin" -mode batch -source scripts/audit_zc706.tcl > reports/board_audit.log 2>&1
"$xsct_bin" scripts/create_zc706_platform.tcl > reports/vitis_platform.log 2>&1
"$xsct_bin" scripts/create_zc706_application.tcl > reports/vitis_application.log 2>&1
python3 scripts/verify_2g_sources.py
python3 scripts/stage_zc706_artifacts.py
printf 'ZC706 BIT/LTX/XSA/ELF ready in %s/export\n' "$project_root"
