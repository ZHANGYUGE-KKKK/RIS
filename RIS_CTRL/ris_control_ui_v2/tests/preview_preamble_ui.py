"""Render the preamble configuration using a separate offline GUI instance."""
from pathlib import Path
import sys
import tempfile
import time
import tkinter as tk

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from ris_gui import RisGui
from preview_ui import capture

base = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as temporary:
    root = tk.Tk()
    errors = []
    root.report_callback_exception = lambda *args: errors.append(args)
    app = RisGui(root, pattern_storage=Path(temporary)/"patterns", mapping_storage=Path(temporary)/"mappings")
    app.open_qam()
    page = app.qam_page
    assert page.load(page.default_path)
    assert page.load_preamble(base/"examples/qam_preamble_mt.txt")
    page.source.set("十六进制字节序列"); page.sequence.set("3F A5 00")
    page.timing_mode.set("低速数字核线（明确改速）")
    page.tabs.select(1)
    root.attributes("-topmost", True)
    root.update(); time.sleep(.2); root.update()
    capture(root, base/"preview/15_qam_preamble.png")
    canvas = page.preamble_table.master.master.master.master
    assert isinstance(canvas, tk.Canvas)
    canvas.yview_moveto(1)
    root.update(); time.sleep(.2); root.update()
    capture(root, base/"preview/16_qam_preamble_details.png")
    app.mapping_page.dirty = False
    app.pattern_page.may_discard = lambda: True
    app.close()
    assert not errors, errors
    print("PASS offline preamble UI render; no board connection")
