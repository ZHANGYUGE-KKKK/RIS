"""Offline Tk/worker integration tests for the pattern editor and playback."""
from pathlib import Path
import sys
import tempfile
import time
import tkinter as tk
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "host"))
from ris_gui import RisGui
from ris_mapping import PORTS, RisMapping
from ris_patterns import MODES, Pattern, PatternLibrary, compile_frame


class Firmware:
    instances = 0
    commands = []
    reject_next = False

    def __init__(self, *_):
        Firmware.instances += 1
        self.image = bytes(50)

    def command(self, command):
        Firmware.commands.append(command)
        fields = command.split()
        ok = not Firmware.reject_next
        Firmware.reject_next = False
        if ok:
            if fields[0] == "FRAME":
                self.image = bytes.fromhex(fields[1])
            elif fields[0] == "BIT":
                chip, bit, value = map(int, fields[1:])
                frame = bytearray(self.image)
                frame[chip] = (frame[chip] & ~(1 << bit)) | (value << bit)
                self.image = bytes(frame)
            elif fields[0] == "ALL":
                self.image = bytes([255 if fields[1] == "1" else 0]) * 50
        return {"ok": ok, "rc": 0 if ok else -1, "errors": 0 if ok else 1,
                "oe": True, "blink_ms": 0, "status": 194, "frames": len(Firmware.commands),
                "image": self.image.hex().upper(), "slots": 16}

    def close(self):
        pass


class PatternGuiTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.mock = patch("ris_gui.RisClient", Firmware)
        self.mock.start()
        Firmware.instances, Firmware.commands, Firmware.reject_next = 0, [], False
        self.root = tk.Tk()
        self.gui = RisGui(self.root, pattern_storage=Path(self.folder.name) / "patterns")
        self.page = self.gui.pattern_page
        self.mapping = self.gui.mapping_page
        self.mapping.storage_dir = Path(self.folder.name)
        self.mapping.recovery_path = Path(self.folder.name) / "mapping.json"
        model = RisMapping()
        for fpc, port in enumerate(PORTS, 1):
            model.bind_wiring(fpc, port)
        self.mapping.model = model
        self.mapping.refresh()
        self.gui.show_page("patterns")
        self.root.update()

    def tearDown(self):
        if not self.gui.closed:
            self.page.may_discard = lambda: True
            self.mapping.close(discard=True)
            self.gui.close()
        self.folder.cleanup()
        self.mock.stop()

    def wait(self, predicate, timeout=3):
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            self.root.update()
            if predicate():
                return
            time.sleep(.005)
        self.fail(self.gui.notice.get() + " / " + self.page.play_status.get())

    def settle(self, seconds=.25):
        end = time.monotonic() + seconds
        while time.monotonic() < end:
            self.root.update()
            time.sleep(.005)

    def connect(self):
        self.gui.connect_button.invoke()
        self.wait(lambda: self.gui.connected and not self.gui.busy)

    def playlist(self, mode="once", count=3):
        self.page.duration.set("100")
        for key in list(self.page.library.patterns)[:count]:
            self.page._activate(key)
            self.page.add_step()
        self.page.mode.set(MODES[mode])
        self.page.set_mode()

    def writes(self):
        return [c for c in Firmware.commands if c != "STATUS"]

    def test_edit_row_column_and_save_is_offline_and_does_not_revert_to_old_selection(self):
        with patch("ris_pattern_gui.messagebox.askyesnocancel", side_effect=AssertionError("unexpected prompt")):
            self.page.new()
            self.page.name.set("行7列20")
            self.page.row.set("7")
            self.page.set_line("row", 1)
            self.page.column.set("20")
            self.page.set_line("column", 1)
            self.root.update()
            self.assertEqual(self.page.pattern.count(), 39)
            self.assertEqual(self.page.pattern.rows[6], "1" * 20)
            self.assertEqual(self.page.name.get(), "行7列20")
            self.assertTrue(self.page.dirty())
            self.gui.mapping_shortcut("undo")
            self.assertEqual(self.page.pattern.count(), 20)
            self.gui.mapping_shortcut("save")
        loaded = PatternLibrary.load(self.page.path)
        self.assertEqual(loaded.patterns[self.page.draft_id]["name"], "行7列20")
        self.assertEqual(Pattern(loaded.patterns[self.page.draft_id]["rows"]).count(), 20)
        self.assertEqual(self.writes(), [])
        self.assertEqual(Firmware.instances, 0)

    def test_canvas_drag_toggle_once_per_cell_and_undo_whole_stroke(self):
        self.page.brush.set("toggle")
        canvas = self.page.canvas
        x0, y0, pitch, gap = self.page.topology.grid_geometry
        def point(row, col):
            return {"x": int(x0 + (col - .5) * pitch - canvas.canvasx(0)),
                    "y": int(y0 + (row - .5) * pitch + (gap if row > 10 else 0) - canvas.canvasy(0))}
        canvas.event_generate("<Button-1>", **point(1, 1))
        canvas.event_generate("<B1-Motion>", **point(1, 1))
        canvas.event_generate("<B1-Motion>", **point(1, 2))
        canvas.event_generate("<ButtonRelease-1>", **point(1, 2))
        self.root.update()
        self.assertEqual(self.page.pattern.count(), 2)
        self.assertEqual(self.page.pattern.rows[0][:2], "11")
        self.page.undo()
        self.assertEqual(self.page.pattern.count(), 0)
        self.assertEqual(self.writes(), [])

    def test_apply_draft_sends_correct_frame_and_read_mirror_is_local(self):
        self.connect()
        self.page.edit(Pattern().line("row", 1, 1))
        self.page.apply_button.invoke()
        self.wait(lambda: not self.gui.busy)
        expected = compile_frame(self.page.pattern, self.mapping.model)
        self.assertEqual(self.writes(), ["FRAME " + expected.hex().upper()])
        self.assertIn("已确认下发", self.page.notice.get())
        before = list(self.writes())
        self.page.edit(Pattern())
        self.page.read_board()
        self.assertEqual(self.page.pattern.rows[0], "1" * 20)
        self.assertEqual(self.writes(), before)

    def test_playlist_order_duration_import_export_and_no_autostart(self):
        self.playlist("pingpong")
        keys = [s["pattern"] for s in self.page.library.playlist]
        self.page.steps.selection_set("2")
        self.page.move_step(-1)
        self.assertEqual([s["pattern"] for s in self.page.library.playlist], [keys[0], keys[2], keys[1]])
        self.page.duration.set("250")
        self.page.set_duration(all_steps=True)
        self.assertEqual([s["dwell_ms"] for s in self.page.library.playlist], [250] * 3)
        exported = Path(self.folder.name) / "export.json"
        with patch("ris_pattern_gui.filedialog.asksaveasfilename", return_value=str(exported)):
            self.page.export_library()
        document = self.page.library.document()
        self.page.remove_step()
        self.assertTrue(self.page.load_library(exported))
        self.assertEqual(self.page.library.document(), document)
        self.assertFalse(self.page.player.active)
        self.assertEqual(self.writes(), [])
        invalid = Path(self.folder.name) / "wrong.json"
        self.mapping.model.save(invalid)
        self.assertFalse(self.page.load_library(invalid))
        self.assertEqual(self.page.library.document(), document)

    def test_play_once_uses_one_shared_client_and_tracks_confirmed_preview(self):
        self.playlist()
        self.connect()
        expected = ["FRAME " + compile_frame(Pattern(self.page.library.patterns[s["pattern"]]["rows"]),
                                              self.mapping.model).hex().upper() for s in self.page.library.playlist]
        self.page.start_button.invoke()
        self.wait(lambda: not self.page.player.active and not self.gui.busy)
        self.assertEqual(self.writes(), expected)
        self.assertEqual(self.page.pattern.count(), 200)
        self.assertIn("播放完成", self.page.play_status.get())
        self.assertEqual(Firmware.instances, 1)
        self.assertEqual(self.gui.latest["image"], expected[-1].split()[1])

    def test_tab_switch_continues_playback_but_manual_control_stops_next_frame(self):
        self.playlist("loop", count=2)
        self.connect()
        self.page.start()
        self.wait(lambda: len(self.writes()) >= 1 and not self.gui.busy)
        self.gui.view_menu.invoke(0)
        self.root.update()
        self.assertEqual(self.gui.view.get(), "control")
        self.wait(lambda: len(self.writes()) >= 2 and not self.gui.busy)
        self.assertTrue(self.page.player.active)
        self.gui.command("BIT 0 0 1")
        self.wait(lambda: not self.gui.busy)
        self.assertFalse(self.page.player.active)
        count = len(self.writes())
        self.settle(.3)
        self.assertEqual(len(self.writes()), count)
        self.assertEqual(self.writes()[-1], "BIT 0 0 1")

    def test_mapping_change_and_rejected_ack_stop_without_further_output(self):
        self.playlist("loop", count=2)
        self.connect()
        Firmware.reject_next = True
        self.page.start()
        self.wait(lambda: not self.gui.busy)
        self.assertFalse(self.page.player.active)
        self.assertIn("未确认", self.page.play_status.get())
        self.page.start()
        self.wait(lambda: self.page.player.active and not self.gui.busy)
        self.mapping.change(lambda model: model.unbind(10))
        self.assertFalse(self.page.player.active)
        count = len(self.writes())
        self.settle(.3)
        self.assertEqual(len(self.writes()), count)
        self.assertEqual(str(self.page.apply_button.cget("state")), "disabled")

    def test_close_cancel_keeps_editor_and_small_window_can_scroll_to_controls(self):
        self.page.edit(Pattern().cell(20, 20, 1))
        with patch("ris_pattern_gui.messagebox.askyesnocancel", return_value=None):
            self.gui.close()
        self.assertFalse(self.gui.closed)
        self.assertTrue(self.mapping.alive)
        self.root.geometry("1180x810")
        self.page.tabs.select(1)
        self.root.update()
        canvas = self.page.steps.master.master
        self.assertIsInstance(canvas, tk.Canvas)
        canvas.yview_moveto(1)
        self.root.update()
        y = self.page.step_button.winfo_rooty() - canvas.winfo_rooty()
        self.assertGreater(y, 0)
        self.assertLess(y + self.page.step_button.winfo_height(), canvas.winfo_height())


if __name__ == "__main__":
    unittest.main()
