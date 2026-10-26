"""Spatial encoding, persistent playlists and ACK-paced switching invariants."""
import copy
import heapq
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "host"))
from ris_mapping import PORTS, RisMapping
from ris_pattern_player import PatternPlayer
from ris_patterns import Pattern, PatternLibrary, compile_frame, from_image


def complete_mapping():
    result = RisMapping()
    for fpc, port in enumerate(PORTS, 1):
        result.bind_wiring(fpc, port)
    return result


class PatternTests(unittest.TestCase):
    def test_row_column_edits_intersections_and_undo_source_are_independent(self):
        blank = Pattern()
        row = blank.line("row", 1, 1)
        cross = row.line("column", 20, 1)
        self.assertEqual(blank.count(), 0)
        self.assertEqual(row.rows[0], "1" * 20)
        self.assertEqual(cross.count(), 39)
        self.assertEqual(cross.line("row", 1, 0).count(), 19)
        self.assertEqual(cross.line("column", 20, 0).count(), 19)
        self.assertEqual(cross.inverted().count(), 361)
        for axis, index, value in (("row", 0, 1), ("column", 21, 0), ("row", 1, 2)):
            with self.assertRaises(ValueError):
                blank.line(axis, index, value)

    def test_measured_row_endpoints_compile_to_known_595_pins(self):
        mapping = complete_mapping()
        # Independent physical anchors after the row-direction correction.
        for row, col, chip, bit in ((1, 1, 0, 0), (10, 1, 1, 1), (11, 1, 29, 7), (20, 1, 28, 6), (20, 20, 45, 0)):
            frame = compile_frame(Pattern().cell(row, col, 1), mapping)
            expected = bytearray(50)
            expected[chip] = 1 << bit
            self.assertEqual(frame, bytes(expected))
        grid = Pattern().line("row", 1, 1)
        image = compile_frame(grid, mapping)
        self.assertEqual(image[:5], bytes((1, 4, 16, 64, 0)))
        self.assertEqual(sum(v.bit_count() for v in image), 20)

    def test_spatial_save_survives_changed_fpc_bindings_and_all_cells_roundtrip(self):
        mapping = complete_mapping()
        reversed_mapping = RisMapping()
        for fpc, port in zip(range(10, 0, -1), PORTS):
            reversed_mapping.bind_wiring(fpc, port)
        for row in range(1, 21):
            grid = Pattern().line("row", row, 1).cell(row, 10, 0)
            self.assertEqual(from_image(compile_frame(grid, mapping), mapping).rows, grid.rows)
            self.assertEqual(from_image(compile_frame(grid, reversed_mapping), reversed_mapping).rows, grid.rows)
        point = Pattern().cell(1, 1, 1)
        self.assertNotEqual(compile_frame(point, mapping), compile_frame(point, reversed_mapping))
        self.assertEqual(compile_frame(Pattern(["1" * 20] * 20), mapping), b"\xff" * 50)

    def test_incomplete_and_unverified_manual_mapping_cannot_send_whole_patterns(self):
        mapping = complete_mapping()
        mapping.unbind(10)
        with self.assertRaises(ValueError):
            compile_frame(Pattern(), mapping)
        mapping.bind_wiring(10, "B5")
        mapping.assign(1, 1, 1, 1)
        with self.assertRaises(ValueError):
            compile_frame(Pattern(), mapping)
        mapping.assign(1, 1, 1, 1, verified=True)
        self.assertEqual(compile_frame(Pattern(), mapping), bytes(50))

    def test_library_playlist_and_ids_roundtrip_and_delete(self):
        library = PatternLibrary()
        a = library.put("图案A", Pattern().line("row", 7, 1))
        b = library.put("图案B", Pattern().line("column", 8, 1))
        library.add_step(a, 100)
        library.add_step(b, 2000)
        library.add_step(a, 300)
        library.mode = "pingpong"
        library.put("图案A改名", Pattern().cell(1, 1, 1), a)
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "patterns.json"
            library.save(path)
            loaded = PatternLibrary.load(path)
            self.assertEqual(loaded.document(), library.document())
            self.assertFalse(list(Path(folder).glob("*.tmp")))
        loaded.delete(a)
        self.assertEqual(loaded.playlist, [{"pattern": b, "dwell_ms": 2000}])
        self.assertEqual(loaded.mode, "pingpong")

    def test_malformed_library_cannot_replace_a_good_file(self):
        library = PatternLibrary.defaults()
        key = next(iter(library.patterns))
        library.add_step(key, 1000)
        cases = []
        for field, value in (("rows", ["0"]), ("name", ""), ("id", "")):
            bad = copy.deepcopy(library.document())
            bad["patterns"][0][field] = value
            cases.append(bad)
        for field, value in (("dwell_ms", True), ("dwell_ms", 99), ("pattern", "missing")):
            bad = copy.deepcopy(library.document())
            bad["playlist"][0][field] = value
            cases.append(bad)
        bad = copy.deepcopy(library.document())
        bad["patterns"].append(dict(bad["patterns"][0]))
        cases.append(bad)
        for doc in cases:
            with self.assertRaises(ValueError):
                PatternLibrary.from_document(doc)
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "good.json"
            library.save(path)
            before = path.read_bytes()
            library.playlist[0]["dwell_ms"] = 1
            with self.assertRaises(ValueError):
                library.save(path)
            self.assertEqual(path.read_bytes(), before)
            path.write_text('{"format":"RIS-PATTERN-LIBRARY","format":"bad"}')
            with self.assertRaises(ValueError):
                PatternLibrary.load(path)


