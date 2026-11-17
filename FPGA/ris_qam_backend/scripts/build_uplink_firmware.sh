#!/usr/bin/env bash
# Separate SGMII sender firmware/BSP; no cable connection or programming.
set -euo pipefail
ris_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ris_xsct=${RIS_XSCT:-/home/wenhan/SOFTWARE/VIVADO2022.2/Vitis/2022.2/bin/xsct}
ris_toolchain=/home/wenhan/SOFTWARE/VIVADO2022.2/Vitis/2022.2/gnu/aarch32/lin/gcc-arm-none-eabi/bin
export PATH="${RIS_MAKE_BIN:-/home/wenhan/SOFTWARE/RIS-Validation/runtime/usr/bin}:$ris_toolchain:$PATH"
# Vitis 2022.2's Eclipse backend needs an X display even with xsct -nodisp.
# Reuse the user's existing session only when SSH supplied no DISPLAY.
if [[ -z ${DISPLAY:-} && -S /tmp/.X11-unix/X0 ]]; then
    export DISPLAY=:0
    ris_xauthority=/run/user/$(id -u)/gdm/Xauthority
    if [[ -r $ris_xauthority ]]; then export XAUTHORITY=$ris_xauthority; fi
fi
cd "$ris_root"
mkdir -p reports/pl_eth_sgmii_20261113/firmware
"$ris_xsct" -nodisp scripts/build_uplink_firmware.tcl 2>&1 | tee reports/pl_eth_sgmii_20261113/firmware/build.log
python3 - <<'PY'
from pathlib import Path
import os
p = Path('reports/pl_eth_sgmii_20261113/firmware/build.log')
marker = 'RIS_UPLINK_PLATFORM_BUILD_PASS' if os.environ.get('RIS_UPLINK_PLATFORM_ONLY') == '1' else 'RIS_UPLINK_FIRMWARE_BUILD_PASS'
if marker not in p.read_text():
    raise SystemExit('Firmware build did not report success')
PY
