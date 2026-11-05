#!/usr/bin/env bash
# Hardware build only. No cable connection, programming, firmware or flashing.
set -euo pipefail
ris_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ris_bin=${RIS_VIVADO_BIN:-/home/wenhan/SOFTWARE/VIVADO2022.2/Vivado/2022.2/bin}
cd "$ris_root"
mkdir -p build/qam_hardware reports/qam
sha256sum rtl/*.v rtl/*.sv constraints/* > reports/qam/source_sha256.txt
if [[ ! -f vivado_qam/ris_ctrl_unit.xpr ]]; then
    RIS_REPORT_DIR="$ris_root/reports/qam" "$ris_bin/vivado" -mode batch \
        -source scripts/create_project.tcl -log build/qam_hardware/create.log \
        -journal build/qam_hardware/create.jou
fi
"$ris_bin/vivado" -mode batch -source scripts/build_qam.tcl \
    -log build/qam_hardware/build.log -journal build/qam_hardware/build.jou \
    2>&1 | tee reports/qam/hardware_build.log
rg -q '^RIS_QAM_BUILD_PASS$' reports/qam/hardware_build.log
python3 scripts/record_build.py
