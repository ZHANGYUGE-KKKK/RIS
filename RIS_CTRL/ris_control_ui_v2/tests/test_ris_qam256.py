"""Codebook integrity, physical bit mapping and complete exported-plan oracle."""
import hashlib
import json
from pathlib import Path
import random
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from ris_mapping import RisMapping
from ris_patterns import compile_frame
from ris_qam256 import (CONTENT, MAX_PAYLOAD, ORIENTATIONS, QamCodebook, export_plan,
                        parse_symbol, payload_bytes, read_payload, transform_cell)

BASE = Path(__file__).resolve().parents[1]
EXAMPLE = BASE.parents[1] / "QAM_RULES/256QAM/ris_256qam_256slice_codebook_0deg.zip"


class CodebookTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.book = QamCodebook.load(EXAMPLE)
        with zipfile.ZipFile(EXAMPLE) as archive:
            cls.members = {name: archive.read(name) for name in (*CONTENT, "SHA256SUMS.txt")}
        cls.mapping = RisMapping.load(BASE / "mappings/ris_mapping.json")

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def directory(self, changes=None, rehash=False):
        data = dict(self.members)
        data.update(changes or {})
        if rehash:
            data["SHA256SUMS.txt"] = "".join(f"{hashlib.sha256(data[name]).hexdigest()}  {name}\n" for name in CONTENT).encode()
        folder = self.path / "codebook"
        folder.mkdir(exist_ok=True)
        for name, value in data.items():
            (folder / name).write_bytes(value)
        return folder

    def test_directory_and_rooted_zip_have_same_verified_content(self):
        folder = self.directory()
        from_dir = QamCodebook.load(folder)
        archive = self.path / "nested.zip"
        with zipfile.ZipFile(archive, "w") as stream:
            for name, data in self.members.items():
                stream.writestr("export/" + name, data)
        from_zip = QamCodebook.load(archive)
        self.assertEqual(from_dir.fingerprint, self.book.fingerprint)
        self.assertEqual(from_zip.fingerprint, self.book.fingerprint)
        self.assertEqual(len(from_dir.frames), 3276800)
        self.assertEqual(from_dir.angles, (0.0,))
        self.assertEqual(from_dir.default_repeats, 3)

    def test_frames_match_independent_modulo_pulses_for_random_coordinates(self):
        rng = random.Random(1234)
        for _ in range(2000):
            symbol, slot, unit = rng.randrange(256), rng.randrange(256), rng.randrange(400)
            width, start = self.book.pulse(0, symbol, unit)
            expected = int((slot - start) % self.book.slots < width)
            image = self.book.frame(0, symbol, slot)
            self.assertEqual((image[unit // 8] >> (unit % 8)) & 1, expected)

    def test_hash_failure_does_not_accept_modified_binary(self):
        data = bytearray(self.members["codebook_frames.bin"])
        data[0] ^= 1
        folder = self.directory({"codebook_frames.bin": bytes(data)})
        with self.assertRaisesRegex(ValueError, "校验失败"):
            QamCodebook.load(folder)

    def test_rehashed_binary_must_still_match_pulse_parameters(self):
        data = bytearray(self.members["codebook_frames.bin"])
        data[0] ^= 1
        folder = self.directory({"codebook_frames.bin": bytes(data)}, rehash=True)
        with self.assertRaisesRegex(ValueError, "脉冲表与二进制"):
            QamCodebook.load(folder)

    def test_short_binary_rejected_even_when_checksum_matches(self):
        folder = self.directory({"codebook_frames.bin": self.members["codebook_frames.bin"][:-1]}, rehash=True)
        with self.assertRaisesRegex(ValueError, "长度"):
            QamCodebook.load(folder)

    def test_invalid_metadata_and_layout_rejected(self):
        for field, value in (("slots", 0), ("slots", True), ("pwm_mhz", float("nan")), ("rows", 10)):
            metadata = json.loads(self.members["metadata.json"])
            metadata["config"][field] = value
            folder = self.directory({"metadata.json": json.dumps(metadata).encode()}, rehash=True)
            with self.assertRaises(ValueError, msg=(field, value)):
                QamCodebook.load(folder)
        metadata = json.loads(self.members["metadata.json"])
        metadata["binary_layout"]["bit_order"] = "big"
        with self.assertRaisesRegex(ValueError, "位序"):
            QamCodebook.load(self.directory({"metadata.json": json.dumps(metadata).encode()}, rehash=True))

    def test_bad_symbol_gray_mapping_rejected(self):
        text = self.members["symbols.csv"].decode().replace("0,00,00000000,-15,-15,", "0,00,00000000,-13,-15,", 1)
        folder = self.directory({"symbols.csv": text.encode()}, rehash=True)
        with self.assertRaisesRegex(ValueError, "Gray"):
            QamCodebook.load(folder)

    def test_nonfinite_extra_metadata_rejected(self):
        metadata = json.loads(self.members["metadata.json"])
        metadata["directions"][0]["evm_equalized_percent"] = float("nan")
        folder = self.directory({"metadata.json": json.dumps(metadata).encode()}, rehash=True)
        with self.assertRaisesRegex(ValueError, "非有限"):
            QamCodebook.load(folder)

    def test_duplicate_pulse_record_rejected(self):
        data = self.members["pulse_parameters.csv"]
        data += data.splitlines(keepends=True)[1]
        folder = self.directory({"pulse_parameters.csv": data}, rehash=True)
        with self.assertRaisesRegex(ValueError, "重复"):
            QamCodebook.load(folder)

    def test_zip_paths_duplicates_and_size_limit_rejected_without_extraction(self):
        bad = self.path / "bad.zip"
        with zipfile.ZipFile(bad, "w") as archive:
            for name, data in self.members.items():
                archive.writestr("../" + name, data)
        with self.assertRaisesRegex(ValueError, "不安全"):
            QamCodebook.load(bad)
        self.assertFalse((self.path.parent / "metadata.json").exists())
        with patch("ris_qam256.MAX_TOTAL", 1024):
            with self.assertRaisesRegex(ValueError, "64 MiB"):
                QamCodebook.load(EXAMPLE)
        with patch("ris_qam256.zipfile.ZipFile.read", side_effect=EOFError("truncated stream")):
            with self.assertRaisesRegex(ValueError, "truncated stream"):
                QamCodebook.load(EXAMPLE)

    def test_all_orientations_are_bijective_and_known_corners_correct(self):
        expected = {"identity": (0, 0), "cw90": (0, 19), "rotate180": (19, 19), "ccw90": (19, 0),
                    "mirror_x": (0, 19), "mirror_y": (19, 0), "transpose": (0, 0), "anti_transpose": (19, 19)}
        for orientation in ORIENTATIONS:
            self.assertEqual(transform_cell(0, 0, orientation), expected[orientation])
            self.assertEqual(len({transform_cell(r, c, orientation) for r in range(20) for c in range(20)}), 400)
        with self.assertRaises(ValueError):
            transform_cell(0, 0, "unknown")

    def test_inverted_and_rotated_patterns_match_source_cells(self):
        raw = self.book.frame(0, 17, 43)
        for orientation in ORIENTATIONS:
            pattern = self.book.pattern(0, 17, 43, orientation, False)
            for unit in range(400):
                row, column = transform_cell(*divmod(unit, 20), orientation)
                self.assertEqual(int(pattern.rows[row][column]), 1 - ((raw[unit // 8] >> (unit % 8)) & 1))

    def test_payload_sources_limits_and_strict_hex(self):
        self.assertEqual(payload_bytes("fixed", "A5", ""), b"\xa5")
        self.assertEqual(payload_bytes("hex", "00", "00,11; AA FF"), b"\0\x11\xaa\xff")
        self.assertEqual(payload_bytes("sweep", "00", ""), bytes(range(256)))
        self.assertEqual(payload_bytes("file", "00", "", b"\x80\xff"), b"\x80\xff")
        for value in ("", "A", "0x00", "0G", "-1"):
            with self.assertRaises(ValueError):
                payload_bytes("hex", "00", value)
        for value in ("100", "-1", "GG", ""):
            with self.assertRaises(ValueError):
                parse_symbol(value)
        with self.assertRaises(ValueError):
            payload_bytes("file", "00", "", None)
        file = self.path / "payload.bin"
        file.write_bytes(b"x" * (MAX_PAYLOAD + 1))
        with self.assertRaises(ValueError):
            read_payload(file)

    def test_indices_are_checked(self):
        for args in ((1, 0, 0), (0, 256, 0), (0, 0, 256), (False, 0, 0)):
            with self.assertRaises(ValueError):
                self.book.frame(*args)

    def test_export_reconstructs_every_symbol_and_all_controller_bits(self):
        target = self.path / "plan.zip"
        manifest = export_plan(target, self.book, self.mapping, 0, "identity", True, 7, False, b"\x00\xff\xa5")
        self.assertFalse(manifest["transport_ready"])
        self.assertEqual(manifest["dictionary_frames"], 1119)
        self.assertEqual(manifest["event_records"], 26103)
        with zipfile.ZipFile(target) as archive:
            self.assertEqual(archive.read("payload.bin"), b"\x00\xff\xa5")
            self.assertEqual(json.loads(archive.read("manifest.json"))["repeats_per_symbol"], 7)
            dictionary = archive.read("patterns.bin")
            events = archive.read("events.bin")
            index = json.loads(archive.read("symbol_index.json"))
            for line in archive.read("SHA256SUMS.txt").decode().splitlines():
                digest, name = line.split()
                self.assertEqual(hashlib.sha256(archive.read(name)).hexdigest(), digest)
        expected_cache = {}
        for symbol, item in enumerate(index):
            q, previous = 0, None
            for offset in range(item["first_record"], item["first_record"] + item["record_count"]):
                frame_id, duration = struct.unpack_from("<HH", events, offset * 4)
                self.assertGreater(duration, 0)
                self.assertNotEqual(frame_id, previous)
                previous = frame_id
                actual = dictionary[frame_id * 50:(frame_id + 1) * 50]
                for slot in range(q, q + duration):
                    raw = self.book.frame(0, symbol, slot)
                    if raw not in expected_cache:
                        expected_cache[raw] = compile_frame(self.book.pattern(0, symbol, slot), self.mapping)
                    self.assertEqual(actual, expected_cache[raw])
                q += duration
            self.assertEqual(q, 256)

    def test_export_rotated_low_polarity_and_source_protection(self):
        target = self.path / "rotated.zip"
        export_plan(target, self.book, self.mapping, 0, "cw90", False, 3, True, b"\x01")
        with zipfile.ZipFile(target) as archive:
            dictionary, events = archive.read("patterns.bin"), archive.read("events.bin")
            index = json.loads(archive.read("symbol_index.json"))
            record = index[17]["first_record"]
            frame_id, _duration = struct.unpack_from("<HH", events, record * 4)
            expected = compile_frame(self.book.pattern(0, 17, 0, "cw90", False), self.mapping)
            self.assertEqual(dictionary[frame_id * 50:(frame_id + 1) * 50], expected)
        before = EXAMPLE.read_bytes()
        with self.assertRaisesRegex(ValueError, "不能覆盖"):
            export_plan(EXAMPLE, self.book, self.mapping, 0, "identity", True, 3, True, b"x")
        self.assertEqual(EXAMPLE.read_bytes(), before)

    def test_partial_mapping_export_leaves_existing_file_intact(self):
        target = self.path / "existing.zip"
        target.write_bytes(b"existing content")
        mapping = self.mapping.copy()
        mapping.unbind(1)
        with self.assertRaises(ValueError):
            export_plan(target, self.book, mapping, 0, "identity", True, 3, True, b"x")
        self.assertEqual(target.read_bytes(), b"existing content")

    def test_export_rejects_boolean_strings_before_writing(self):
        target = self.path / "bad.zip"
        for polarity, loop in (("false", True), (True, "false")):
            with self.assertRaisesRegex(ValueError, "布尔"):
                export_plan(target, self.book, self.mapping, 0, "identity", polarity, 3, loop, b"x")
            self.assertFalse(target.exists())


if __name__ == "__main__":
    unittest.main()
