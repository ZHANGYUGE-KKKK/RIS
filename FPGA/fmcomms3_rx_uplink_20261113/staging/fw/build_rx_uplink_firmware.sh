#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
vitis=${RX_VITIS:-/home/wenhan/SOFTWARE/VIVADO2022.2/Vitis/2022.2}
export PATH="${RX_MAKE_BIN:-/home/wenhan/SOFTWARE/RIS-Validation/runtime/usr/bin}:$vitis/gnu/aarch32/lin/gcc-arm-none-eabi/bin:$PATH"
out=$root/reports/uplink
platform=$root/vitis_rx_uplink/rx_uplink_platform
domain=$platform/export/rx_uplink_platform/sw/rx_uplink_platform/standalone_domain
include=$domain/bspinclude/include
lib=$domain/bsplib/lib
if [[ ! -f $lib/liblwip4.a || ${1:-} == --rebuild-bsp ]]; then
    if [[ -z ${DISPLAY:-} && -S /tmp/.X11-unix/X0 ]]; then
        export DISPLAY=:0
        xauthority=/run/user/$(id -u)/gdm/Xauthority
        if [[ -r $xauthority ]]; then export XAUTHORITY=$xauthority; fi
    fi
    "$vitis/bin/xsct" -nodisp "$root/scripts/build_rx_uplink_platform.tcl" > "$out/vitis_platform.log" 2>&1
    grep -Fxq RX_UPLINK_BSP_OK "$out/vitis_platform.log"
fi
src=$root/vitis_code/key_ctrlll/src
build=$out/firmware_obj
mkdir -p "$build"
arch=(-mcpu=cortex-a9 -mfpu=vfpv3 -mfloat-abi=hard)
objects=()
for file in "$src"/*.c "$src"/ad_config/*.c "$src"/drivers/*.c; do
    relative=${file#"$src"/}
    object=$build/${relative//\//_}.o
    arm-none-eabi-gcc "${arch[@]}" -std=gnu11 -g3 -O2 -Wall -Wextra \
        -ffunction-sections -fdata-sections -I"$include" -iquote "$include/lwip" \
        -c "$file" -o "$object"
    objects+=("$object")
done
arm-none-eabi-gcc "${arch[@]}" -specs="$src/Xilinx.spec" -T "$src/lscript.ld" \
    -Wl,--gc-sections,--build-id=none,-Map,"$out/zc706_rx_uplink.map" \
    -o "$out/zc706_rx_uplink.elf.tmp" "${objects[@]}" -L"$lib" \
    -Wl,--start-group -llwip4 -lxil -lm -lgcc -lc -Wl,--end-group
mv -f "$out/zc706_rx_uplink.elf.tmp" "$out/zc706_rx_uplink.elf"
arm-none-eabi-size "$out/zc706_rx_uplink.elf"
if [[ -f $platform/hw/ps7_init.tcl ]]; then cp "$platform/hw/ps7_init.tcl" "$out/ps7_init.tcl"; fi
echo RX_UPLINK_FIRMWARE_OK
