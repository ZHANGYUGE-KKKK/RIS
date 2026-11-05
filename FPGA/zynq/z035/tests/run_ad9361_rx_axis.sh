#!/usr/bin/env bash
set -euo pipefail
# Current config915 receiver regression. The previous runner is backed up in
# backups/before_rx_axis_rewrite_20261016/run_ad9361_rx_axis.sh.
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec "$test_dir/run_ad9361_rx_axis_rewrite.sh" "$@"
