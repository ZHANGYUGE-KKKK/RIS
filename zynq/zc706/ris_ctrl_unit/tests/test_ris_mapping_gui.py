"""Offline Tk tests. The controller stub acknowledges only when the test asks."""
from pathlib import Path
import json
import sys
import tempfile
import time
import tkinter as tk
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "host"))
from ris_mapping_gui import MappingPage


class Controller:
    def __init__(self, root):
        self.root = root
        self.connected = False
        self.busy = False
        self.host = tk.StringVar(value="192.168.1.11")
        self.port = tk.StringVar(value="7060")
        self.latest = {"image": "00" * 50, "oe": True, "errors": 0, "blink_ms": 0, "ok": True}
        self.commands = []
        self.callback = None

    def connect(self):
        self.connected = True

    def command(self, command, callback=None):
        if not self.connected or self.busy:
            return False
        self.busy = True
        self.commands.append(command)
        self.callback = callback
        return True

    def ack(self, window, ok=True):
        command = self.commands[-1]
        self.latest["image"] = command.split()[1] if command.startswith("FRAME ") else "00" * 50
        self.latest["ok"] = ok
        self.busy = False
        window.update_state()
        callback, self.callback = self.callback, None
        if callback:
            callback(self.latest, None)


class GuiTests(unittest.TestCase):
    def setUp(self):
        self.root = tk.Tk()
        self.folder = tempfile.TemporaryDirectory()
        self.controller = Controller(self.root)
        self.window = MappingPage(self.controller, self.root, self.folder.name)
        self.window.auto_next.set(False)
        self.root.update()

    def tearDown(self):
        self.window.close(discard=True)
        self.root.destroy()
        self.folder.cleanup()

    def bind(self):
        self.window.port.set("T1 · 上端 1")
        self.window.bind_port()
        self.assertEqual(self.window.model.ports, {1: "T1"})

    def test_offline_edit_undo_recovery_and_bad_load(self):
        self.bind()
        self.assertTrue(self.window.record(1, 1))
        self.assertEqual(self.window.model.count(), 40)
        self.assertEqual(self.window.model.count(verified=True), 0)
        self.assertEqual(self.controller.commands, [])
        self.assertTrue(self.window.recovery_path.exists())
        self.window.undo()
        self.assertEqual(self.window.model.channels[1, 1]["basis"], "wiring")
        self.assertEqual(self.window.model.count(), 40)
        self.assertEqual(self.window.model.ports, {1: "T1"})
        before = self.window.model.document()
        bad = Path(self.folder.name) / "invalid.json"
        bad.write_text('{"version":1}')
        self.assertFalse(self.window.load_path(bad))
        self.assertEqual(self.window.model.document(), before)
        self.window.path = Path(self.folder.name) / "saved.json"
        self.assertTrue(self.window.save())
        self.assertFalse(self.window.dirty)

    def test_probe_ack_required_and_verified_control(self):
        self.bind()
        self.controller.connected = True
        self.window.measured.set(True)
        self.assertFalse(self.window.record(1, 1))
        self.window.test_channel()
        self.assertEqual(len(self.controller.commands), 1)
        self.assertIsNone(self.window.probed)
        self.assertFalse(self.window.record(1, 1))
        self.controller.ack(self.window)
        self.assertEqual(self.window.probed, (1, 1))
        self.assertTrue(self.window.record(1, 1))
        self.assertTrue(self.window.model.channels[1, 1]["verified"])
        self.window.cell = 1, 1
        self.window.control_cell(0)
        self.assertEqual(self.controller.commands[-1], "BIT 0 0 0")
        self.controller.ack(self.window)
        self.assertIsNone(self.window.probed)

    def test_auto_next_does_not_send_without_follow_option(self):
        self.bind()
        self.controller.connected = True
        self.window.auto_next.set(True)
        self.window.record(1, 1)
        self.assertEqual(self.window.channel.get(), "2")
        self.assertEqual(self.controller.commands, [])
        self.window.record_mode.set(False)
        x0, y0, pitch, gap = self.window.grid_geometry
        self.assertEqual(self.window.hit_cell(x0 + pitch / 2, y0 + pitch / 2), (1, 1))
        self.assertIsNone(self.window.hit_cell(x0 + pitch / 2, y0 + 10 * pitch + gap / 2))
        self.assertEqual(self.window.hit_cell(x0 + 19.5 * pitch, y0 + 19.5 * pitch + gap), (20, 20))

    def test_failed_ack_does_not_create_verified_record(self):
        self.bind()
        self.controller.connected = True
        self.window.measured.set(True)
        self.window.test_channel()
        self.controller.ack(self.window, ok=False)
        self.assertIsNone(self.window.probed)
        self.assertFalse(self.window.record(1, 1))
        self.assertEqual(self.window.model.count(), 40)

    def test_group_probe_is_not_a_single_channel_proof(self):
        self.bind()
        self.controller.connected = True
        self.window.test_fpc()
        self.controller.ack(self.window)
        self.assertIsNone(self.window.probed)
        self.assertFalse(self.window.has_probe())
        self.assertIn("40路高", self.window.output_state.get())

    def test_undo_after_load_restores_original_filename(self):
        self.bind()
        original = Path(self.folder.name) / "original.json"
        second = Path(self.folder.name) / "second.json"
        self.window.path = original
        self.window.model.save(second)
        self.window.load_path(second)
        self.assertEqual(self.window.path, second)
        self.window.undo()
        self.assertEqual(self.window.path, original)

    def test_generated_cell_click_shows_physical_pins_and_controls_single_bit(self):
        self.bind()
        self.window.record_mode.set(False)
        x0, y0, pitch, _gap = self.window.grid_geometry
        self.window.canvas.event_generate("<Button-1>", x=int(x0 + pitch / 2), y=int(y0 + pitch / 2))
        self.root.update()
        self.assertEqual(self.window.selected_source(), (1, 1))
        detail = self.window.selected_cell.get()
        for text in ("R01 C01", "U4.Q0", "芯片第2脚", "FPC第60针", "U4 第10针", "接线表·未实测"):
            self.assertIn(text, detail)
        self.assertEqual(self.controller.commands, [])
        self.controller.connected = True
        self.window.update_state()
        self.window.control_cell(1)
        self.assertEqual(self.controller.commands, ["BIT 0 0 1"])
        self.assertEqual(self.window.model.count(verified=True), 0)
        self.controller.ack(self.window)
        self.window.model.assign(1, 1, 1, 1, False)
        self.window.control_cell(0)
        self.assertEqual(self.controller.commands, ["BIT 0 0 1"])

    def test_old_bindings_can_be_generated_and_undone_without_network_commands(self):
        self.window.model.bind(6, "B1")
        self.window.generate_wiring()
        self.assertEqual(self.window.model.count(), 40)
        self.assertEqual(self.window.model.at(20, 4), (6, 1))
        self.assertEqual(self.window.model.count(verified=True), 0)
        self.window.undo()
        self.assertEqual(self.window.model.ports, {6: "B1"})
        self.assertEqual(self.window.model.count(), 0)
        self.assertEqual(self.controller.commands, [])

    def test_switching_fpc_moves_single_selection_and_control_target(self):
        self.window.model.bind_wiring(2, "T2")
        self.window.model.bind_wiring(7, "B2")
        self.window.fpc.set("7")
        self.window.channel.set("34")
        self.window.choose_channel()
        self.assertEqual(self.window.cell, (17, 5))
        self.window.choose_fpc(2)
        self.assertEqual(self.window.selected_source(), (2, 1))
        self.assertEqual(self.window.cell, (1, 5))
        self.assertEqual(self.window.previous_cell, (17, 5))
        self.assertIn("FPC2 / CH01", self.window.selected_cell.get())
        selected = self.window.canvas.find_withtag("selected_cell")
        self.assertEqual(len(selected), 1)
        self.assertIn("cell_box_r1_c5", self.window.canvas.gettags(selected[0]))
        previous = self.window.canvas.find_withtag("previous_cell")
        self.assertEqual(len(previous), 1)
        self.assertNotEqual(self.window.canvas.itemcget(previous[0], "outline"), "#152f51")
        self.controller.connected = True
        self.window.control_cell(1)
        self.assertEqual(self.controller.commands, ["BIT 5 0 1"])
        self.controller.ack(self.window)
        self.window.choose_fpc(8)  # No bound region: no black cell selection.
        self.assertIsNone(self.window.cell)
        self.assertEqual(self.window.canvas.find_withtag("selected_cell"), ())

    def test_old_json_migrates_without_writes_and_saves_new_rule_once(self):
        from ris_mapping import LEGACY_WIRING_PROFILE, WIRING_PROFILE
        old = self.window.model.document()
        old["wiring_profile"] = LEGACY_WIRING_PROFILE
        old["ports"] = {"1": "T1"}
        old["channels"] = [{"fpc": 1, "channel": 1, "row": 10, "column": 1,
                            "verified": False, "basis": "wiring"}]
        path = Path(self.folder.name) / "legacy.json"
        original = json.dumps(old)
        path.write_text(original)
        self.controller.connected = True
        self.window._schedule_test((1, 1))
        self.assertTrue(self.window.load_path(path))
        time.sleep(.12)
        self.root.update()
        self.assertIsNone(self.window.follow_timer)
        self.assertEqual(self.controller.commands, [])
        self.assertEqual(path.read_text(), original)
        self.assertEqual(self.window.cell, (1, 1))
        self.assertTrue(self.window.dirty)
        self.assertIn("按实测修正", self.window.notice.get())
        self.assertEqual(json.loads(self.window.recovery_path.read_text())["wiring_profile"], WIRING_PROFILE)
        self.assertTrue(self.window.save())
        self.assertFalse(self.window.dirty)
        self.assertTrue(self.window.load_path(path))
        self.assertEqual(self.window.cell, (1, 1))
        self.assertFalse(self.window.dirty)


