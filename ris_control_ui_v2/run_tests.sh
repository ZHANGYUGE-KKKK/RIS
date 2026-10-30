#!/usr/bin/env bash
set -euo pipefail
ris_console_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$ris_console_dir/runtime_env.sh"
cd "$ris_console_dir"
exec /usr/bin/python3 -B -m unittest discover -s tests -v "$@"
