#!/usr/bin/env bash
set -euo pipefail
ris_gui_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec /usr/bin/python3 "$ris_gui_dir/ris_gui.py" "$@"
