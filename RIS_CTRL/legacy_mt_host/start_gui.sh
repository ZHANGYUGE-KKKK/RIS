#!/usr/bin/env bash
set -euo pipefail
ris_gui_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$ris_gui_dir/runtime_env.sh"
exec /usr/bin/python3 -B "$ris_gui_dir/ris_gui.py" "$@"
