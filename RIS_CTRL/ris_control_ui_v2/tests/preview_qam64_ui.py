"""Render separate offline 64QAM windows; never connect to a board."""
from pathlib import Path
import sys,tempfile,time,tkinter as tk
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from ris_gui import RisGui
from preview_ui import capture
base=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as d:
    root=tk.Tk();errors=[]
    root.report_callback_exception=lambda *args:errors.append(args)
    app=RisGui(root,pattern_storage=Path(d)/'patterns',mapping_storage=Path(d)/'mappings')
    app.open_qam(64);p=app.qam64_page
    assert p.load(p.default_path)
    p.source.set('十六进制字节序列');p.sequence.set('00 1B 3F')
    assert p.load_preamble(base/'examples/qam_preamble_mt.txt')
    root.attributes('-topmost',True);root.update();time.sleep(.2);root.update()
    capture(root,base/'preview/17_qam64_preview.png')
    p.tabs.select(1);root.update();time.sleep(.2);root.update()
    capture(root,base/'preview/18_qam64_parameters.png')
    app.mapping_page.dirty=False;app.pattern_page.may_discard=lambda:True
    app.close();assert not errors,errors
    print('QAM64_UI_PREVIEW_PASS: offline only')