class Clock:
    def __init__(self):
        self.now, self.sequence = 0, 0
        self.queue, self.cancelled = [], set()

    def after(self, delay, callback):
        self.sequence += 1
        heapq.heappush(self.queue, (self.now + delay, self.sequence, callback))
        return self.sequence

    def after_cancel(self, timer):
        self.cancelled.add(timer)

    def tick(self, duration):
        end = self.now + duration
        while self.queue and self.queue[0][0] <= end:
            self.now, sequence, callback = heapq.heappop(self.queue)
            if sequence not in self.cancelled:
                callback()
        self.now = end


class PlayerTests(unittest.TestCase):
    def setUp(self):
        self.clock = Clock()
        self.connected, self.busy = True, False
        self.sent, self.events = [], []
        self.pending = None
        def send(command, callback):
            self.sent.append(command)
            self.pending = callback
            self.busy = True
            return True
        self.player = PatternPlayer(self.clock, send, lambda: self.connected, lambda: self.busy,
                                    lambda *event: self.events.append(event))
        self.steps = [{"name": chr(65 + i), "image": bytes([i]) * 50, "dwell_ms": 100} for i in range(3)]

    def ack(self, **changes):
        reply = {"ok": True, "errors": 0, "oe": True, "blink_ms": 0, "image": self.sent[-1].split()[1]}
        reply.update(changes)
        self.busy = False
        pending, self.pending = self.pending, None
        pending(reply, None)

    def test_once_waits_for_ack_then_full_dwell_and_leaves_last_frame(self):
        self.player.start(self.steps, "once")
        self.clock.tick(10000)
        self.assertEqual(len(self.sent), 1)
        for count in (1, 2, 3):
            self.ack()
            self.clock.tick(99)
            self.assertEqual(len(self.sent), count)
            self.clock.tick(1)
        self.assertFalse(self.player.active)
        self.assertEqual(len(self.sent), 3)
        self.assertIn("完成", self.events[-1][-1])
        self.assertEqual(self.sent[-1], "FRAME " + "02" * 50)

    def test_loop_pingpong_and_random_indices(self):
        for mode, expected in (("loop", [0, 1, 2, 0, 1]), ("pingpong", [0, 1, 2, 1, 0])):
            self.player.start(self.steps, mode)
            observed = []
            for _ in range(5):
                observed.append(self.player.index)
                self.ack()
                self.clock.tick(100)
            self.player.stop()
            self.ack()  # Complete the already submitted next frame after stop.
            self.assertEqual(observed, expected)
        self.player.start(self.steps, "random")
        for _ in range(20):
            previous = self.player.index
            self.ack()
            self.clock.tick(100)
            self.assertNotEqual(self.player.index, previous)

    def test_stop_during_inflight_and_late_old_ack_never_restart(self):
        self.player.start(self.steps, "loop")
        self.player.stop()
        self.ack()
        self.clock.tick(10000)
        self.assertEqual(len(self.sent), 1)
        self.player.start(self.steps, "loop")
        self.ack()
        self.player.stop()
        self.clock.tick(10000)
        self.assertEqual(len(self.sent), 2)

    def test_poll_busy_waits_without_skipping_and_disconnect_stops(self):
        self.player.start(self.steps, "loop")
        self.ack()
        self.busy = True
        self.clock.tick(160)
        self.assertEqual(len(self.sent), 1)
        self.busy = False
        self.clock.tick(20)
        self.assertEqual(len(self.sent), 2)
        self.ack()
        self.connected = False
        self.clock.tick(100)
        self.assertFalse(self.player.active)
        self.assertEqual(len(self.sent), 2)

    def test_rejected_or_mismatched_ack_stops_without_retry(self):
        for changes in ({"ok": False}, {"errors": 1}, {"oe": False}, {"blink_ms": 100}, {"image": "FF" * 50}):
            self.player.start(self.steps, "loop")
            before = len(self.sent)
            self.ack(**changes)
            self.clock.tick(5000)
            self.assertFalse(self.player.active)
            self.assertEqual(len(self.sent), before)

    def test_one_item_loop_and_snapshot_immutability(self):
        steps = [dict(self.steps[0])]
        self.player.start(steps, "pingpong")
        steps[0]["image"] = b"\xff" * 50
        for _ in range(3):
            self.assertEqual(self.sent[-1], "FRAME " + "00" * 50)
            self.ack()
            self.clock.tick(100)


if __name__ == "__main__":
    unittest.main()
