#!/usr/bin/env bash
set -euo pipefail
test_root=$(cd -- "$(dirname -- "$0")/.." && pwd)
tool_root=/home/yyz/vivado2020.2/main/Vitis/2020.2
"$tool_root/bin/xsct" "$test_root/scripts/build_bsp.tcl" > "$test_root/reports/build_bsp.log" 2>&1
bsp_root="$test_root/vitis/bsp/ps7_cortexa9_0"
compiler="$tool_root/gnu/aarch32/lin/gcc-arm-none-eabi/bin/arm-none-eabi-gcc"
"$compiler" -mcpu=cortex-a9 -mfpu=vfpv3 -mfloat-abi=hard -O2 -g3 -Wall -Wextra -Werror \
    -I"$bsp_root/include" -L"$bsp_root/lib" -specs="$test_root/software/Xilinx.spec" \
    -Wl,-T,"$test_root/software/lscript.ld" -Wl,-Map,"$test_root/reports/ddr2g_test.map" \
    "$test_root/software/main.c" -Wl,--start-group -lxil -lgcc -lc -Wl,--end-group \
    -o "$test_root/export/ddr2g_test.elf"
"${compiler%gcc}size" "$test_root/export/ddr2g_test.elf"
echo DDR2G_SOFTWARE_BUILD_PASS
