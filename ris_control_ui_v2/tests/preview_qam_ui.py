"""Capture the new QAM pages, always offline and using temporary settings."""
from pathlib import Path
import sys
import tempfile
import time
import tkinter as tk

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from ris_gui import RisGui
from ris_qam256 import ORIENTATIONS
from preview_ui import capture


def main():
    base = Path(__file__).resolve().parents[1]
    destination = base / "preview"
    destination.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory() as directory:
        root = tk.Tk()
        app = RisGui(root, pattern_storage=Path(directory) / "patterns", mapping_storage=Path(directory) / "mappings")
        errors = []
        root.report_callback_exception = lambda *args: errors.append(args)
        app.mapping_page.load_path(base / "mappings/ris_mapping.json")
        app.open_qam()
        assert app.qam_page.load(app.qam_page.default_path)
        page = app.qam_page
        page.symbol.set("A5")
        page.slot.set("85")
        page.row.set("9")
        page.column.set("10")
        root.attributes("-topmost", True)
        def shot(name):
            root.update()
            time.sleep(.2)
            root.update()
            capture(root, destination / f"{name}.png")
            print(name, root.winfo_width(), root.winfo_height())
        shot("10_qam_preview")
        page.tabs.select(1)
        page.source.set("十六进制字节序列")
        shot("11_qam_parameters")
        page.tabs.select(2)
        shot("12_qam_compatibility")
        app.open_qam_settings()
        app.qam_orientation.set(ORIENTATIONS["identity"])
        app.qam_state1.set("驱动高")
        # Remain unconfirmed: this is a UI preview, not physical calibration.
        shot("13_qam_settings")
        app.open_qam()
        page.tabs.select(0)
        root.geometry("1180x760")
        shot("14_qam_compact")
        app.mapping_page.dirty = False
        app.pattern_page.may_discard = lambda: True
        app.close()
        assert not errors, errors


if __name__ == "__main__":
    main()
