#!/usr/bin/env bash
# Reuse the already installed, isolated Tk runtime; install nothing.
ris_runtime_dir="${RIS_GUI_RUNTIME:-/home/wenhan/SOFTWARE/RIS-GUI/runtime}"
if [[ -d "$ris_runtime_dir/usr/lib/python3.14/tkinter" ]]; then
  export PYTHONPATH="$ris_runtime_dir/usr/lib/python3.14:$ris_runtime_dir/usr/lib/python3.14/lib-dynload${PYTHONPATH:+:$PYTHONPATH}"
  export LD_LIBRARY_PATH="$ris_runtime_dir/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  export TK_LIBRARY="$ris_runtime_dir/usr/share/tcltk/tk8.6"
fi
export PYTHONDONTWRITEBYTECODE=1
