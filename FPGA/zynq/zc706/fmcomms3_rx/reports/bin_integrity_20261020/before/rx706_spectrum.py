"""Bounded, read-only FFT analysis of little-endian I1 Q1 I2 Q2 captures."""
from __future__ import annotations

from dataclasses import dataclass
import json
import math
from pathlib import Path


class AnalysisCancelled(Exception):
    pass


@dataclass
class Spectrum:
    path: Path
    channel: int
    sample_rate_hz: float
    rate_source: str
    lo_hz: float | None
    first_tuple: int
    total_tuples: int
    nfft: int
    averages: int
    remove_dc: bool
    frequency_hz: object
    dbfs: object
    peak_hz: float | None
    peak_dbfs: float | None
    rms_counts: float
    clipped: int

    @property
    def samples(self):
        return self.nfft * self.averages


def _cancel(event):
    if event is not None and event.is_set():
        raise AnalysisCancelled("频谱分析已停止")


def _metadata(path, size, fallback_rate):
    sidecar = Path(str(path) + ".json")
    if not sidecar.exists():
        return fallback_rate, "手动设置（没有同名 JSON）", None
    try:
        if sidecar.stat().st_size > 1024 * 1024:
            raise ValueError("JSON 超过 1 MiB")
        meta = json.loads(sidecar.read_text(encoding="utf-8"))
        capture = meta["capture"]
        if (meta.get("complete") is not True or meta["file_bytes"] != size
                or capture["bytes"] != size or capture["tuples"] != size // 8
                or capture["order"] != ["I1", "Q1", "I2", "Q2"]
                or capture["dtype"] != "int16" or capture["byte_order"] != "little"
                or capture["channels"] != 2 or capture["valid_bits"] != 12):
            raise ValueError("文件长度、完成标记或 IQ 格式不匹配")
        rate = float(capture["sample_rate_hz"])
        lo = capture.get("rx_lo_config_hz")
        if lo is not None:
            lo = float(lo)
            if not math.isfinite(lo) or lo <= 0:
                raise ValueError("无效的 LO 配置值")
        if not math.isfinite(rate) or rate <= 0:
            raise ValueError("无效的采样率")
        return rate, "同名 JSON", lo
    except (ValueError, KeyError, TypeError, OverflowError) as exc:
        raise ValueError(f"同名 JSON 无效：{exc}") from exc


def analyze_bin(filename, *, channel=1, nfft=65536, averages=16, first_tuple=0,
                sample_rate_hz=15360000, remove_dc=True, cancel_event=None):
    """Average nonoverlapping Hann-windowed complex FFTs in linear power.

    Only one FFT block is read at a time. For a bin-centred complex sinusoid
    with I/Q amplitude 2048 counts, the peak is 0 dBFS. This is a coherent-gain
    corrected bin spectrum, not a PSD or calibrated RF power measurement.
    Metadata supplies Fs when available; otherwise the explicit fallback wins.
    """
    _cancel(cancel_event)
    import numpy as np

    path = Path(filename).expanduser()
    if path.name.endswith(".part"):
        raise ValueError("请选择下载完成的 bin 文件，不能分析 .part")
    if channel not in (1, 2):
        raise ValueError("通道必须是 RX1 或 RX2")
    if type(nfft) is not int or not 256 <= nfft <= 1048576 or nfft & (nfft - 1):
        raise ValueError("FFT 点数必须是 256～1048576 之间的 2 次幂")
    if type(averages) is not int or not 1 <= averages <= 64:
        raise ValueError("平均段数必须是 1～64")
    if type(first_tuple) is not int or first_tuple < 0:
        raise ValueError("起始点必须是非负整数（每通道采样点）")
    sample_rate_hz = float(sample_rate_hz)
    if not math.isfinite(sample_rate_hz) or sample_rate_hz <= 0:
        raise ValueError("采样率必须是正的有限数值")
    # Open only once: the size and samples refer to the same file handle.
    with path.open("rb") as stream:
        stream.seek(0, 2)
        size = stream.tell()
        if not size or size % 8:
            raise ValueError("bin 长度必须是 8 字节的正整数倍（I1/Q1/I2/Q2）")
        rate, source, lo = _metadata(path, size, sample_rate_hz)
        available = size // 8 - first_tuple
        if available < 256:
            raise ValueError("起始位置之后至少需要 256 个 IQ 采样点")
        nfft = min(nfft, 1 << (available.bit_length() - 1))
        averages = min(averages, available // nfft)
        stream.seek(first_tuple * 8)
        window = np.hanning(nfft + 1)[:-1]  # periodic Hann, coherent gain 0.5
        scale = float(window.sum()) ** 2
        power = np.zeros(nfft, dtype=np.float64)
        energy, clipped = 0.0, 0
        for _ in range(averages):
            _cancel(cancel_event)
            raw = np.fromfile(stream, dtype="<i2", count=nfft * 4)
            if raw.size != nfft * 4:
                raise ValueError("文件在分析期间被截短")
            iq = raw.reshape(-1, 4)[:, (channel - 1) * 2:channel * 2]
            if np.any((iq < -2048) | (iq > 2047)):
                raise ValueError("所选通道包含超出 12 位符号扩展范围的数据，请检查 bin 格式")
            clipped += int(np.count_nonzero(np.any((iq <= -2048) | (iq >= 2047), axis=1)))
            x = iq[:, 0].astype(np.float64) + 1j * iq[:, 1].astype(np.float64)
            energy += float(np.vdot(x, x).real)
            if remove_dc:
                x -= x.mean()
            transformed = np.fft.fft((x / 2048.0) * window)
            power += (transformed.real ** 2 + transformed.imag ** 2) / scale
        _cancel(cancel_event)
        stream.seek(0, 2)
        if stream.tell() != size:
            raise ValueError("文件长度在分析期间发生变化，请使用下载完成的文件")
    power = np.fft.fftshift(power / averages)
    frequencies = np.fft.fftshift(np.fft.fftfreq(nfft, 1.0 / rate))
    dbfs = 10.0 * np.log10(np.maximum(power, 1e-18))
    peak = int(np.argmax(power))
    has_peak = power[peak] > 1e-18
    return Spectrum(path, channel, rate, source, lo, first_tuple, size // 8, nfft, averages,
                    remove_dc, frequencies, dbfs,
                    float(frequencies[peak]) if has_peak else None,
                    float(dbfs[peak]) if has_peak else None,
                    math.sqrt(energy / (nfft * averages)), clipped)


def display_trace(result, max_points=8192):
    """Preserve the strongest bin in each display bucket; analysis stays full-size."""
    import numpy as np
    count = len(result.dbfs)
    width = max(1, (count + max_points - 1) // max_points)
    starts = np.arange(0, count, width)
    powers = np.maximum.reduceat(result.dbfs, starts)
    # Bucket centres keep the plotted frequency axis monotonic.
    centres = np.minimum(starts + width // 2, count - 1)
    return result.frequency_hz[centres] / 1e6, powers
