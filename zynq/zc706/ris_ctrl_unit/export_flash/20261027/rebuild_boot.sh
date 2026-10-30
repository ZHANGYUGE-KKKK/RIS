#!/usr/bin/env bash
set -euo pipefail
ris_package_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ris_package_dir"
exec /home/wenhan/SOFTWARE/VIVADO2022.2/Vitis/2022.2/bin/bootgen -arch zynq -image BOOT.bif -o BOOT.bin -w on
