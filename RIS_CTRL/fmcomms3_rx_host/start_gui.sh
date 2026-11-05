#!/usr/bin/env bash
set -euo pipefail
rx_gui_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$rx_gui_dir/runtime_env.sh"
exec /usr/bin/python3 -B "$rx_gui_dir/rx706_gui.py" "$@"
