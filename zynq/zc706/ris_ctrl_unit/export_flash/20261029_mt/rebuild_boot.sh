#!/usr/bin/env bash
# Regenerate/inspect the image only; does not connect to or program hardware.
set -euo pipefail
ris_package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ris_bootgen=${RIS_BOOTGEN:-/home/wenhan/SOFTWARE/VIVADO2022.2/Vitis/2022.2/bin/bootgen}
cd "$ris_package_dir"
"$ris_bootgen" -arch zynq -image BOOT.bif -o BOOT.bin -w on
"$ris_bootgen" -arch zynq -read BOOT.bin
python3 -B verify_zynq_boot.py .
sha256sum -c SHA256SUMS
