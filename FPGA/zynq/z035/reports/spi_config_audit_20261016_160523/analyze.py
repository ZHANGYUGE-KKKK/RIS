from pathlib import Path
from fractions import Fraction
import hashlib
import json
import re
import struct

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]


def words(name):
    data = (OUT / name).read_bytes()
    return struct.unpack('<%dI' % (len(data) // 4), data)


before, after = words('spi_baseline.bin'), words('spi_final.bin')
header = words('header_trials.bin')
final_header = words('header_final.bin')
raw = words('rows_trials.bin')
source = ROOT / 'zynq/z035/config915'
expected = {}
for a, v in re.findall(r'^SPIWrite\s+([0-9A-Fa-f]+),([0-9A-Fa-f]+)', source.read_text(), re.M):
    expected[int(a, 16)] = int(v, 16)
# Explicit board/executor adaptations after the exported script.
expected.update({0x009: 7, 0x014: 0x23, 0x292: 8, 0x293: 0x80, 0x294: 0,
                 0x3f4: 0x53, 0x3f5: 0, 0x3f6: 0x30})
checked = [2, 3, 4, 6, 7, 9, 10, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15,
           0x3c, 0x3d, 0x3e, 0x41, 0x42, 0x43, 0x44, 0x45,
           0x292, 0x293, 0x294, 0x2ab, 0x2ac, 0x3f4, 0x3f5, 0x3f6]
checks = {f'{a:03X}': {'actual': before[a], 'expected': expected.get(a),
                       'matches': before[a] == expected.get(a)} for a in checked}

bbpll = 40000000 * (before[0x44] + Fraction(
    before[0x41] << 16 | before[0x42] << 8 | before[0x43], 2088960))
adc = bbpll / (1 << (before[0xa] & 7))
dac = adc / (1 + ((before[0xa] >> 3) & 1))


def stages(rate, filt):
    values = [float(rate)]
    for d in [1 + ((filt >> 4) & 3), 1 + ((filt >> 3) & 1),
              1 + ((filt >> 2) & 1), 1 << max(0, (filt & 3) - 1)]:
        rate /= d
        values.append(float(rate))
    return values


trials = []
for n in range(header[6]):
    r = raw[32 * n:32 * (n + 1)]
    trials.append({'index': n, 'reg010': f'{r[1]:02X}', 'reg03d': f'{r[2]:02X}',
                   'reg03e': f'{r[3]:02X}', 'reg006': f'{r[4]:02X}',
                   'pn_result': r[5] if r[5] < 2**31 else r[5] - 2**32,
                   'channel_status': list(r[6:10]), 'sample_delta': r[10],
                   'edge_delta': r[11], 'estimated_rx_mhz':
                       r[12] * 333333343 / r[13] / 1e6})

changed = [6, 0x10, 0x3d, 0x3e, 0x3f4, 0x3f5, 0x3f6]
restored = all(before[a] == after[a] for a in changed)
delays_unchanged = words('header_baseline.bin')[16:23] == final_header[16:23]
result = {'register_checks': checks, 'bbpll_hz': float(bbpll),
          'rx_clock_stages_hz': stages(adc, before[3]),
          'tx_clock_stages_hz': stages(dac, before[2]),
          'pll_locks': {'bbpll': bool(before[0x5e] & 0x80),
                        'rx': bool(before[0x247] & 2), 'tx': bool(before[0x287] & 2)},
          'trials': trials, 'pn_pass_count': header[7],
          'restore_result': header[5], 'changed_spi_restored': restored,
          'fpga_delays_unchanged': delays_unchanged,
          'final_arm': final_header[10], 'final_flags': final_header[11],
          'core_control': final_header[9], 'pn_select': list(final_header[24:28])}
(OUT / 'analysis.json').write_text(json.dumps(result, indent=2) + '\n')
hashes = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
          for p in [source, ROOT / 'zynq/z035/vitis_code/key_ctrlll/Debug/key_ctrlll.elf',
                    ROOT / 'zynq/z035/PZ_UART.srcs/sources_1/new/ad9361_rx_axis.v',
                    ROOT / 'zynq/z035/PZ_UART.srcs/sources_1/new/ad9361_rx_lvds_if.v']}
(OUT / 'artifact_hashes.json').write_text(json.dumps(hashes, indent=2) + '\n')
print(json.dumps(result, indent=2))
assert all(c['matches'] for c in checks.values()), 'SPI differs from active configuration'
assert restored and delays_unchanged and header[5] == 0
assert final_header[10] == 0 and final_header[11] & ~2 == 1
assert header[6] == 4
