"""Bit-identical test lowering for Icarus' unsupported packed-struct arrays.

Writes only the simulation build directory; authoritative Vivado RTL is intact.
"""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
text = (root / "rtl/ris_controller_core.sv").read_text()
fields = [("op", 8), ("flags", 2), ("id", 32), ("arg0", 32), ("arg1", 32),
          ("mask", 50), ("payload", 400), ("config_words", 352)]
assert sum(width for _, width in fields) == 908
assert "logic [31:0] id, arg0, arg1;" in text
assert "logic [351:0] config_words;" in text
text = text.replace("command_t commands [0:CMD_DEPTH-1];", "reg [907:0] commands [0:CMD_DEPTH-1];")
pattern = r"commands\[cmd_tail\]<='\{op:submitted_op,flags:submitted_flags,id:id_shadow,\s*arg0:arg0_shadow,arg1:arg1_shadow,mask:mask_shadow,\s*payload:frame_shadow,config_words:config_shadow\};"
text, count = re.subn(pattern, "commands[cmd_tail]<={submitted_op,submitted_flags,id_shadow,"
                     "arg0_shadow,arg1_shadow,mask_shadow,frame_shadow,config_shadow};", text)
assert count == 1
high = 907
for field, width in fields:
    low = high - width + 1
    text = re.sub(r"commands\[([^\]]+)\]\." + field + r"\[(\d+)\+:(\d+)\]",
                  lambda m: f"commands[{m[1]}][{low + int(m[2])}+:{m[3]}]", text)
    text = re.sub(r"commands\[([^\]]+)\]\." + field + r"\[(\d+)\]",
                  lambda m: f"commands[{m[1]}][{low + int(m[2])}]", text)
    text = re.sub(r"commands\[([^\]]+)\]\." + field + r"\b", rf"commands[\1][{high}:{low}]", text)
    high = low - 1
assert not re.search(r"commands\[[^\]]+\]\.", text)
destination = root / "build/simulation/ris_controller_core_icarus.sv"
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(text)
