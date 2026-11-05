#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT
sources=("$root/tests/test_network_core.c" "$root/vitis_code/key_ctrlll/src/drivers/capture_format.c" "$root/vitis_code/key_ctrlll/src/drivers/capture_store.c" "$root/vitis_code/key_ctrlll/src/drivers/rx_control.c")
flags=(-std=c11 -D_GNU_SOURCE -Wall -Wextra -Werror -I"$root/tests/network_stubs" -I"$root/vitis_code/key_ctrlll/src/drivers")
if [[ -n "${RX706_TEST_PROFILE:-}" ]]; then
    flags+=("-DRX_RF_PROFILE=$RX706_TEST_PROFILE")
fi
gcc "${flags[@]}" -O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer -DTEST_MAIN "${sources[@]}" -o "$build/core"
"$build/core"
gcc "${flags[@]}" -O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer "$root/tests/test_mig_mapping.c" "$root/vitis_code/key_ctrlll/src/drivers/mig_ddr.c" -o "$build/mapping"
"$build/mapping"
gcc "${flags[@]}" -O2 -fPIC -shared "${sources[@]}" -o "$build/libcapture_test.so"
PYTHONDONTWRITEBYTECODE=1 python3 "$root/tests/test_rx706.py" "$build/libcapture_test.so"
if [[ "${RX706_GUI_TESTS:-0}" == "1" ]]; then
    PYTHONDONTWRITEBYTECODE=1 xvfb-run -a -s '-screen 0 1440x1080x24' python3 "$root/tests/test_rx706_gui.py" "$build/libcapture_test.so"
fi
