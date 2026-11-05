import hashlib
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from compile_qam_plan import compile_plan, emit_plan


class PlanTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name)
        self.source = ROOT / "build/codebook_fixture/host_plan.zip"

    def changed(self, member, data, rehash=True):
        with zipfile.ZipFile(self.source) as archive:
            files = {name: archive.read(name) for name in archive.namelist()}
        files[member] = data
        if rehash:
            files["SHA256SUMS.txt"] = "".join(f"{hashlib.sha256(value).hexdigest()}  {name}\n"
                for name, value in files.items() if name != "SHA256SUMS.txt").encode()
        result = self.path / "changed.zip"
        with zipfile.ZipFile(result, "w") as archive:
            for name, value in files.items():
                archive.writestr(name, value)
        return result

    def test_native_frequency_rejected_without_rounding(self):
        with self.assertRaisesRegex(ValueError, "source timing incompatible"):
            compile_plan(self.source)

    def test_explicit_retiming_required(self):
        with self.assertRaisesRegex(ValueError, "retime-for-bench"):
            compile_plan(self.source, 60)
        with self.assertRaisesRegex(ValueError, "slot_ticks"):
            compile_plan(self.source, 30, True)

    def test_valid_upload_has_complete_tables_and_no_start(self):
        report, writes, frames, events, symbols, payload = compile_plan(self.source, 60, True)
        self.assertEqual((report["frames"], report["events"]), (1119, 26103))
        self.assertEqual(report["actual_pwm_hz"], 19531.25)
        self.assertTrue(report["retimed_for_bench"])
        self.assertFalse(report["transport_ready"])
        self.assertEqual([value for address, value in writes if address == 0x204], [16])
        self.assertEqual(len(frames), 1119 * 13)
        self.assertTrue(all(value < 65536 for value in frames[12::13]))
        self.assertEqual(len(symbols), 256)
        self.assertEqual(payload, bytes(range(256)))
        with zipfile.ZipFile(self.source) as archive:
            original = archive.read("patterns.bin")
        restored = b"".join(struct.pack("<13I", *frames[i:i + 13])[:50] for i in range(0, len(frames), 13))
        self.assertEqual(restored, original)

    def test_checksum_failure(self):
        path = self.changed("payload.bin", b"x", False)
        with self.assertRaisesRegex(ValueError, "checksum mismatch"):
            compile_plan(path, 60, True)

    def test_event_bounds_and_zero_duration(self):
        with zipfile.ZipFile(self.source) as archive:
            events = archive.read("events.bin")
        for event in [0, (1 << 16) | 2048]:
            with self.subTest(event=event):
                path = self.changed("events.bin", struct.pack("<I", event) + events[4:])
                with self.assertRaisesRegex(ValueError, "invalid event"):
                    compile_plan(path, 60, True)

    def test_symbol_period_and_range(self):
        with zipfile.ZipFile(self.source) as archive:
            index = json.loads(archive.read("symbol_index.json"))
        index[0]["record_count"] -= 1
        path = self.changed("symbol_index.json", json.dumps(index).encode())
        with self.assertRaisesRegex(ValueError, "period does not equal"):
            compile_plan(path, 60, True)
        index[0]["first_record"] = 65535
        path = self.changed("symbol_index.json", json.dumps(index).encode())
        with self.assertRaisesRegex(ValueError, "first event"):
            compile_plan(path, 60, True)

    def test_hardware_payload_capacity(self):
        path = self.changed("payload.bin", bytes(4097))
        with self.assertRaisesRegex(ValueError, "payload bytes"):
            compile_plan(path, 60, True)

    def test_output_cannot_overwrite(self):
        folder = self.path / "output"
        report = emit_plan(self.source, folder, 60, True)
        self.assertEqual(json.loads((folder / "manifest.json").read_text()), report)
        with self.assertRaises(FileExistsError):
            emit_plan(self.source, folder, 60, True)


if __name__ == "__main__":
    unittest.main()
