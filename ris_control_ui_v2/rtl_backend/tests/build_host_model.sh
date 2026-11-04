#!/usr/bin/env bash
set -euo pipefail
ris_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ris_gcc=${RIS_HOST_GCC:-/home/wenhan/SOFTWARE/VIVADO2022.2/Vivado/2022.2/tps/lnx64/gcc-8.3.0/bin/gcc}
cd "$ris_root"
mkdir -p build/protocol
"$ris_gcc" -std=gnu99 -Wall -Wextra -Werror -O2 -DRIS_HOST_TEST -DRIS_FAST_TOGGLE -DRIS_MT_TABLE -DRIS_QAM_TABLE \
    -isystem /usr/include/x86_64-linux-gnu -B/usr/lib/x86_64-linux-gnu/ \
    -Itests/protocol_stubs -Isoftware -Isoftware/network software/ris_controller.c \
    software/network/ris_protocol.c tests/qam_model_server.c -o build/protocol/qam_model_server
"$ris_gcc" -std=gnu99 -Wall -Wextra -Werror -O2 \
    -isystem /usr/include/x86_64-linux-gnu -B/usr/lib/x86_64-linux-gnu/ \
    -Itests/protocol_stubs -Isoftware -Isoftware/network \
    software/network/ris_protocol.c tests/test_fast_protocol.c -o build/protocol/test_fast_protocol
build/protocol/test_fast_protocol
