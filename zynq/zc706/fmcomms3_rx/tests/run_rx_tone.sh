#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_build_dir=$(mktemp -d /tmp/zc706-rx-tone.XXXXXX)
trap 'rm -rf -- "$test_build_dir"' EXIT
"${CC:-gcc}" -std=c11 -Wall -Wextra -Werror -fsanitize=address,undefined -O1 -g \
    -I "$project_root/vitis_code/key_ctrlll/src/drivers" \
    "$project_root/tests/test_rx_tone.c" \
    "$project_root/vitis_code/key_ctrlll/src/drivers/rx_tone.c" \
    -lm -o "$test_build_dir/test_rx_tone"
"$test_build_dir/test_rx_tone"
