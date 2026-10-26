"""Offline manual-control integration tests with the real Tk UI and worker."""
from pathlib import Path
import sys
import tempfile
import time
import tkinter as tk
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "host"))
from ris_gui import RisGui
from ris_mapping import RisMapping, probe_command


class Client:
    instances = 0
    commands = []

    def __init__(self, *_):
        Client.instances += 1
        Client.instance = self
        self.image = bytearray(50)
        self.image[49] = 0x81
        self.oe = True
        self.blink = 0
        self.reject = False

    def command(self, command):
        Client.commands.append(command)
        fields = command.split()
        ok = not self.reject
        if ok:
            if fields[0] == "BIT":
                chip, bit, high = map(int, fields[1:])
                self.image[chip] = (self.image[chip] & ~(1 << bit)) | (high << bit)
            elif fields[0] == "FRAME":
                self.image[:] = bytes.fromhex(fields[1])
            elif fields[0] == "ALL":
                self.image[:] = bytes([255 if fields[1] == "1" else 0]) * 50
            elif fields[0] in ("CHIP", "GROUP"):
                index, value = int(fields[1]), int(fields[2], 16)
                if fields[0] == "CHIP":
                    self.image[index] = value
                else:
                    self.image[index * 5:index * 5 + 5] = bytes([value]) * 5
            elif fields[0] == "OE":
                self.oe = fields[1] == "1"
            elif fields[0] == "BLINK":
                self.blink = int(fields[1])
            if fields[0] in ("BIT", "FRAME", "ALL", "CHIP", "GROUP"):
                self.oe, self.blink = True, 0
        return {"image": self.image.hex().upper(), "oe": self.oe, "ok": ok,
                "rc": 0 if ok else -1, "errors": 0 if ok else 1,
                "blink_ms": self.blink, "status": 194, "frames": len(Client.commands), "slots": 16}

    def close(self):
        pass


