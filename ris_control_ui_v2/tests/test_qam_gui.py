"""QAM UI uses only the existing global gate; all traffic targets a fake."""
import json
from pathlib import Path
from types import SimpleNamespace
import unittest
import zipfile

import test_console_gui as baseline

Board = baseline.Board
from ris_patterns import compile_frame
from ris_qam256 import ORIENTATIONS
from ris_qam256_gui import QAM_TYPE, UNIFORM_TYPE


class QamGuiTests(unittest.TestCase):
    tearDown = baseline.ConsoleTests.tearDown
    wait = baseline.ConsoleTests.wait
    settle = baseline.ConsoleTests.settle
    connect = baseline.ConsoleTests.connect
    apply = baseline.ConsoleTests.apply
    writes = baseline.ConsoleTests.writes
    playlist = baseline.ConsoleTests.playlist

    def setUp(self):
        baseline.ConsoleTests.setUp(self)
        self.page = self.app.qam_page
        self.assertTrue(self.page.load(self.page.default_path))
        self.app.open_qam()
        self.root.update()

    def wiring(self, orientation="identity", high=True):
        self.app.qam_orientation.set(ORIENTATIONS[orientation])
        self.app.qam_state1.set("驱动高" if high else "驱动低")
        self.app.qam_confirmed.set(True)
        self.root.update()

    def test_preamble_load_is_offline_preserves_invalid_and_uses_snapshot(self):
        path = self.directory / "prefix.txt"
        path.write_text("(20,0);\n(50,0);\n(80,0);")
        self.assertTrue(self.page.load_preamble(path))
        self.root.update()
        saved = self.page.preamble_rows
        self.assertEqual(len(self.page.preamble_table.get_children()),3)
        path.write_text("(99,10);")
        self.assertFalse(self.page.load_preamble(path))
        self.assertEqual(self.page.preamble_rows,saved)
        self.assertEqual(self.writes(),[])
        self.assertEqual(Board.instances,0)
        self.wiring();self.page.timing_mode.set("低速数字核线（明确改速）")
        self.page.source.set("十六进制字节序列");self.page.sequence.set("3F")
        plan = self.page.prepare_action().payload
        self.assertEqual(plan.preamble.rows,saved)
        self.page.clear_preamble();self.root.update()
        self.assertFalse(self.page.preamble_enabled.get())
        self.assertEqual(self.page.preamble_rows,())
        self.assertEqual(plan.preamble.rows,saved)

    def test_loading_and_all_preview_edits_never_connect_or_send(self):
        self.wiring()
        self.page.symbol.set("FF")
        self.page.slot.set("127")
        self.page.row.set("7")
        self.page.column.set("15")
        self.page.source.set("测试序列00–FF")
        self.page.repeats.set("7")
        self.page.loop.set(False)
        self.page.action.set("static")
        self.root.update()
        self.assertEqual(Board.instances, 0)
        self.assertEqual(self.writes(), [])
        self.assertTrue(self.app.apply_button.instate(["disabled"]))
        self.assertEqual(self.app.status_title.get(), "未连接")

    def test_mt_subpages_are_exclusive_and_preserve_uniform_parameters(self):
        self.app.fast_value.set("125")
        self.app.fast_unit.set("k")
        for name in (UNIFORM_TYPE, QAM_TYPE, UNIFORM_TYPE, QAM_TYPE):
            self.app.show_mt_type(name)
            self.assertEqual(self.app.mt_content.pack_slaves(), [self.app.mt_panels[name]])
        self.assertEqual(self.app.fast_value.get(), "125")
        self.assertEqual(self.app.fast_unit.get(), "k")
        self.assertEqual(self.writes(), [])

    def test_static_needs_confirmed_wiring_and_complete_mapping(self):
        self.connect()
        self.page.action.set("static")
        self.root.update()
        self.assertFalse(self.app.apply_current())
        self.assertEqual(self.writes(), [])
        self.wiring()
        self.app.mapping_page.change(lambda model: model.unbind(1))
        self.assertFalse(self.app.apply_current())
        self.assertEqual(self.writes(), [])

    def test_static_only_sends_mapped_frame_after_global_button(self):
        self.connect()
        self.wiring("cw90", False)
        self.page.symbol.set("3A")
        self.page.slot.set("121")
        self.page.action.set("static")
        self.root.update()
        expected = compile_frame(self.page.book.pattern(0, 0x3a, 121, "cw90", False), self.app.mapping_page.model)
        self.assertEqual(self.writes(), [])
        self.app.apply_button.invoke()
        self.wait(lambda: not self.app.busy)
        self.assertEqual(self.writes(), ["FRAME " + expected.hex().upper()])
        self.assertIn("已确认", self.page.notice.get())
        self.assertEqual(self.app.status_title.get(), "256QAM静态码片")
        before = self.writes()
        self.page.symbol.set("FF")
        self.page.slot.set("9")
        self.root.update()
        self.assertEqual(self.writes(), before)
        self.assertEqual(self.app.status_title.get(), "256QAM静态码片")

    def test_static_rejection_is_reported_without_retry(self):
        self.connect()
        self.wiring()
        self.page.action.set("static")
        Board.reject = "FRAME"
        self.apply()
        self.assertEqual(len(self.writes()), 1)
        self.assertIn("未确认", self.page.notice.get())
        self.assertEqual(self.app.status_title.get(), "执行异常")

    def test_playback_is_blocked_even_with_uniform_mt_or_unimplemented_capability(self):
        self.connect()
        self.app.latest.update(mt_supported=True, qam_supported=True, vector_supported=True)
        self.wiring()
        self.page.action.set("play")
        self.root.update()
        self.assertTrue(self.app.apply_button.instate(["disabled"]))
        self.assertFalse(self.app.apply_current())
        self.assertEqual(self.writes(), [])
        self.assertFalse(self.app.mt_uploading)

    def test_export_and_preview_keep_previous_playlist_running(self):
        self.connect()
        player_page = self.playlist()
        self.apply()
        plan = self.app.playback_plan
        self.app.open_qam()
        self.wiring()
        before = self.writes()
        target = self.directory / "plan.zip"
        self.assertTrue(self.page.export(target))
        self.assertEqual(self.writes(), before)
        self.assertTrue(player_page.player.active)
        self.assertIs(self.app.playback_plan, plan)
        self.assertFalse(self.app.apply_current())
        self.assertTrue(player_page.player.active)

    def test_payload_export_uses_file_snapshot_and_exact_playback_settings(self):
        self.wiring("mirror_y", True)
        source = self.directory / "input.bin"
        source.write_bytes(b"\x00\x81\xff")
        self.assertTrue(self.page.load_payload(source))
        source.write_bytes(b"changed later")
        self.page.repeats.set("5")
        self.page.loop.set(False)
        self.root.update()
        self.assertIn("200,000.000 Baud", self.page.payload_text.get())
        target = self.directory / "snapshot.zip"
        self.assertTrue(self.page.export(target))
        with zipfile.ZipFile(target) as archive:
            manifest = json.loads(archive.read("manifest.json"))
            self.assertEqual(archive.read("payload.bin"), b"\x00\x81\xff")
            self.assertEqual(manifest["orientation"], "mirror_y")
            self.assertEqual(manifest["repeats_per_symbol"], 5)
            self.assertFalse(manifest["loop"])
            self.assertFalse(manifest["transport_ready"])
        self.assertEqual(self.writes(), [])

    def test_invalid_load_preserves_current_codebook_and_parameters(self):
        previous = self.page.book
        self.page.symbol.set("F1")
        self.page.repeats.set("9")
        bad = self.directory / "bad.zip"
        bad.write_bytes(b"not a zip")
        self.assertFalse(self.page.load(bad))
        self.assertIs(self.page.book, previous)
        self.assertEqual(self.page.symbol.get(), "F1")
        self.assertEqual(self.page.repeats.get(), "9")
        self.assertEqual(self.writes(), [])

    def test_orientation_changes_revoke_confirmation_and_save_only_local_settings(self):
        self.connect()
        self.wiring()
        self.assertTrue(self.app.save_qam_settings())
        data = json.loads(self.app.qam_settings_path.read_text())
        self.assertEqual(data, {"version": 1, "orientation": "identity", "state1_high": True, "confirmed": True})
        self.app.qam_orientation.set(ORIENTATIONS["cw90"])
        self.assertFalse(self.app.qam_confirmed.get())
        self.page.action.set("static")
        self.assertFalse(self.app.apply_current())
        self.assertFalse(self.app.save_qam_settings())
        self.app._load_qam_settings()
        self.assertEqual(self.app.qam_wiring(), ("identity", True))
        self.assertEqual(self.writes(), [])

    def test_settings_page_cannot_apply_a_hidden_oe_action(self):
        self.connect()
        self.app.settings_mode.set("disable")
        self.app.open_qam_settings()
        self.assertFalse(self.app.apply_current())
        self.assertEqual(self.writes(), [])

    def test_invalid_selections_do_not_write_and_stop_works_without_codebook(self):
        self.connect()
        self.wiring()
        self.page.action.set("static")
        for field, invalid, valid in ((self.page.symbol, "100", "00"), (self.page.slot, "256", "0"), (self.page.row, "0", "1")):
            field.set(invalid)
            self.root.update()
            self.assertFalse(self.app.apply_current())
            self.assertEqual(self.writes(), [])
            field.set(valid)
        self.page.book = None
        self.page.action.set("stop")
        self.assertEqual(self.writes(), [])
        self.apply()
        self.assertEqual(self.writes(), ["STOP"])

    def test_constellation_and_rotated_array_selection_only_change_preview(self):
        self.wiring("cw90", True)
        point = self.page.point_hits[31]
        self.page.pick_symbol(SimpleNamespace(x=point[0], y=point[1]))
        self.assertEqual(self.page.symbol.get(), "1F")
        x0, y0, size, _orientation = self.page.grid_geometry
        self.page.pick_cell(SimpleNamespace(x=x0 + 19.5 * size, y=y0 + .5 * size))
        self.assertEqual((self.page.row.get(), self.page.column.get()), ("1", "1"))
        self.assertEqual(self.writes(), [])


if __name__ == "__main__":
    unittest.main()