class WorkerTests(unittest.TestCase):
    def test_shared_worker_connection_delivers_probe_ack(self):
        from ris_gui import RisGui
        class Client:
            instances = 0
            commands = []
            def __init__(self, *_):
                Client.instances += 1
                self.image = "00" * 50
            def command(self, command):
                Client.commands.append(command)
                if command.startswith("FRAME "):
                    self.image = command.split()[1]
                elif command == "ALL 0":
                    self.image = "00" * 50
                return {"image": self.image, "oe": True, "ok": True, "rc": 0,
                        "errors": 0, "blink_ms": 0, "status": 194, "frames": 1, "slots": 16}
            def close(self):
                pass
        root = tk.Tk()
        gui = None
        with tempfile.TemporaryDirectory() as folder, patch("ris_gui.RisClient", Client):
            try:
                gui = RisGui(root)
                def wait(predicate):
                    deadline = time.monotonic() + 3
                    while time.monotonic() < deadline:
                        root.update()
                        if predicate():
                            return
                        time.sleep(0.01)
                    self.fail(gui.notice.get())
                gui.connect()
                wait(lambda: gui.connected and not gui.busy)
                gui.open_mapping()
                window = gui.mapping_page
                window.storage_dir = Path(folder)
                window.recovery_path = Path(folder) / "recovery.json"
                window.auto_next.set(False)
                window.port.set("T1 · 上端1")
                window.bind_port()
                window.test_channel()
                self.assertIsNone(window.probed)
                wait(lambda: window.probed == (1, 1))
                self.assertTrue(window.has_probe())
                self.assertEqual(Client.instances, 1)
                window.measured.set(True)
                self.assertTrue(window.record(1, 1))
                self.assertEqual(window.model.count(verified=True), 1)
                connection = gui.connected
                writes = [cmd for cmd in Client.commands if cmd != "STATUS"]
                for _ in range(3):
                    gui.view_menu.invoke(0)
                    root.update()
                    self.assertEqual(gui.view.get(), "control")
                    gui.view_menu.invoke(1)
                    root.update()
                self.assertIs(gui.mapping_page, window)
                self.assertEqual(window.model.count(verified=True), 1)
                self.assertEqual(gui.connected, connection)
                self.assertEqual(Client.instances, 1)
                self.assertEqual([cmd for cmd in Client.commands if cmd != "STATUS"], writes)
                gui.show_page("control")
                gui.command("ALL 0")
                wait(lambda: gui.latest["image"] == "00" * 50 and not gui.busy)
                gui.open_mapping()
                self.assertIn("400路全部低", window.output_state.get())
                self.assertEqual(window.model.count(verified=True), 1)
            finally:
                if gui:
                    if gui.mapping_page:
                        gui.mapping_page.close(discard=True)
                    gui.close()
                else:
                    root.destroy()