class ManualTests(unittest.TestCase):
    def setUp(self):
        Client.instances, Client.commands = 0, []
        self.mock = patch("ris_gui.RisClient", Client)
        self.mock.start()
        self.folder = tempfile.TemporaryDirectory()
        self.root = tk.Tk()
        self.gui = RisGui(self.root)
        self.page, self.manual = self.gui.mapping_page, self.gui.manual
        self.page.storage_dir = Path(self.folder.name)
        self.page.recovery_path = Path(self.folder.name) / "recovery.json"
        self.page.change(lambda model: [model.bind_wiring(fpc, port)
                                       for fpc, port in ((1, "T1"), (2, "T2"), (6, "B1"))])
        self.root.update()

    def tearDown(self):
        self.page.close(discard=True)
        self.gui.close()
        self.folder.cleanup()
        self.mock.stop()

    def wait(self, predicate):
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            self.root.update()
            if predicate():
                return
            time.sleep(.01)
        self.fail(self.gui.notice.get())

    def connect(self):
        self.gui.connect_button.invoke()
        self.wait(lambda: self.gui.connected and not self.gui.busy)

    def click_cell(self, row, column):
        canvas = self.manual.canvas
        x0, y0, pitch, gap = self.manual.topology.grid_geometry
        x = x0 + (column - .5) * pitch - canvas.canvasx(0)
        y = y0 + (row - .5) * pitch + (gap if row > 10 else 0) - canvas.canvasy(0)
        canvas.event_generate("<Button-1>", x=int(x), y=int(y))
        self.root.update()

    def test_control_click_is_selection_even_when_mapping_is_in_record_mode(self):
        self.page.record_mode.set(True)
        self.page.measured.set(True)
        self.page.auto_next.set(True)
        self.page.auto_test.set(True)
        before, history = self.page.model.document(), len(self.page.history)
        self.click_cell(1, 1)
        self.assertEqual(self.page.cell, (1, 1))
        self.assertEqual(self.page.selected_source(), (1, 1))
        self.assertEqual((self.manual.row.get(), self.manual.column.get()), ("1", "1"))
        for text in ("R01 C01", "U4.Q0", "芯片第2脚", "FPC第60针", "U4 第10针"):
            self.assertIn(text, self.page.selected_cell.get())
        for canvas in (self.manual.canvas, self.page.canvas):
            selected = canvas.find_withtag("selected_cell")
            self.assertEqual(len(selected), 1)
            self.assertIn("cell_box_r1_c1", canvas.gettags(selected[0]))
            self.assertEqual(canvas.itemcget(canvas.find_withtag("selected_row_label")[0], "text"), "01")
            self.assertEqual(canvas.itemcget(canvas.find_withtag("selected_column_label")[0], "text"), "01")
        self.assertEqual(self.page.model.document(), before)
        self.assertEqual(len(self.page.history), history)
        self.assertEqual(Client.commands, [])
        self.assertTrue(self.gui.tasks.empty())
        self.assertEqual(str(self.manual.high_button.cget("state")), "disabled")

    def test_locate_bottom_cell_and_mapping_page_selection_stay_synchronized(self):
        self.manual.row.set("20")
        self.manual.column.set("1")
        self.assertTrue(self.manual.locate())
        self.assertEqual(self.page.selected_source(), (6, 31))
        self.assertIn("U32.Q6", self.page.selected_cell.get())
        self.gui.open_mapping()
        self.page.fpc.set("2")
        self.page.channel.set("1")
        self.page.choose_channel()
        self.gui.show_page("control")
        self.root.update()
        self.assertEqual(self.page.cell, (1, 5))
        self.assertEqual((self.manual.row.get(), self.manual.column.get()), ("1", "5"))
        self.assertIs(self.manual.topology.state, self.page.topology.state)
        self.assertEqual(Client.commands, [])

    def test_bit_buttons_preserve_other_outputs_and_share_one_tcp_worker(self):
        self.connect()
        self.manual.select_cell(1, 1)
        original = bytes.fromhex(self.gui.latest["image"])
        self.manual.high_button.invoke()
        self.assertTrue(self.gui.busy)
        self.manual.low_button.invoke()  # Busy UI must not queue a second write.
        self.wait(lambda: not self.gui.busy)
        expected = bytearray(original)
        expected[0] |= 1
        self.assertEqual(bytes.fromhex(self.gui.latest["image"]), bytes(expected))
        self.assertEqual([cmd for cmd in Client.commands if cmd != "STATUS"], ["BIT 0 0 1"])
        self.assertIn("高 · 1", self.manual.level.get())
        self.manual.low_button.invoke()
        self.wait(lambda: not self.gui.busy)
        self.assertEqual(bytes.fromhex(self.gui.latest["image"]), original)
        self.assertIn("低 · 0", self.manual.level.get())
        self.assertEqual(Client.instances, 1)
        self.assertEqual(self.page.model.count(verified=True), 0)

    def test_one_cell_probe_clears_other_399_and_requires_acknowledgment(self):
        self.connect()
        self.manual.select_cell(1, 1)
        self.manual.test_button.invoke()
        self.assertIsNone(self.page.probed)
        self.wait(lambda: not self.gui.busy)
        self.assertEqual(Client.commands[-1], probe_command(1, 1))
        image = bytes.fromhex(self.gui.latest["image"])
        self.assertEqual(image[0], 1)
        self.assertEqual(sum(value.bit_count() for value in image), 1)
        self.assertEqual(self.page.probed, (1, 1))
        self.assertEqual(self.page.model.count(verified=True), 0)
        self.manual.zero_button.invoke()
        self.wait(lambda: not self.gui.busy)
        self.assertEqual(self.gui.latest["image"], "00" * 50)

    def test_unmapped_and_unverified_manual_cells_cannot_be_driven(self):
        self.connect()
        for cell in ((20, 20), (1, 1)):
            if cell == (1, 1):
                self.page.change(lambda model: model.assign(1, 1, 1, 1))
            self.manual.select_cell(*cell)
            for button in (self.manual.high_button, self.manual.low_button, self.manual.test_button):
                self.assertEqual(str(button.cget("state")), "disabled")
                button.invoke()
            self.manual.control(1)
            self.manual.test_cell()
        self.assertEqual([cmd for cmd in Client.commands if cmd != "STATUS"], [])
        self.page.change(lambda model: model.assign(1, 1, 1, 1, verified=True))
        self.assertEqual(str(self.manual.test_button.cget("state")), "normal")

    def test_invalid_coordinates_and_typing_do_not_change_selection_or_write(self):
        self.manual.select_cell(1, 1)
        for row, column in (("0", "1"), ("1", "21"), ("abc", "1"), ("", "")):
            self.manual.row.set(row)
            self.manual.column.set(column)
            self.assertFalse(self.manual.locate())
            self.assertEqual(self.page.cell, (1, 1))
        self.manual.row.set("12")
        self.page.update_state()  # Polling must not overwrite an unfinished edit.
        self.assertEqual(self.manual.row.get(), "12")
        self.assertEqual(Client.commands, [])

    def test_reload_and_undo_replace_shared_model_without_stale_control_target(self):
        self.manual.select_cell(1, 1)
        replacement = RisMapping()
        replacement.bind_wiring(9, "T1")
        path = Path(self.folder.name) / "different.json"
        replacement.save(path)
        self.assertTrue(self.page.load_path(path))
        self.assertFalse(self.manual.can_control())  # Former FPC1 no longer mapped.
        self.manual.select_cell(1, 1)
        self.assertEqual(self.page.selected_source(), (9, 1))
        self.assertIn("U44.Q0", self.page.selected_cell.get())
        self.page.undo()
        self.manual.select_cell(1, 1)
        self.assertEqual(self.page.selected_source(), (1, 1))
        self.assertEqual(Client.commands, [])

    def test_small_window_scrolls_to_located_cell_and_step_only_selects(self):
        self.root.geometry("1180x810")
        self.root.update()
        self.manual.select_cell(20, 1)
        self.root.update()
        canvas = self.manual.canvas
        x0, y0, pitch, gap = self.manual.topology.grid_geometry
        y = y0 + 19.5 * pitch + gap - canvas.canvasy(0)
        self.assertGreater(canvas.canvasy(0), 0)
        self.assertGreater(y, 0)
        self.assertLess(y, canvas.winfo_height())
        self.manual.step(1)
        self.assertEqual(self.page.cell, (20, 2))
        self.manual.step(-1)
        self.assertEqual(self.page.cell, (20, 1))
        self.gui.show_chip_editor.set(True)
        self.gui.toggle_chip_editor()
        self.root.update()
        self.assertTrue(self.gui.editor.winfo_ismapped())
        self.assertEqual(Client.commands, [])

    def test_high_impedance_and_disconnect_do_not_claim_a_measured_voltage(self):
        self.connect()
        self.manual.select_cell(1, 1)
        self.gui.command("OE 0")
        self.wait(lambda: not self.gui.busy)
        self.assertIn("高阻", self.manual.level.get())
        self.gui.disconnect_button.invoke()
        self.wait(lambda: not self.gui.busy)
        self.assertIn("尚未确认", self.manual.level.get())
        self.assertEqual(str(self.manual.test_button.cget("state")), "disabled")

    def test_rejected_probe_does_not_show_a_successful_output_or_measurement(self):
        self.connect()
        self.manual.select_cell(1, 1)
        Client.instance.reject = True
        self.manual.test_button.invoke()
        self.wait(lambda: not self.gui.busy)
        self.assertIsNone(self.page.probed)
        self.assertEqual(self.page.model.count(verified=True), 0)
        self.assertIn("输出未确认", self.page.notice.get())
        self.assertIn("板端报错", self.manual.level.get())
        self.assertEqual(bytes.fromhex(self.gui.latest["image"])[0], 0)

    def test_measured_top_and_bottom_row_endpoints_send_correct_physical_bits(self):
        self.connect()
        # Fixed hardware endpoints, independent of the generator under test.
        for row, column, source, chip, bit in ((1, 1, (1, 1), 0, 0),
                                               (10, 1, (1, 10), 1, 1),
                                               (11, 1, (6, 40), 29, 7),
                                               (20, 1, (6, 31), 28, 6)):
            self.manual.select_cell(row, column)
            self.assertEqual(self.page.selected_source(), source)
            before = len(Client.commands)
            self.manual.test_button.invoke()
            self.wait(lambda: not self.gui.busy)
            expected = bytearray(50)
            expected[chip] = 1 << bit
            self.assertEqual(self.gui.latest["image"], expected.hex().upper())
            self.assertEqual(Client.commands[before], "FRAME " + expected.hex().upper())


if __name__ == "__main__":
    unittest.main()
