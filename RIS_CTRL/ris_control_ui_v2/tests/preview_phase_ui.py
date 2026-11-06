"""Render the phase reference checkbox offline; no board connection."""
from pathlib import Path
import sys,tempfile,time,tkinter as tk
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from ris_gui import RisGui
from preview_ui import capture
base=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as d:
    root=tk.Tk();errors=[]
    root.report_callback_exception=lambda *args:errors.append(args)
    app=RisGui(root,pattern_storage=Path(d)/"patterns",mapping_storage=Path(d)/"mappings")
    prefix=Path(d)/"prefix.txt";prefix.write_text("(25,0);\n(75,0);\n")
    for order,name in ((256,"19_qam256_phase.png"),(64,"20_qam64_phase.png")):
        page=app.qam_page if order==256 else app.qam64_page
        assert page.load(page.default_path)
        app.open_qam(order);page.tabs.select(1)
        page.source.set("十六进制字节序列");page.sequence.set("01 2A");page.repeats.set("2")
        assert page.load_preamble(prefix)
        page.phase_compensation.set(True)
        root.attributes("-topmost",True);root.update();time.sleep(.2);root.update()
        capture(root,base/"preview"/name)
    app.mapping_page.dirty=False;app.pattern_page.may_discard=lambda:True
    app.close();assert not errors,errors
    print("PHASE_UI_PREVIEW_PASS: offline only, both QAM modes")
