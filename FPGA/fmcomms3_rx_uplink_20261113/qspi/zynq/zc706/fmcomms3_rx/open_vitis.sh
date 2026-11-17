#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec /home/yyz/vivado2020.2/main/Vitis/2020.2/bin/vitis -wait -workspace "$project_root/vitis_code" -eclipseargs --launcher.newInstance
