#!/usr/bin/env bash
set -euo pipefail
ris_app_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export RIS_GUI_RUNTIME="$ris_app_dir/runtime"
exec /home/wenhan/PROJECTS/RIS/ris_control_ui_v2/start_gui.sh "$@"