class NavigationTests(unittest.TestCase):
    def setUp(self):
        from ris_gui import RisGui
        self.root = tk.Tk()
        self.gui = RisGui(self.root)
        self.folder = tempfile.TemporaryDirectory()
        self.gui.open_mapping()
        self.page = self.gui.mapping_page
        self.page.storage_dir = Path(self.folder.name)
        self.page.recovery_path = Path(self.folder.name) / "recovery.json"
        self.page.auto_next.set(False)
        self.root.update()

    def tearDown(self):
        if not self.gui.closed:
            self.page.close(discard=True)
            self.gui.close()
        self.folder.cleanup()

    def test_menu_and_tabs_share_one_window_and_keep_edits(self):
        page = self.page
        page.port.set("T1 · 上端1")
        page.bind_port()
        page.record(1, 1)
        page.channel.set("7")
        page.choose_channel()
        with patch("ris_mapping_gui.messagebox.askyesnocancel") as prompt:
            self.gui.view_menu.invoke(0)
            self.root.update()
            self.assertEqual(self.gui.pages.select(), str(self.gui.control_frame))
            self.assertFalse(page.frame.winfo_ismapped())
            self.assertTrue(self.gui.canvas.winfo_ismapped())
            self.gui.pages.select(self.gui.mapping_frame)
            self.root.update()
            prompt.assert_not_called()
        self.assertEqual(self.gui.view.get(), "mapping")
        self.assertTrue(page.frame.winfo_ismapped())
        self.assertFalse(self.gui.canvas.winfo_ismapped())
        self.assertIs(self.gui.mapping_page, page)
        self.assertEqual(page.model.count(), 40)
        self.assertEqual(page.channel.get(), "7")
        self.assertTrue(page.dirty)
        self.assertIs(page.frame.winfo_toplevel(), self.root)
        def toplevels(widget):
            return [child for child in widget.winfo_children()
                    if isinstance(child, tk.Toplevel)] + [window for child in widget.winfo_children()
                                                         for window in toplevels(child)]
        self.assertEqual(toplevels(self.root), [])
        self.assertTrue(self.gui.tasks.empty())

    def test_exit_cancel_keeps_both_pages_and_save_closes_app(self):
        self.page.port.set("T1 · 上端1")
        self.page.bind_port()
        self.gui.show_page("control")
        self.root.update()
        with patch("ris_mapping_gui.messagebox.askyesnocancel", return_value=None) as prompt:
            self.gui.close()
            prompt.assert_called_once()
        self.assertFalse(self.gui.closed)
        self.assertTrue(self.page.alive)
        self.assertTrue(self.root.winfo_exists())
        saved = Path(self.folder.name) / "mapping.json"
        self.page.path = saved
        with patch("ris_mapping_gui.messagebox.askyesnocancel", return_value=True):
            self.gui.close()
        self.assertTrue(self.gui.closed)
        self.assertTrue(saved.exists())

    def test_mapping_shortcuts_follow_active_page(self):
        with patch.object(self.page, "save") as save, patch.object(self.page, "undo") as undo:
            self.gui.show_page("control")
            self.assertIsNone(self.gui.mapping_shortcut("save"))
            save.assert_not_called()
            self.gui.open_mapping()
            self.assertEqual(self.gui.mapping_shortcut("save"), "break")
            self.assertEqual(self.gui.mapping_shortcut("undo"), "break")
            save.assert_called_once()
            undo.assert_called_once()

    def test_scrolled_array_selects_correct_cell_in_small_window(self):
        self.root.geometry("1180x810")
        self.root.update()
        canvas = self.page.canvas
        self.page.record_mode.set(False)
        canvas.yview_moveto(1.0)
        self.root.update()
        x0, y0, pitch, gap = self.page.grid_geometry
        x = x0 + 19.5 * pitch - canvas.canvasx(0)
        y = y0 + 19.5 * pitch + gap - canvas.canvasy(0)
        self.assertGreater(canvas.canvasy(0), 0)
        self.assertLess(y, canvas.winfo_height())
        canvas.event_generate("<Button-1>", x=int(x), y=int(y))
        self.root.update()
        self.assertEqual(self.page.cell, (20, 20))


if __name__ == "__main__":
    unittest.main()
