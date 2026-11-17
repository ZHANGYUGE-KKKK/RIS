#!/usr/bin/env bash
# Isolated hardware build and exports only; never programs or flashes a board.
set -euo pipefail
ris_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ris_vivado=${RIS_VIVADO_BIN:-/home/wenhan/SOFTWARE/VIVADO2022.2/Vivado/2022.2/bin}/vivado
ris_build=${RIS_UPLINK_BUILD_DIR:-$ris_root/build/pl_eth_sgmii_20261113}
ris_report=${RIS_UPLINK_REPORT_DIR:-$ris_root/reports/pl_eth_sgmii_20261113/hardware}
ris_export=${RIS_UPLINK_EXPORT_DIR:-$ris_root/export_uplink}
mkdir -p "$ris_build" "$ris_report" "$ris_export"
cd "$ris_build"
if [[ ! -f "$ris_build/project/ris_ctrl_unit.xpr" ]]; then
    RIS_PROJECT_DIR="$ris_build/project" RIS_REPORT_DIR="$ris_report/rebuild" \
        "$ris_vivado" -mode batch -notrace -source "$ris_root/scripts/create_project.tcl" \
        -log "$ris_build/create.log" -journal "$ris_build/create.jou"
fi
sha256sum "$ris_root"/rtl/*.v "$ris_root"/rtl/*.sv "$ris_root"/constraints/* "$ris_root/scripts/create_project.tcl" \
    "$ris_root/scripts/configure_pl_eth_bd.tcl" \
    "$ris_build/project/ris_ctrl_unit.srcs/sources_1/bd/ris_system/ris_system.bd" \
    > "$ris_report/source_sha256.txt"
RIS_UPLINK_BUILD_DIR="$ris_build" RIS_UPLINK_REPORT_DIR="$ris_report" \
RIS_UPLINK_EXPORT_DIR="$ris_export" \
    "$ris_vivado" -mode batch -notrace -source "$ris_root/scripts/build_uplink.tcl" \
    -log "$ris_build/build.log" -journal "$ris_build/build.jou" \
    2>&1 | tee "$ris_report/hardware_build.log"
python3 - "$ris_report/hardware_build.log" "$ris_export" "$ris_report/source_sha256.txt" <<'PY_BUILD'
from pathlib import Path
import hashlib,json,sys,zipfile
log=Path(sys.argv[1]);out=Path(sys.argv[2])
if 'RIS_UPLINK_BUILD_PASS' not in log.read_text().splitlines():
    raise SystemExit('Uplink build completion marker missing')
# write_hw_platform writes a fresh BIT header; deliver its exact embedded BIT.
with zipfile.ZipFile(out/'ris_ctrl_unit.xsa') as archive:
    bits=[n for n in archive.namelist() if n.endswith('.bit')]
    if len(bits)!=1:
        raise SystemExit('Expected one BIT in the final hardware platform')
    (out/'ris_ctrl_unit.bit').write_bytes(archive.read(bits[0]))
    handoff={n:hashlib.sha256(archive.read(n)).hexdigest() for n in ['ris_system.hwh','ps7_init.tcl','ps7_init.c','ps7_init.h']}
manifest={p.name:{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in out.glob('*') if p.suffix in ['.bit','.xsa']}
manifest.update(handoff_sha256=handoff,source_manifest=sys.argv[3],exact_bit_xsa_pair=True)
(out/'hardware_manifest.json').write_text(json.dumps(manifest,indent=2)+chr(10))
PY_BUILD
