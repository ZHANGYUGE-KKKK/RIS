"""Complete MT previews, scroll reachability, late waveform accuracy; no board."""
from pathlib import Path
import sys
import tkinter as tk
import unittest
from unittest.mock import patch

BASE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BASE))

from ris_mt import compile_mt, parse_mt
from ris_mt_preview import MTPreview
import test_console_gui as console


class PreviewTests(unittest.TestCase):
    def setUp(self):
        self.root = tk.Tk()
        self.root.geometry("1000x700")
        self.addCleanup(self.root.destroy)
        self.errors = []
        self.root.report_callback_exception = lambda *args: self.errors.append(args)

    def tearDown(self):
        self.assertEqual(self.errors, [])

    def test_full_512_rows_waveform_matches_late_pulses_and_scrolls_to_last_cycle(self):
        rows = parse_mt("\n".join(f"({(i%5)*25},{(i%4)*25});" for i in range(512)))
        plan = compile_mt(rows, "1", "M")
        view = MTPreview(self.root, plan)
        self.root.update()
        self.assertEqual(len(view.table.get_children()), 512)
        self.assertEqual(view.table.item("512", "values")[0], "512")
        self.assertEqual(len(view.waveform.find_withtag("cycle_label")), 513)
        runs = [view.waveform.coords(item) for item in view.waveform.find_withtag("wave")]
        for cycle in (0, 10, 31, 100, 254, 510, 511):
            m, delay = map(int, rows[cycle])
            for phase in (0, 23, 80, 149, 280, 299):
                x = view.MARGIN + (cycle + phase/300) * view.period_width
                horizontal = next(line for line in runs if line[0] <= x < line[-2])
                expected = int((phase - delay*3) % 300 < m*3)
                self.assertEqual(horizontal[-1], 110 - 75*expected, (cycle, phase))
        self.assertAlmostEqual(max(line[-2] for line in runs), view.MARGIN + 512*view.period_width)
        view.waveform.xview_moveto(1)
        view.table.yview_moveto(1)
        self.root.update()
        self.assertAlmostEqual(view.waveform.xview()[1], 1)
        self.assertTrue(view.table.bbox("512"))
        self.assertIn("512", view.visible_text.get())
        view.geometry("720x480")
        self.root.update()
        view.table.yview_moveto(1)
        view.waveform.xview_moveto(1)
        self.root.update()
        self.assertTrue(view.table.bbox("512"))
        self.assertLessEqual(sum(view.table.column(c, "width") for c in view.table['columns']), view.table.winfo_width())
        self.assertLessEqual(view.help_label.winfo_y()+view.help_label.winfo_height(), view.winfo_height())
        self.assertGreaterEqual(view.waveform.canvasx(view.waveform.winfo_width()), view.MARGIN + 512*view.period_width)
        before = view.waveform.xview()[0]
        view.waveform.event_generate("<Button-4>")
        self.root.update()
        self.assertLess(view.waveform.xview()[0], before)
        view.table.selection_set("410")
        view.table.see("410")
        self.root.update()
        selected_x = view.MARGIN + 409*view.period_width
        self.assertLessEqual(view.waveform.canvasx(0), selected_x)
        self.assertGreater(view.waveform.canvasx(view.waveform.winfo_width()), selected_x)
        self.assertEqual(view.waveform.itemcget(view.highlight, "state"), "normal")

    def test_short_tables_and_once_final_low_are_fully_visible(self):
        for text, loop in (("(100,0);", False), ("(0,0);", True), ("(25,0);\n(50,80);", True)):
            plan = compile_mt(parse_mt(text), "1", "M", loop)
            view = MTPreview(self.root, plan)
            self.root.update()
            self.assertEqual(len(view.table.get_children()), len(plan.rows))
            self.assertEqual(view.waveform.xview(), (0, 1))
            if not loop:
                last = view.waveform.coords(view.waveform.find_withtag("wave")[-1])
                self.assertEqual(last[-1], 110)
            view.destroy()


class PreviewEntryTests(unittest.TestCase):
    tearDown = console.ConsoleTests.tearDown
    writes = console.ConsoleTests.writes

    def setUp(self):
        with patch.object(tk.Tk, "withdraw", lambda root: None):
            console.ConsoleTests.setUp(self)

    def test_uniform_prefix_and_both_qam_prefix_tables_are_complete_and_offline(self):
        self.app.show_page("mt")
        self.app.fast_value.set("100")
        self.app.fast_unit.set("k")
        body = self.directory / "body.mt"
        body.write_text("(50,80);\n" * 40)
        prefix = self.directory / "prefix.mt"
        prefix.write_text("(25,25);\n" * 10)
        controls = self.app.mt_controls
        self.assertTrue(controls.load(body))
        self.assertTrue(controls.load_preamble(prefix))
        before = self.app._prepare_action()
        view = controls.preview()
        self.root.update()
        self.assertEqual(len(view.table.get_children()), 50)
        self.assertEqual(view.plan.rows[:10], parse_mt(prefix.read_text()))
        self.assertEqual(view.plan.rows[10:], parse_mt(body.read_text()))
        controls.preamble_enabled.set(False)
        self.app.fast_value.set("50")
        self.assertEqual(view.plan, before.payload)
        view.destroy()
        for order in (64, 256):
            self.app.open_qam(order)
            page = self.app.active_qam_page()
            page.tabs.select(1)
            self.assertTrue(page.load_preamble(prefix))
            self.root.update()
            table = page.preamble_table
            self.assertEqual(len(table.get_children()), 10)
            self.assertEqual(table.item(table.get_children()[0], "values")[1:3], ("25", "25"))
            table.yview_moveto(1)
            self.root.update()
            last = table.get_children()[-1]
            self.assertEqual(table.item(last, "values")[0], "10")
            self.assertTrue(table.bbox(last))
        self.assertEqual(self.writes(), [])
        self.assertEqual(console.Board.instances, 0)


if __name__ == "__main__":
    unittest.main()
