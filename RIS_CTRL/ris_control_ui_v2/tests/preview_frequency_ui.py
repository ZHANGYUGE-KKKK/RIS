"""Capture PWM controls and long header text offline; never access a board."""
from pathlib import Path
import sys
import tempfile
import time
import tkinter as tk

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from preview_ui import capture
from ris_gui import RisGui
from ris_mapping import RisMapping
from ris_qam256 import ORIENTATIONS

base = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as temp:
    root = tk.Tk()
    errors = []
    root.report_callback_exception = lambda *args: errors.append(args)
    app = RisGui(root, pattern_storage=Path(temp)/'patterns', mapping_storage=Path(temp)/'mappings')
    app.mapping_page.model = RisMapping.load(base/'mappings/ris_mapping.json')
    app.qam_orientation.set(ORIENTATIONS['identity'])
    app.qam_state1.set('驱动高'); app.qam_confirmed.set(True)
    prefix = Path(temp)/'prefix.txt'
    prefix.write_text('(25,0);\n(75,0);\n')
    root.attributes('-topmost', True)
    for order, name, slices64 in ((256, '21_qam256_frequency.png', False), (64, '22_qam64_frequency.png', False),
                                   (256, '24_qam256_64slice_frequency.png', True)):
        page = app.qam_page if order==256 else app.qam64_page
        assert page.load(page.default_path.parent/'ris_256qam_64slice_codebook' if slices64 else page.default_path)
        if slices64: page.pwm_frequency.set('160')
        app.open_qam(order); page.tabs.select(1)
        page.source.set('十六进制字节序列'); page.sequence.set('01 2A')
        page.phase_compensation.set(True)
        assert page.load_preamble(prefix)
        root.update(); time.sleep(.2); root.update()
        app.status_title.set(f'{order}QAM帧循环 · 含相偏补偿')
        app.status_detail.set(f'PWM {"19.53125" if order==256 and not slices64 else "160"} kHz · 前导10周期 · 相偏补偿 {"00 08 88 80" if order==256 else "00 04 24 20"} ×K3 · 正式4096符号×K3 · 包CRC 12345678')
        app.status_meta.set('离线显示示例 · 未连接实际板卡')
        root.update()
        capture(root, base/'preview'/name)
    root.geometry('1180x980'); root.update()
    assert page.load(page.default_path)
    root.update()
    capture(root, base/'preview'/'23_qam_header_narrow.png')
    print('FREQUENCY_UI_PREVIEW_PASS: offline only, both QAM modes and 1180px header')
    app.mapping_page.dirty = False
    app.close()
    assert not errors, errors
