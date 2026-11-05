"""Real Tk/worker integration; all board traffic goes to an in-memory fake."""
from pathlib import Path
import sys
import tempfile
import threading
import time
import tkinter as tk
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from ris_actions import confirmed_status, OutputAction
from ris_gui import FEATURES, RisGui
from ris_mapping import PORTS, RisMapping, probe_command
from ris_mt import compile_mt, parse_mt
from ris_patterns import MODES, Pattern, PatternLibrary, compile_frame


class Board:
    commands = []
    instances = 0
    reject = None
    bad_ack = False
    variable = True
    mt_supported = True
    gate_op = None
    blocked = threading.Event()
    release = threading.Event()

    def __init__(self, *_):
        type(self).instances += 1
        self.image = bytearray(50)
        self.oe, self.blink, self.ticks = True, 0, 0
        self.running, self.loaded, self.period = False, 0, 300

    def command(self, command):
        cls = type(self)
        cls.commands.append(command)
        fields = command.split()
        op = fields[0]
        if op == cls.gate_op:
            cls.blocked.set()
            cls.release.wait(3)
        ok = op != cls.reject
        if ok:
            if op not in ("STATUS", "OE", "MTSEG", "MTSTART", "MTBEGIN"):
                self.blink = self.ticks = 0
                self.running = False
            if op == "ALL":
                self.image[:] = bytes([255 if fields[1] == "1" else 0]) * 50
                self.oe = True
            elif op == "FRAME":
                self.image[:] = bytes.fromhex(fields[1])
                self.oe = True
            elif op == "BIT":
                chip, bit, value = map(int, fields[1:])
                self.image[chip] = (self.image[chip] & ~(1 << bit)) | value << bit
                self.oe = True
            elif op in ("CHIP", "GROUP"):
                index, value = int(fields[1]), int(fields[2], 16)
                if op == "CHIP":
                    self.image[index] = value
                else:
                    self.image[index * 5:index * 5 + 5] = bytes([value]) * 5
                self.oe = True
            elif op == "BLINK":
                self.blink = int(fields[1])
                self.oe = True
            elif op == "FASTTICKS":
                self.ticks = int(fields[1])
                self.oe = True
            elif op == "OE":
                self.oe = fields[1] == "1"
                if not self.oe:
                    self.blink = self.ticks = 0
                    self.running = False
            elif op == "MTBEGIN":
                self.loaded, self.period = 0, int(fields[3])
                self.running, self.blink, self.ticks = False, 0, 0
            elif op == "MTSEG":
                self.loaded += 1
            elif op == "MTSTART":
                self.running = fields[1] == "1"  # A short one-shot completes immediately.
                self.image[:] = bytes(50)
                self.oe = True
        return {"ok": ok, "rc": 0 if ok else -3, "errors": 0 if ok else 1,
                "oe": self.oe, "blink_ms": self.blink, "status": 194, "frames": len(cls.commands),
                "image": self.image.hex().upper(), "slots": 16,
                "fast_supported": cls.variable, "fast_variable": cls.variable,
                "fast_mhz": {150: 1, 50: 3, 30: 5}.get(self.ticks, 0), "fast_ticks": self.ticks, "fast_edges": 123,
                "mt_supported": cls.mt_supported, "mt_running": self.running,
                "mt_period": self.period, "mt_loaded": self.loaded + int(cls.bad_ack)}

    def close(self):
        pass


class ConsoleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.directory = Path(self.temp.name)
        self.patch = patch("ris_gui.RisClient", Board)
        self.patch.start()
        Board.commands, Board.instances = [], 0
        Board.reject = Board.gate_op = None
        Board.bad_ack = False
        Board.variable = Board.mt_supported = True
        Board.blocked.clear()
        Board.release.clear()
        self.root = tk.Tk()
        self.root.withdraw()
        self.errors = []
        self.root.report_callback_exception = lambda *args: self.errors.append(args)
        self.app = RisGui(self.root, pattern_storage=self.directory / "patterns", mapping_storage=self.directory / "mappings")
        self.root.after_cancel(self.app.poll_timer)
        model = RisMapping()
        for fpc, port in enumerate(PORTS, 1):
            model.bind_wiring(fpc, port)
        self.app.mapping_page.model = model
        self.app.mapping_page.refresh()
        self.app.pattern_page.may_discard = lambda: True
        self.app.show_page("board")
        self.root.update()

    def tearDown(self):
        Board.release.set()
        if not self.app.closed:
            self.app.mapping_page.dirty = False
            self.app.close()
        self.patch.stop()
        self.temp.cleanup()
        self.assertEqual(self.errors, [], f"Tk callback errors: {self.errors}")

    def wait(self, predicate, timeout=4):
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            self.root.update()
            if predicate():
                return
            time.sleep(.005)
        self.fail(self.app.notice.get())

    def settle(self, seconds=.15):
        end = time.monotonic() + seconds
        while time.monotonic() < end:
            self.root.update()
            time.sleep(.005)

    def connect(self):
        self.app.connect_button.invoke()
        self.wait(lambda: self.app.connected and not self.app.busy)

    def apply(self):
        self.assertTrue(self.app.apply_current(), self.app.pending_text.get())
        self.wait(lambda: not self.app.busy)

    def writes(self):
        return [command for command in Board.commands if command != "STATUS"]

    def table(self, text="(50,10);\n(30,0);", frequency="1"):
        path = self.directory / "mt.txt"
        path.write_text(text)
        self.app.show_page("mt")
        self.app.fast_value.set(frequency)
        self.app.fast_unit.set("M")
        self.assertTrue(self.app.mt_controls.load(path))

    def playlist(self, mode="loop"):
        self.app.show_page("patterns")
        page = self.app.pattern_page
        library = PatternLibrary.defaults()
        for key in list(library.patterns)[:2]:
            library.add_step(key, 100)
        library.mode = mode
        page.library = library
        page.refresh_lists(0)
        page.mode.set(MODES[mode])
        page.start_button.invoke()
        return page

    def test_one_major_page_and_one_settings_pane_visible(self):
        self.assertEqual(list(FEATURES.values()), ["全板控制", "MT时域控制", "图案切换控制", "全板设置"])
        for page in ("home", *FEATURES):
            self.app.show_page(page)
            self.root.update()
            self.assertEqual(self.app.content.pack_slaves(), [self.app.frames[page]])
        self.app.open_mapping()
        self.assertEqual(self.app.current_page, "settings")
        for name, frame in self.app.settings_frames.items():
            self.app.show_settings(name)
            self.assertEqual(self.app.settings_content.pack_slaves(), [frame])
        self.assertEqual(Board.instances, 0)

    def test_offline_config_buttons_never_create_a_connection(self):
        self.app.manual.select_cell(1, 1)
        self.app.manual.high_button.invoke()
        self.app.manual.low_button.invoke()
        self.app.manual.test_button.invoke()
        self.app.manual.zero_button.invoke()
        self.app.hex_value.set("A5")
        self.app.apply_byte(False)
        self.app.apply_byte(True)
        self.table()
        for button in (self.app.mt_controls.once_button, self.app.mt_controls.loop_button, self.app.mt_controls.stop_button):
            button.invoke()
        self.app.open_mapping()
        page = self.app.mapping_page
        for button in (page.test_button, page.test_group_button, page.high_button, page.low_button, page.zero_button):
            button.invoke()
        patterns = self.playlist()
        for button in (patterns.apply_button, patterns.start_button, patterns.stop_button, patterns.step_button, patterns.next_button, patterns.previous_button):
            button.invoke()
        self.root.update()
        self.assertEqual(Board.instances, 0)
        self.assertEqual(self.writes(), [])
        self.assertTrue(self.app.apply_button.instate(["disabled"]))

    def test_board_modes_only_apply_from_total_button_and_report_actual_state(self):
        self.connect()
        for mode, command, title in (("all1", "ALL 1", "停止 · 全1保持"), ("all0", "ALL 0", "停止 · 全0保持"),
                                     ("blink", "BLINK 1000", "全0 / 全1慢速循环"), ("fast", "FASTTICKS 30", "全0 / 全1循环"),
                                     ("stop", "STOP", "停止 · 全0保持")):
            before, previous = self.writes(), self.app.status_title.get()
            self.app.board_mode.set(mode)
            self.root.update()
            self.assertEqual(self.writes(), before)
            self.assertEqual(self.app.status_title.get(), previous)
            self.app.apply_button.invoke()
            self.wait(lambda: not self.app.busy)
            self.assertEqual(self.writes(), before + [command])
            self.assertEqual(self.app.status_title.get(), title)

    def test_total_button_uses_only_current_feature_and_retains_other_drafts(self):
        self.connect()
        self.app.board_mode.set("all1")
        self.table()
        self.app.open_mapping()
        self.app.mapping_page.test_fpc()
        self.app.show_page("board")
        self.apply()
        self.assertEqual(self.writes(), ["ALL 1"])
        self.app.show_page("mt")
        self.apply()
        self.assertEqual(self.writes()[1:], list(self.app.mt_controls.plan().commands()))
        self.assertEqual(self.app.board_mode.get(), "all1")

    def test_worker_rejects_direct_writes_and_unapproved_playlist_frames(self):
        self.connect()
        self.assertFalse(self.app.submit("command", "ALL 1"))
        self.assertFalse(self.app.submit("mt", compile_mt(parse_mt("(50,0);"), "1", "M")))
        self.assertFalse(self.app.send_play_frame("ALL 1", None, self.app.pattern_page.player))
        self.assertEqual(self.writes(), [])
        self.app.command("ALL 1")
        self.assertEqual(self.writes(), [])
        self.apply()
        self.assertEqual(self.writes(), ["ALL 1"])

    def test_byte_configuration_reads_latest_fields_at_total_apply(self):
        self.connect()
        self.app.hex_value.set("A5")
        self.app.apply_byte(False)
        self.assertEqual(self.writes(), [])
        self.app.hex_value.set("5A")
        self.apply()
        self.assertEqual(self.writes(), ["CHIP 0 5A"])
        self.app.apply_byte(True)
        self.app.hex_value.set("FF")
        self.apply()
        self.assertEqual(self.writes()[-1], "GROUP 0 FF")

    def test_connect_preserves_prepared_offline_byte_configuration(self):
        self.app.hex_value.set("A5")
        self.app.apply_byte(False)
        self.connect()
        self.assertEqual(self.app.hex_value.get(), "A5")
        self.assertEqual(self.writes(), [])
        self.apply()
        self.assertEqual(self.writes(), ["CHIP 0 A5"])

    def test_manual_and_mapping_probes_wait_for_total_and_callback_ack(self):
        self.connect()
        self.app.manual.select_cell(1, 1)
        self.app.manual.high_button.invoke()
        self.assertEqual(self.writes(), [])
        self.apply()
        self.assertTrue(self.writes()[-1].startswith("BIT "))
        self.app.manual.test_button.invoke()
        count = len(self.writes())
        self.assertIsNone(self.app.mapping_page.probed)
        self.apply()
        self.assertEqual(len(self.writes()), count + 1)
        self.assertTrue(self.app.mapping_page.has_probe())
        self.app.manual.zero_button.invoke()
        self.assertTrue(self.app.mapping_page.has_probe())
        self.apply()
        self.assertFalse(self.app.mapping_page.has_probe())

    def test_settings_oe_is_staged_and_mapping_draft_cannot_leak_to_general(self):
        self.connect()
        self.app.show_page("settings")
        for mode, command, title in (("disable", "OE 0", "输出禁能 · 高阻"), ("enable", "OE 1", "停止 · 全0保持")):
            before = self.writes()
            self.app.settings_mode.set(mode)
            self.assertEqual(before, self.writes())
            self.apply()
            self.assertEqual(self.writes()[-1], command)
            self.assertEqual(self.app.status_title.get(), title)
        self.app.open_mapping()
        self.app.mapping_page.test_fpc()
        self.app.show_settings("输出设置")
        before = self.writes()
        self.assertFalse(self.app.apply_current())
        self.assertEqual(self.writes(), before)

    def test_mapping_changes_invalidate_prepared_cell_command(self):
        self.connect()
        self.app.manual.select_cell(1, 1)
        self.app.manual.high_button.invoke()
        self.app.mapping_page.change(lambda model: model.unbind(1))
        self.assertFalse(self.app.apply_current())
        self.assertIn("映射已修改", self.app.pending_text.get())
        self.assertEqual(self.writes(), [])

    def test_auto_next_only_prepares_new_probe_until_total_apply(self):
        self.connect()
        self.app.open_mapping()
        page = self.app.mapping_page
        page.test_button.invoke()
        self.assertEqual(self.writes(), [])
        self.apply()
        before = self.writes()
        key = page.probed
        cell = page.model.channels[key]
        page.measured.set(True)
        page.auto_test.set(True)
        self.assertTrue(page.record(cell["row"], cell["column"]))
        self.settle()
        self.assertEqual(self.writes(), before)
        self.assertIn("CH02", self.app.pending_text.get())
        self.apply()
        self.assertEqual(self.writes()[-1], probe_command(key[0], 2))

    def test_mt_upload_order_once_loop_and_stop_are_all_gated(self):
        self.connect()
        self.table()
        for loop, button in ((False, self.app.mt_controls.once_button), (True, self.app.mt_controls.loop_button)):
            before = self.writes()
            button.invoke()
            self.assertEqual(self.writes(), before)
            plan = self.app.mt_controls.plan()
            self.assertEqual(plan.loop, loop)
            self.apply()
            self.assertEqual(self.writes()[len(before):], list(plan.commands()))
            self.assertIn("MT 模式循环" if loop else "MT 一次完成", self.app.status_title.get())
        before = self.writes()
        self.app.mt_controls.stop_button.invoke()
        self.assertEqual(self.writes(), before)
        self.assertEqual(self.app.status_title.get(), "MT 模式循环")
        self.apply()
        self.assertEqual(self.writes()[-1], "STOP")

    def test_cancel_upload_requires_a_second_total_button_click(self):
        self.connect()
        self.table()
        Board.gate_op = "MTSEG"
        self.assertTrue(self.app.apply_current())
        self.wait(Board.blocked.is_set)
        self.app.mt_controls.cancel_button.invoke()
        self.assertFalse(self.app.mt_cancel.is_set())
        self.assertFalse("STOP" in self.writes())
        self.assertTrue(self.app.apply_current())
        Board.release.set()
        self.wait(lambda: not self.app.busy)
        self.assertEqual(self.writes()[-1], "STOP")
        self.assertFalse(any(c.startswith("MTSTART") for c in self.writes()))

    def test_mt_bad_ack_or_rejection_prevents_start_without_retry(self):
        for bad_ack, reject in ((True, None), (False, "MTSEG")):
            self.connect()
            self.table()
            Board.bad_ack, Board.reject = bad_ack, reject
            self.assertTrue(self.app.apply_current())
            self.wait(lambda: not self.app.busy)
            self.assertFalse(self.app.connected)
            self.assertFalse(any(c.startswith("MTSTART") for c in self.writes()))
            self.assertEqual(self.app.status_title.get(), "未连接")
            Board.bad_ack, Board.reject = False, None

    def test_cancel_at_last_upload_ack_still_stops_started_mt(self):
        self.connect()
        self.table()
        Board.gate_op = "MTSTART"
        self.assertTrue(self.app.apply_current())
        self.wait(Board.blocked.is_set)
        self.app.mt_controls.cancel_button.invoke()
        self.assertTrue(self.app.apply_current())
        Board.release.set()
        self.wait(lambda: not self.app.busy)
        self.assertTrue(any(c.startswith("MTSTART") for c in self.writes()))
        self.assertEqual(self.writes()[-1], "STOP")
        self.assertFalse(self.app.latest["mt_running"])
        self.assertTrue(self.app.status_title.get().startswith("停止"))

    def test_unsupported_mt_only_rejects_at_apply_and_preserves_frequency(self):
        self.connect()
        self.table()
        self.app.latest["mt_supported"] = False
        self.app.mt_controls.loop_button.invoke()
        self.assertEqual(self.app.fast_value.get(), "1")
        self.assertFalse(self.app.apply_current())
        self.assertEqual(self.writes(), [])

    def test_local_configuration_replaces_board_panel_without_output(self):
        self.app.board_mode.set("all1")
        self.app.show_chip_editor.set(True)
        self.app.toggle_chip_editor()
        self.assertEqual(self.app.board_modes.winfo_manager(), "")
        self.assertEqual(self.app.local_controls.winfo_manager(), "pack")
        self.app.show_chip_editor.set(False)
        self.app.toggle_chip_editor()
        self.assertEqual(self.app.local_controls.winfo_manager(), "")
        self.assertEqual(self.app.board_mode.get(), "all1")
        self.assertEqual(self.writes(), [])

    def test_invalid_or_unsupported_new_config_keeps_running_output(self):
        self.connect()
        page = self.playlist()
        self.apply()
        self.assertTrue(page.player.active)
        self.app.show_page("board")
        self.app.board_mode.set("fast")
        self.app.board_frequency.set("99")
        self.assertFalse(self.app.apply_current())
        self.assertTrue(page.player.active)
        self.app.board_frequency.set("5")
        self.app.latest["fast_variable"] = False
        self.assertFalse(self.app.apply_current())
        self.assertTrue(page.player.active)
        self.app.board_mode.set("all1")
        self.apply()
        self.assertFalse(page.player.active)
        self.assertEqual(self.writes()[-1], "ALL 1")

    def test_pattern_edit_manual_step_and_playlist_buttons_are_drafts(self):
        self.connect()
        page = self.playlist()
        page.edit(Pattern().line("row", 1, 1))
        for button in (page.apply_button, page.step_button, page.next_button, page.previous_button, page.start_button, page.stop_button):
            button.invoke()
            self.assertEqual(self.writes(), [])
        page.apply_button.invoke()
        self.apply()
        expected = compile_frame(page.pattern, self.app.mapping_page.model).hex().upper()
        self.assertEqual(self.writes(), ["FRAME " + expected])
        self.assertIn("已确认", page.notice.get())

    def test_pattern_run_uses_immutable_snapshot_during_edits_and_page_changes(self):
        self.connect()
        page = self.playlist()
        self.apply()
        plan = self.app.playback_plan
        self.assertTrue(page.player.active)
        page.edit(Pattern().line("row", 1, 1))
        page.save_pattern()
        page.duration.set("4000")
        page.set_duration(all_steps=True)
        page.mode.set(MODES["once"])
        page.set_mode()
        self.app.open_mapping()
        self.app.mapping_page.change(lambda model: model.unbind(1))
        self.assertTrue(page.player.active)
        self.wait(lambda: len(self.writes()) >= 3)
        expected = ["FRAME " + step.image.hex().upper() for step in plan.steps]
        self.assertEqual(self.writes()[:3], [expected[0], expected[1], expected[0]])
        self.assertEqual(page.player.mode, "loop")
        self.assertTrue(all(step["dwell_ms"] == 100 for step in page.player.steps))

    def test_staged_pattern_stop_does_not_cancel_before_total(self):
        self.connect()
        page = self.playlist()
        self.apply()
        page.stop_button.invoke()
        self.assertTrue(page.player.active)
        self.wait(lambda: len(self.writes()) >= 2 and not self.app.busy)
        self.apply()
        count = len(self.writes())
        self.settle(.25)
        self.assertFalse(page.player.active)
        self.assertEqual(self.writes()[-1], "STOP")
        self.assertEqual(len(self.writes()), count)

    def test_once_playlist_finishes_and_does_not_restart_on_poll(self):
        self.connect()
        page = self.playlist("once")
        self.apply()
        self.wait(lambda: not page.player.active)
        before = self.writes()
        self.assertEqual(len(before), 2)
        self.assertTrue(self.app.status_title.get().startswith("停止"))
        self.app.submit("poll")
        self.wait(lambda: not self.app.busy)
        self.assertEqual(before, self.writes())

    def test_rejection_keeps_draft_visible_without_retries(self):
        self.connect()
        self.app.board_mode.set("all1")
        Board.reject = "ALL"
        self.apply()
        self.assertEqual(self.writes(), ["ALL 1"])
        self.assertEqual(self.app.board_mode.get(), "all1")
        self.assertEqual(self.app.status_title.get(), "执行异常")

    def test_imported_mapping_saves_in_copy_and_preserves_source(self):
        original = self.directory / "input.json"
        self.app.mapping_page.model.save(original)
        before = original.read_bytes()
        page = self.app.mapping_page
        self.assertTrue(page.load_path(original))
        page.change(lambda model: model.unbind(1))
        self.assertTrue(page.save())
        self.assertEqual(page.path.parent, page.storage_dir)
        self.assertEqual(original.read_bytes(), before)
        self.assertEqual(RisMapping.load(page.path).count(), 360)


class StatusTests(unittest.TestCase):
    def test_mt_constant_modes_and_existing_unknown_run(self):
        board = Board()
        reply = board.command("STATUS")
        reply["mt_running"] = True
        self.assertEqual(confirmed_status(True, reply)[0], "MT 模式运行")
        for m, title in ((0, "全0循环 · MT"), (100, "全1循环 · MT"), (50, "MT 模式循环")):
            plan = compile_mt(parse_mt(f"({m},0);"), "1", "M", True)
            action = OutputAction("mt", plan, "preview")
            self.assertEqual(confirmed_status(True, reply, action)[0], title)
        self.assertEqual(confirmed_status(False, reply)[0], "未连接")


if __name__ == "__main__":
    unittest.main()
