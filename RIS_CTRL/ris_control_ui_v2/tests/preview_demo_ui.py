"""Offline render of ten demo slots. Never opens a device connection."""
from pathlib import Path
import sys
import tempfile
import time
import tkinter as tk
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from ris_gui import RisGui
from preview_ui import capture
base=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as temp:
    root=tk.Tk();errors=[]
    root.report_callback_exception=lambda *args:errors.append(args)
    app=RisGui(root,pattern_storage=Path(temp)/'patterns',mapping_storage=Path(temp)/'mappings')
    root.attributes('-topmost',True)
    app.show_page('demo')
    for i,path in enumerate(sorted((base/'examples/demo_presets').glob('*.json'))):
        assert app.demo_page.load(i,path)
    app.demo_page.select(3)
    for geometry,name in (('1460x980','25_demo_mode.png'),('1180x760','26_demo_mode_small.png')):
        root.geometry(geometry);root.update();time.sleep(.2);root.update()
        capture(root,base/'preview'/name)
    app.mapping_page.dirty=False
    app.pattern_page.may_discard=lambda:True
    app.close()
    assert not errors,errors
    print('DEMO_PREVIEW_PASS: offline, ten rows at 1460x980 and 1180x760')
