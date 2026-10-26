#!/usr/bin/env python3
"""Exercise real Tk buttons against the board. Run under xvfb-run if desired."""
from pathlib import Path
import subprocess
import sys
import time
import tkinter as tk

root_dir = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root_dir / "host"))
from ris_gui import RisGui


def main():
    root = tk.Tk()
    gui = RisGui(root)

    def wait(predicate):
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            root.update()
            if predicate():
                return
            time.sleep(0.01)
        raise AssertionError(gui.notice.get())

    def button(text):
        matches = [b for b in gui.controls if b.cget("text") == text]
        assert len(matches) == 1, text
        return matches[0]

    def invoke(text, predicate):
        wait(lambda: not gui.busy)
        button(text).invoke()
        wait(lambda: not gui.busy and predicate())
        print("PASS Tk:", text)

    try:
        gui.connect_button.invoke()
        wait(lambda: gui.connected and not gui.busy)
        invoke("400 路全高 · 1", lambda: gui.latest["image"] == "FF" * 50)
        invoke("400 路全低 · 0", lambda: gui.latest["image"] == "00" * 50)
        gui.chip.set("2")
        gui.select_chip()
        gui.bits[0].set(1)
        gui.bits[7].set(1)
        gui.bits_to_hex()
        expected = (b"\x00\x81" + bytes(48)).hex().upper()
        invoke("写入所选片", lambda: gui.latest["image"] == expected)
        gui.hex_value.set("AA")
        expected = (bytes([0xAA]) * 5 + bytes(45)).hex().upper()
        invoke("写入所选 5 片组", lambda: gui.latest["image"] == expected)
        invoke("禁能输出 · 高阻", lambda: not gui.latest["oe"])
        invoke("使能输出", lambda: gui.latest["oe"])
        gui.period.set("200")
        invoke("启动切换", lambda: gui.latest["blink_ms"] == 200)
        frames = gui.latest["frames"]
        wait(lambda: gui.latest["frames"] >= frames + 2)
        invoke("停止切换并保持", lambda: gui.latest["blink_ms"] == 0)
        invoke("400 路全低 · 0", lambda: gui.latest["image"] == "00" * 50)
        root.update()
        screenshot = root_dir / "reports/network/gui.png"
        subprocess.run(["import", "-window", str(root.winfo_id()), str(screenshot)], check=True)
        print("RIS_NETWORK_GUI_TEST_PASS: real Tk/worker/TCP/lwIP/AXI; final all LOW")
    finally:
        if gui.connected:
            wait(lambda: not gui.busy)
            gui.command("ALL 0")
            wait(lambda: not gui.busy)
            gui.disconnect()
            wait(lambda: not gui.busy)
        gui.close()


if __name__ == "__main__":
    main()
