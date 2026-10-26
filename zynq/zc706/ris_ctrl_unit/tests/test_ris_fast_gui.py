"""Real Tk/worker tests for capability negotiation and programmable hardware frequency."""
from pathlib import Path
import sys
import tempfile
import time
import tkinter as tk
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "host"))
from ris_gui import RisGui
from test_ris_manual_control import Client


class FastClient(Client):
    supported = True

    def __init__(self, *args):
        super().__init__(*args)
        self.fast = 0
        self.ticks = 0

    def command(self, command):
        if command.startswith("FASTTICKS "):
            self.ticks = int(command.split()[1])
            self.fast = {150: 1, 50: 3, 30: 5}.get(self.ticks, 0)
            self.blink = 0
        elif command.split()[0] not in ("STATUS", "OE"):
            self.fast = 0
            self.ticks = 0
        reply = super().command(command)
        reply.update(fast_supported=self.supported, fast_mhz=self.fast, fast_edges=10000, fast_variable=self.supported, fast_ticks=self.ticks)
        return reply


class FastGuiTests(unittest.TestCase):
    def setUp(self):
        self.mock = patch("ris_gui.RisClient", FastClient)
        self.mock.start()
        FastClient.supported = True
        Client.commands = []
        self.temp = tempfile.TemporaryDirectory()
        self.root = tk.Tk()
        self.gui = RisGui(self.root, pattern_storage=self.temp.name)
        self.gui.mapping_page.storage_dir = Path(self.temp.name)
        self.gui.mapping_page.recovery_path = Path(self.temp.name) / "mapping.json"
        self.gui.mapping_page.change(lambda model: model.bind_wiring(1, "T1"))
        self.gui.mapping_page.channel.set("1")
        self.gui.mapping_page.choose_channel()
        self.root.update()

    def tearDown(self):
        self.gui.mapping_page.close(discard=True)
        self.gui.close()
        self.temp.cleanup()
        self.mock.stop()

    def wait(self, check):
        limit = time.monotonic() + 3
        while time.monotonic() < limit:
            self.root.update()
            if check():
                return
            time.sleep(.005)
        self.fail(self.gui.notice.get())

    def connect(self):
        self.gui.connect()
        self.wait(lambda: self.gui.connected and not self.gui.busy)

    def test_frequency_entry_units_preview_apply_and_stop(self):
        self.connect()
        for value, unit, ticks, shown in (("1", "M", 150, "1 MHz"), ("2400", "k", 63, "2.38095238 MHz"), ("0.005", "G", 30, "5 MHz"), ("125", "k", 1200, "125 kHz")):
            before = list(Client.commands)
            self.gui.fast_value.set(value)
            self.gui.fast_unit.set(unit)
            self.root.update()
            self.assertEqual(Client.commands, before)  # Editing never writes.
            self.assertIn(shown, self.gui.fast_notice.get())
            self.gui.fast_start.invoke()
            self.wait(lambda: not self.gui.busy)
            self.assertEqual(Client.commands[-1], f"FASTTICKS {ticks}")
            self.assertIn(shown, self.gui.state.get())
            self.assertIn("瞬时电平", self.gui.mapping_page.output_state.get())
            self.assertFalse(self.gui.mapping_page.has_probe())
        self.gui.command("STOP")
        self.wait(lambda: not self.gui.busy)
        self.assertEqual(self.gui.latest["fast_ticks"], 0)
        self.assertIn("静态保持", self.gui.state.get())

    def test_invalid_frequency_does_not_change_output(self):
        self.connect()
        self.gui.start_fast()
        self.wait(lambda: not self.gui.busy)
        before = list(Client.commands)
        for text, unit in (("5.01", "M"), ("1", "G"), ("0", "Hz"), (".9", "Hz"), ("NaN", "M"), ("-3", "k"), ("1e6", "Hz"), ("", "M")):
            self.gui.fast_value.set(text)
            self.gui.fast_unit.set(unit)
            self.assertFalse(self.gui.start_fast())
            self.assertEqual(Client.commands, before)
            self.assertEqual(self.gui.latest["fast_ticks"], 30)

    def test_old_firmware_disables_fast_buttons_without_write(self):
        FastClient.supported = False
        self.connect()
        self.assertEqual(str(self.gui.fast_start["state"]), "disabled")
        for button in self.gui.fast_buttons[:-1]:
            self.assertEqual(str(button["state"]), "normal")
        before = list(Client.commands)
        self.assertFalse(self.gui.start_fast())
        self.assertEqual(Client.commands, before)

    def test_manual_frame_takes_over_from_fast_mode(self):
        self.connect()
        self.gui.start_fast()
        self.wait(lambda: not self.gui.busy)
        self.gui.command("ALL 0")
        self.wait(lambda: not self.gui.busy)
        self.assertEqual(self.gui.latest["fast_mhz"], 0)
        self.assertEqual(self.gui.latest["image"], "00" * 50)
