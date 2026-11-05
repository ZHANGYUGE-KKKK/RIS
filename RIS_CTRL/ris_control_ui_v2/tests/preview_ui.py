"""Capture only this Tk window on Linux/X11; never connect to a board."""
import ctypes as C
import ctypes.util
from pathlib import Path
import struct
import sys
import tempfile
import time
import tkinter as tk
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from ris_gui import RisGui


class XImage(C.Structure):
    _fields_ = [("width", C.c_int), ("height", C.c_int), ("xoffset", C.c_int), ("format", C.c_int),
                ("data", C.c_void_p), ("byte_order", C.c_int), ("bitmap_unit", C.c_int),
                ("bitmap_bit_order", C.c_int), ("bitmap_pad", C.c_int), ("depth", C.c_int),
                ("bytes_per_line", C.c_int), ("bits_per_pixel", C.c_int),
                ("red_mask", C.c_ulong), ("green_mask", C.c_ulong), ("blue_mask", C.c_ulong)]


def capture(root, path):
    x11 = C.CDLL(ctypes.util.find_library("X11"))
    x11.XOpenDisplay.argtypes, x11.XOpenDisplay.restype = [C.c_char_p], C.c_void_p
    x11.XGetImage.argtypes = [C.c_void_p, C.c_ulong, C.c_int, C.c_int, C.c_uint, C.c_uint, C.c_ulong, C.c_int]
    x11.XGetImage.restype = C.POINTER(XImage)
    x11.XDestroyImage.argtypes = [C.POINTER(XImage)]
    x11.XCloseDisplay.argtypes = [C.c_void_p]
    display = x11.XOpenDisplay(None)
    if not display:
        raise RuntimeError("No X11 display")
    width, height = root.winfo_width(), root.winfo_height()
    picture = x11.XGetImage(display, root.winfo_id(), 0, 0, width, height, C.c_ulong(-1).value, 2)
    if not picture:
        raise RuntimeError("Unable to capture this window")
    try:
        info = picture.contents
        if info.bits_per_pixel != 32 or info.byte_order != 0 or info.red_mask != 0xff0000:
            raise RuntimeError("Unsupported X11 pixel format")
        data = C.string_at(info.data, info.bytes_per_line * height)
        rows = []
        for y in range(height):
            raw = data[y * info.bytes_per_line:y * info.bytes_per_line + width * 4]
            rgb = bytearray(width * 3)
            rgb[0::3], rgb[1::3], rgb[2::3] = raw[2::4], raw[1::4], raw[0::4]
            rows.append(b"\0" + rgb)
        def chunk(kind, content):
            return struct.pack("!I", len(content)) + kind + content + struct.pack("!I", zlib.crc32(kind + content))
        path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack("!2I5B", width, height, 8, 2, 0, 0, 0)) +
                         chunk(b"IDAT", zlib.compress(b"".join(rows), 6)) + chunk(b"IEND", b""))
    finally:
        x11.XDestroyImage(picture)
        x11.XCloseDisplay(display)


def main():
    directory = Path(__file__).resolve().parents[1]
    output = directory / "preview"
    output.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory() as temporary:
        root = tk.Tk()
        app = RisGui(root, pattern_storage=Path(temporary) / "patterns", mapping_storage=Path(temporary) / "mappings")
        app.mapping_page.load_path(directory / "mappings" / "ris_mapping.json")
        root.attributes("-topmost", True)
        def shot(name):
            root.update()
            time.sleep(.2)
            root.update()
            capture(root, output / f"{name}.png")
            print(name, root.winfo_width(), root.winfo_height())
        shot("01_home")
        app.show_page("board")
        shot("02_board")
        app.show_chip_editor.set(True)
        app.toggle_chip_editor()
        shot("03_manual")
        app.show_page("mt")
        app.fast_value.set("100")
        app.fast_unit.set("k")
        app.mt_controls.load(directory / "matlab" / "mt_example.txt")
        shot("04_mt")
        app.show_page("patterns")
        shot("05_patterns")
        app.show_page("settings")
        shot("06_settings")
        app.open_mapping()
        shot("07_mapping")
        root.geometry("1180x760")
        shot("08_mapping_compact")
        app.show_page("board")
        shot("09_manual_compact")
        app.mapping_page.dirty = False
        app.pattern_page.may_discard = lambda: True
        app.close()


if __name__ == "__main__":
    main()
