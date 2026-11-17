"""Uniform MT prefix timing, preset portability and the existing output gate."""
from pathlib import Path
import sys
import tempfile
import tkinter as tk
from tkinter import ttk
import unittest
from unittest.mock import patch

BASE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BASE))

from ris_gui import RisGui
from ris_mt import compile_mt, parse_mt
from ris_mt_gui import MTControls
from ris_presets import action_from_document, document_for_action
from ris_qam256_gui import UNIFORM_TYPE
from test_ris_mt import output
import test_console_gui as console


class LocalHost:
    _prepare_action = RisGui._prepare_action
    stage_mt = RisGui.stage_mt
    stage_mt_stop = RisGui.stage_mt_stop

    def __init__(self, root):
        self.root = root
        self.current_page = "mt"
        self.mt_type = tk.StringVar(value=UNIFORM_TYPE)
        self.mt_action = tk.StringVar(value="play")
        self.fast_value = tk.StringVar(value="1")
        self.fast_unit = tk.StringVar(value="M")
        self.notice = tk.StringVar()
        self.mt_uploading = False
        self.mt_controls = MTControls(self, ttk.Frame(root))

    def refresh_pending(self):
        pass


class PreambleTests(unittest.TestCase):
    def setUp(self):
        self.root = tk.Tk()
        self.addCleanup(self.root.destroy)
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.host = LocalHost(self.root)
        self.controls = self.host.mt_controls

    def write(self, name, text):
        path = self.directory / name
        path.write_text(text, encoding="utf-8")
        return path

    def test_continuous_periods_once_and_across_repeated_frame_boundaries(self):
        body = parse_mt("(50,80);\n(30,0);")
        self.assertTrue(self.controls.load(self.write("body.mt", "(50,80);\n(30,0);")))
        self.assertFalse(self.controls.preamble_enabled.get())
        self.assertEqual(self.controls.plan(), compile_mt(body, "1", "M"))
        self.assertTrue(self.controls.load_preamble(self.write("prefix.mt", "(0,75);\n(50,50);\n(25,25);")))
        prefix = parse_mt("(0,75);\n(50,50);\n(25,25);")
        for loop in (False, True):
            self.controls.start(loop)
            plan = self.host._prepare_action().payload
            self.assertEqual(plan.rows, prefix + body)
            self.assertEqual(plan.period, 300)
            # Independent phase oracle checks every tick, including the prefix,
            # wrapped body pulses and four complete frame boundaries.
            for time in range(len(plan.rows) * plan.period * 4):
                cycle, phase = divmod(time, plan.period)
                m, delay = plan.rows[cycle % len(plan.rows)]
                expected = ((phase - int(delay)*3) % 300 < int(m)*3
                            if loop or cycle < len(plan.rows) else False)
                self.assertEqual(output(plan, time), expected, (loop, time))
            restored = action_from_document(document_for_action(self.host._prepare_action()))
            self.assertEqual(restored.payload, plan)

    def test_invalid_file_preserves_prefix_and_capacity_or_edge_checks_reject(self):
        good = self.write("good.mt", "(25,0);\n(75,0);")
        self.assertTrue(self.controls.load_preamble(good))
        saved = self.controls.preamble_rows
        for text in ("(95,10);", "(25,0);\n" * 11, "", "(101,0);", "bad"):
            self.assertFalse(self.controls.load_preamble(self.write("bad.mt", text)))
            self.assertEqual(self.controls.preamble_rows, saved)
            self.assertEqual(self.controls.preamble_path, good)
        self.controls.preamble_enabled.set(False)
        self.controls.preamble_rows = ()
        self.controls.preamble_enabled.set(True)
        with self.assertRaisesRegex(ValueError, "先加载"):
            self.host._prepare_action()
        self.controls.load_preamble(self.write("ten.mt", "(25,0);\n" * 10))
        self.controls.rows = parse_mt("(50,0);\n" * 502)
        self.assertEqual(len(self.controls.plan().rows), 512)
        self.controls.rows += parse_mt("(50,0);")
        with self.assertRaisesRegex(ValueError, "512"):
            self.controls.plan()
        self.controls.rows = None
        self.host.fast_value.set("5")
        with self.assertRaisesRegex(ValueError, "100 ns"):
            self.controls.plan()

    def test_default_waveform_and_prefix_disable_restore_original_output(self):
        original = self.host._prepare_action()
        self.assertEqual(original.kind, "command")
        self.assertEqual(original.payload, "FASTTICKS 150")
        self.assertTrue(self.controls.load_preamble(self.write("prefix.mt", "(25,0);\n(75,0);")))
        self.assertTrue(self.controls.once_button.instate(["!disabled"]))
        action = self.host._prepare_action()
        self.assertEqual(action.kind, "mt")
        self.assertEqual(action.payload.rows, parse_mt("(25,0);\n(75,0);\n(50,0);"))
        self.controls.preamble_checkbox.invoke()
        self.assertEqual(self.host._prepare_action(), original)
        self.assertTrue(self.controls.once_button.instate(["disabled"]))
        # Disabling a loaded prefix retains it for the next configuration.
        self.controls.preamble_checkbox.invoke()
        self.assertEqual(self.host._prepare_action(), action)


class OutputGateTests(unittest.TestCase):
    tearDown = console.ConsoleTests.tearDown
    wait = console.ConsoleTests.wait
    connect = console.ConsoleTests.connect
    writes = console.ConsoleTests.writes
    apply = console.ConsoleTests.apply

    def setUp(self):
        # A visible test window avoids withdrawn Tk redraw stalls on this X11.
        with patch.object(tk.Tk, "withdraw", lambda root: None):
            console.ConsoleTests.setUp(self)

    def test_file_buttons_checkbox_and_edits_only_apply_via_total_button(self):
        self.connect()
        self.app.show_page("mt")
        self.app.fast_value.set("1")
        self.app.fast_unit.set("M")
        controls = self.app.mt_controls
        body = self.directory / "body.mt"
        body.write_text("(50,80);\n(30,0);")
        prefix = self.directory / "prefix.mt"
        prefix.write_text("(25,25);\n(50,50);")
        self.assertTrue(controls.load(body))
        with patch("ris_mt_gui.filedialog.askopenfilename", return_value=str(prefix)):
            controls.preamble_load_button.invoke()
        self.assertEqual(self.writes(), [])
        self.assertIn("含前导码2周期", self.app.pending_text.get())
        for loop, button in ((False, controls.once_button), (True, controls.loop_button)):
            before = self.writes()
            button.invoke()
            plan = controls.plan()
            self.assertEqual(plan.loop, loop)
            self.assertEqual(self.writes(), before)
            self.apply()
            self.assertEqual(self.writes()[len(before):], list(plan.commands()))
        before = self.writes()
        applied = self.app.applied_action.payload
        controls.preamble_checkbox.invoke()
        self.app.fast_value.set("500")
        self.app.fast_unit.set("k")
        self.assertEqual(self.writes(), before)
        self.assertEqual(self.app.applied_action.payload, applied)
        self.apply()
        self.assertEqual(self.app.applied_action.payload.rows, parse_mt(body.read_text()))


if __name__ == "__main__":
    unittest.main()
