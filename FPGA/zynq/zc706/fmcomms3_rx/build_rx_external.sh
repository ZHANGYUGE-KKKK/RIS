#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export PATH="/home/yyz/vivado2020.2/main/Vitis/2020.2/gnu/aarch32/lin/gcc-arm-none-eabi/bin:/home/yyz/vivado2020.2/main/Vitis/2020.2/bin:$PATH"
make -C "$project_root/vitis_code/key_ctrlll/Debug" -j2 all
python3 "$project_root/scripts/stage_zc706_artifacts.py"
printf 'RX external-test ELF ready: %s/export/key_ctrlll.elf\n' "$project_root"
