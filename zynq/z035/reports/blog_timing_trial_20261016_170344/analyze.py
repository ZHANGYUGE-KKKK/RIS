#!/usr/bin/env python3
"""Decode the saved board experiment; does not access hardware."""
import collections
import csv
import hashlib
import itertools
import json
from pathlib import Path
import struct

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def words(name):
    raw = (HERE / name).read_bytes()
    assert len(raw) % 4 == 0
    return list(struct.unpack(f"<{len(raw) // 4}I", raw))


def signed(value):
    return value if value < (1 << 31) else value - (1 << 32)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


baseline = words("header_baseline.bin")
trial = words("header_trials.bin")
final = words("header_final.bin")
spi_before = words("spi_baseline.bin")
spi_after = words("spi_final.bin")
raw = words("rows_trials.bin")
assert len(raw) % 32 == 0
rows = [raw[i:i + 32] for i in range(0, len(raw), 32)]
assert len(rows) == trial[6] == 100
assert all(h[0] == 0x424C4F47 and h[1] == 1 for h in (baseline, trial, final))
assert trial[3] == trial[5] == 0
assert all(h[10] == 0 and not (h[11] & 0x3C) for h in (baseline, trial, final))
assert baseline[16:23] == final[16:23] == [0] * 7
assert baseline[8:10] == final[8:10] == [3, 0]
assert spi_before == spi_after
assert all(r[21] == 0x10 and not (r[17] & 0x3C) for r in rows)
assert all(r[26] == 0x80 for r in rows)
assert [r[0] for r in rows] == list(range(len(rows)))
cases = [r for r in rows if r[25] == 1]
assert len(cases) == 96
expected = set(itertools.product(range(2), range(4), (0x0F, 0x04, 0x88), range(4)))
assert {(r[1], r[2], r[3], r[4]) for r in cases} == expected
for r in cases:
    assert r[18] == (spi_before[0x010] ^ r[1])
    assert r[19] == ((spi_before[0x011] & ~3) | r[4])
    assert r[20] == r[3]
    assert r[22] == (10 if r[2] else baseline[16])
    assert r[23] == (10 if r[2] == 3 else baseline[22])
pn_rows = [r for r in rows if r[24]]
assert len(pn_rows) == 99
assert all(r[24] == 10000 and r[27] == 9 for r in pn_rows)
assert all(r[10] >= 32 and r[11] >= 128 for r in pn_rows)
assert all(signed(r[5]) == -4 and r[6:10] == [2] * 4 for r in pn_rows)
assert trial[7] == 0
assert rows[-1][25] == 3 and rows[-1][27] == spi_before[0x3F4]
assert "BLOG_TIMING_TRIAL_COMPLETE" in (HERE / "trial.log").read_text()

names = [
    "index", "clock_inverted", "fpga_pattern", "requested_006", "data_slip",
    "pn_result", "ch0_status", "ch1_status", "ch2_status", "ch3_status",
    "pn_sample_delta", "pn_edge_delta", "count_edges", "timer_ticks",
    "clockmon", "clockratio", "accumulated_axi_status", "gpio_status",
    "actual_010", "actual_011", "actual_006", "actual_012", "data0_taps",
    "frame_taps", "pn_observe_us", "kind", "bbpll_status_05e", "bist_3f4",
    "reserved28", "reserved29", "reserved30", "reserved31",
]
with (HERE / "trial_points.csv").open("w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(names + ["internal_edge_estimate_mhz"])
    for row in rows:
        decoded = row.copy()
        decoded[5] = signed(row[5])
        writer.writerow(decoded + [row[12] * 333333343 / row[13] / 1e6])

previous = {}
for report, key in (
    ("rx_sampling_check_20261016_150939/artifact_hashes.json", None),
    ("spi_config_audit_20261016_160523/artifact_hashes.json", None),
    ("rx_incremental_stage1_20261016/verification.json", "source_sha256"),
    ("lvds_constraint_audit_20261016/verification.json", "source_sha256"),
):
    data = json.loads((HERE.parent / report).read_text())
    previous.update(data[key] if key else data)
hashes = {name: sha(ROOT / name) for name in previous}
assert hashes == previous, "An existing project artifact differs from its latest saved hash"
(HERE / "artifact_hashes.json").write_text(json.dumps(hashes, indent=2) + "\n")

summary = {
    "article_url": "https://blog.csdn.net/weixin_42550052/article/details/160432413",
    "unique_trial_combinations": len(cases),
    "baseline_prbs_checks": sum(r[25] == 0 for r in rows),
    "prbs_checks_total": len(pn_rows),
    "prbs_passes": trial[7],
    "prbs_return_codes": dict(collections.Counter(signed(r[5]) for r in pn_rows)),
    "all_four_channels_pn_out_of_sync": True,
    "post_restore_rf_rows": 1,
    "rows_total": len(rows),
    "all_observed_012_values": sorted({r[21] for r in rows}),
    "all_observed_05e_values": sorted({r[26] for r in rows}),
    "spi_snapshot_addresses": "0x000..0x05f and 0x3f4..0x3f6 (99 registers)",
    "spi_snapshot_identical_before_after": spi_before == spi_after,
    "all_seven_fpga_taps_before": baseline[16:23],
    "all_seven_fpga_taps_after": final[16:23],
    "restore_result": trial[5],
    "final_arm": final[10],
    "final_gpio_status": final[11],
    "gpio_status_observed": sorted({r[17] for r in rows}),
    "project_artifact_hash_checks": len(hashes),
    "all_project_artifact_hashes_match_previous_records": True,
    "scope": "Original FPGA image and ARM firmware; temporary DDR diagnostic calls existing SPI, IDELAY and PN functions; no new ILA or DMA capture",
    "limit": "No passing PRBS point in these combinations; this does not exclude other timing, electrical, format or checker problems. Internal edge estimates are not pin-frequency measurements.",
}
(HERE / "analysis.json").write_text(json.dumps(summary, indent=2) + "\n")
print(json.dumps(summary, indent=2))
