#!/usr/bin/env bash
# Independent read-back only. Both erase and program are explicitly disabled.
set -euo pipefail
ris_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ris_package="$ris_root/export_flash/20261105_qam64"
exec /home/wenhan/SOFTWARE/VIVADO2022.2/Vitis/2022.2/bin/program_flash \
  -f "$ris_package/BOOT.bin" -offset 0 -flash_type qspi-x8-dual_parallel \
  -fsbl "$ris_package/fsbl.elf" -no_erase -no_program -verify \
  -target_name jsn-JTAG-HS3-210299372306-4ba00477-0 \
  -url tcp:127.0.0.1:3121
