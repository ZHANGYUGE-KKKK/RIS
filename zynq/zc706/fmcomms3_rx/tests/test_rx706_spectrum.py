"""Scientific checks using known complex tones, raw interleaving and sparse DDR files."""
import json
from pathlib import Path
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "host"))
from rx706_spectrum import AnalysisCancelled, analyze_bin, display_trace

FS = 15360000
N = 4096


def tones(count=N, amp1=1024, amp2=512, bin1=525, bin2=-256, dc=0):
    t = np.arange(count)
    x = amp1 * np.exp(2j * np.pi * bin1 * t / N) + dc
    y = amp2 * np.exp(2j * np.pi * bin2 * t / N)
    return np.rint(np.column_stack((x.real, x.imag, y.real, y.imag))).astype("<i2")


class SpectrumTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.path = Path(self.directory.name) / "capture.bin"

    def tearDown(self):
        self.directory.cleanup()

    def metadata(self, **changes):
        size = self.path.stat().st_size
        capture = dict(bytes=size, tuples=size // 8, order=["I1", "Q1", "I2", "Q2"],
                       dtype="int16", byte_order="little", channels=2, valid_bits=12,
                       sample_rate_hz=FS, rx_lo_config_hz=915000000)
        capture.update(changes)
        meta = dict(complete=True, file_bytes=size, capture=capture)
        Path(str(self.path) + ".json").write_text(json.dumps(meta))

    def test_signed_frequency_iq_order_and_full_scale(self):
        tones().tofile(self.path)
        self.metadata()
        for channel, bin_index, expected_dbfs in [(1, 525, -6.0206), (2, -256, -12.0412)]:
            result = analyze_bin(self.path, channel=channel, nfft=N, sample_rate_hz=1)
            self.assertEqual(result.peak_hz, bin_index * FS / N)
            self.assertAlmostEqual(result.peak_dbfs, expected_dbfs, delta=0.015)
            self.assertEqual(result.sample_rate_hz, FS)  # metadata overrides manual Fs
            self.assertEqual(result.clipped, 0)
            self.assertEqual(result.lo_hz, 915000000)

    def test_averages_linear_power_not_db_or_amplitude(self):
        np.concatenate((tones(amp1=1024), tones(amp1=512))).tofile(self.path)
        result = analyze_bin(self.path, nfft=N, averages=2)
        self.assertEqual(result.averages, 2)
        expected = 10 * np.log10(((1024 / 2048) ** 2 + (512 / 2048) ** 2) / 2)
        self.assertAlmostEqual(result.peak_dbfs, expected, delta=0.015)

    def test_2p4_ghz_metadata_keeps_unsigned_lo_and_baseband_peak(self):
        tones().tofile(self.path)
        self.metadata(rx_lo_config_hz=2_400_000_000)
        result = analyze_bin(self.path, nfft=N)
        self.assertEqual(result.lo_hz, 2_400_000_000)
        self.assertEqual(result.peak_hz, 525 * FS / N)
        self.assertEqual(result.lo_hz + result.peak_hz, 2_401_968_750)

    def test_dc_removal_and_raw_rms(self):
        tones(amp1=100, bin1=123, dc=900).tofile(self.path)
        raw = analyze_bin(self.path, nfft=N, remove_dc=False)
        clean = analyze_bin(self.path, nfft=N, remove_dc=True)
        self.assertEqual(raw.peak_hz, 0)
        self.assertEqual(clean.peak_hz, 123 * FS / N)
        self.assertAlmostEqual(raw.rms_counts, clean.rms_counts)
        self.assertLess(clean.dbfs[N // 2], -100)

    def test_start_offset_short_file_and_tail(self):
        np.concatenate((tones(amp1=100, bin1=1), tones(count=N+37))).tofile(self.path)
        result = analyze_bin(self.path, first_tuple=N, nfft=65536, averages=16)
        self.assertEqual(result.first_tuple, N)
        self.assertEqual(result.nfft, N)
        self.assertEqual(result.samples, N)
        self.assertEqual(result.total_tuples, N*2+37)
        self.assertEqual(result.peak_hz, 525 * FS / N)

    def test_clipping_and_malformed_samples(self):
        data = tones()
        data[0, :2] = [-2048, 2047]  # count this tuple once
        data[1, 1] = 2047
        data.tofile(self.path)
        self.assertEqual(analyze_bin(self.path, nfft=N).clipped, 2)
        data[2, 0] = 4095
        data.tofile(self.path)
        with self.assertRaisesRegex(ValueError, "12 位"):
            analyze_bin(self.path, nfft=N)
        self.assertEqual(analyze_bin(self.path, channel=2, nfft=N).clipped, 0)

    def test_near_gib_capture_reads_only_requested_blocks(self):
        size = 1020 * 1048576
        with self.path.open("wb") as stream:
            stream.truncate(size)  # sparse; no GiB allocation or full-file read
            stream.seek(size - 2*N*8)
            stream.write(tones(count=2*N).tobytes())
        original = np.fromfile
        counts = []

        def bounded_read(*args, **kwargs):
            counts.append(kwargs["count"])
            return original(*args, **kwargs)

        with patch.object(np, "fromfile", side_effect=bounded_read):
            result = analyze_bin(self.path, first_tuple=size//8-2*N, nfft=N, averages=16)
        self.assertEqual(counts, [N*4, N*4])
        self.assertEqual(result.samples * 8, 65536)
        self.assertEqual(result.peak_hz, 525 * FS / N)

    def test_malformed_error_locates_later_block_and_channel(self):
        data = tones(count=3*N)
        sample = 2*N + 7
        data[sample, 3] = -2059
        data.tofile(self.path)
        with self.assertRaises(ValueError) as caught:
            analyze_bin(self.path, channel=2, first_tuple=N, nfft=N, averages=2)
        message = str(caught.exception)
        offset = sample * 8 + 6
        self.assertIn(f"RX2 Q2 采样点 {sample}", message)
        self.assertIn(f"文件偏移 {offset}（0x{offset:X}）", message)
        self.assertIn("-2059（0xF7F5）", message)
        # An invalid RX2 sample must not reject an otherwise valid RX1 trace.
        self.assertEqual(analyze_bin(self.path, channel=1, first_tuple=N,
                                     nfft=N, averages=2).samples, 2*N)

    def test_incomplete_wrong_metadata_and_invalid_inputs_rejected(self):
        tones().tofile(self.path)
        for changes in [dict(byte_order="big"), dict(tuples=N-1),
                        dict(sample_rate_hz=0), dict(valid_bits=16)]:
            self.metadata(**changes)
            with self.assertRaises(ValueError):
                analyze_bin(self.path)
        self.metadata()
        sidecar = Path(str(self.path) + ".json")
        meta = json.loads(sidecar.read_text())
        meta["complete"] = False
        sidecar.write_text(json.dumps(meta))
        with self.assertRaises(ValueError):
            analyze_bin(self.path)
        sidecar.unlink()
        for options in [dict(nfft=1000), dict(averages=0), dict(averages=65),
                        dict(first_tuple=N-1), dict(first_tuple=-1), dict(channel=0),
                        dict(sample_rate_hz=float("nan"))]:
            with self.assertRaises(ValueError):
                analyze_bin(self.path, **options)
        with self.assertRaisesRegex(ValueError, r"\.part"):
            analyze_bin(str(self.path) + ".part")
        self.path.write_bytes(b"bad size")  # one tuple, insufficient FFT data
        with self.assertRaises(ValueError):
            analyze_bin(self.path)

    def test_cancellation_zero_data_and_peak_preserving_display(self):
        stopped = threading.Event()
        stopped.set()
        with self.assertRaises(AnalysisCancelled):
            analyze_bin(self.path, cancel_event=stopped)
        np.zeros((N, 4), dtype="<i2").tofile(self.path)
        silence = analyze_bin(self.path, nfft=N)
        self.assertIsNone(silence.peak_hz)
        self.assertTrue(np.all(np.isfinite(silence.dbfs)))
        tones().tofile(self.path)
        result = analyze_bin(self.path, nfft=N)
        freq, dbfs = display_trace(result, max_points=100)
        self.assertLessEqual(len(freq), 100)
        self.assertAlmostEqual(float(dbfs.max()), result.peak_dbfs)
        self.assertTrue(np.all(np.diff(freq) > 0))


if __name__ == "__main__":
    unittest.main(verbosity=2)
