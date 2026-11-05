# AD9361 RX board image build — 2026-10-16

The rewritten receiver and independent ARM=0 diagnostics were built from RTL SHA256 `9e18a38d233bf723319d35c09968da39f2be7d5b9f4a50f992844a19c2e5979e`. Vivado 2020.2 regenerated the BD in the private snapshot `/tmp/ad9361_rx_validation_68_1792144654`, synthesized the complete `pz7035_top`, implemented the five-probe ILA, placed and routed the design, and exported BIT/LTX/XSA. The active GUI project was not used for implementation. No hardware programming was performed by this build.

Published artifacts:

| Artifact | Canonical path relative to `zynq/z035` | SHA256 |
|---|---|---|
| BIT | `PZ_UART.runs/impl_1/pz7035_top.bit` | `f589670ea1b5656d9d44f17854c3ceca053a18b6fca33e8b0d0cc0260e3d331b` |
| LTX | `PZ_UART.runs/impl_1/pz7035_top.ltx` | `f0c1b8a4027b3393bcd4d745635ae144bcec0f9c73b6a198bcdded8c6f628f81` |
| XSA | `pz7035_top.xsa` | `116014f6aa08bdd908ef0f83317725f5eaafead4feee057f298faa00ad549d99` |

All three previous canonical files were backed up to `backups/before_rx_board_publish_20261016_180747` before replacement. `published_artifacts.json` records provenance and paths. Matching copies are retained in this report directory.

The initial strict whole-file BIT comparison correctly stopped publication: `write_hw_platform -include_bit` reruns bitgen, so the two BIT headers contained times `18:05:54` and `18:06:08`. Their complete 13,321,404-byte FPGA configuration payloads, device, and design metadata match. `pz7035_top.pre_xsa.bit` preserves the first export; `bitstream_comparison.json` records payload hashes and both timestamps. The published standalone BIT is now byte-for-byte identical to the BIT embedded in the XSA. The XSA HWH also matches the newly generated snapshot HWH byte-for-byte. The reusable build/publication scripts handle this timestamp behavior explicitly.

Implementation checks:

- Routed WNS +0.183 ns, WHS +0.054 ns; TNS and THS zero. All existing user-specified timing constraints are met.
- All 43,073 routable nets are fully routed; zero routing errors.
- Worst reported bus-skew slack +4.101 ns; no failing bus-skew constraints.
- CDC report contains no Critical entries. Remaining warnings are vendor control/handshake structures, ILA synchronization, and MIG reset synchronization; see `cdc.rpt` for exact paths.
- Routed DRC: zero errors or Critical Warnings, two warnings (MIG clock-output buffering, loadless vendor/debug nets), two DMA BRAM advisories. The synthesis-only MIG PLIDC-2 warning is absent after implementation.
- No unclocked registers or unconstrained internal endpoints. Existing external constraints still omit input delays for the RX data/FRAME pins among 13 inputs, and output delays on 26 outputs; the timing result is not a complete board-level LVDS timing signoff. See `check_timing.rpt`; on-board PN and frame continuity measurements remain necessary.
- All 171 receiver ILA bits were checked against the implemented LTX, including exact probe index, width, bus name, and each bit connection. UUID: `ABD3947756075108AE30C8BE393E8055`.

ILA clock is AXIS 100 MHz. Probes are `debug_axis_data[63:0]`, `debug_axis_flags[9:0]`, `debug_sample_count[23:0]`, `debug_clock_count[23:0]`, and `debug_raw_rx[48:0]`. The raw observation probe is valid at bit48, with a coherent 48-bit RX record below it: bits47:32 contain DATA_CLK counter15:0; bits31:26 contain counter21:16; bits25:22 are delay-ready, frame-fault, sample-valid, frame-lock; bits21:14 are frame history; bits13:7 and6:0 are the early/late seven-bit FRAME+DATA samples. The record counter is reconstructed as `{record[31:26],record[47:32]}`.

Reproduce from the project root with:

```sh
/home/yyz/vivado2020.2/main/Vivado/2020.2/bin/vivado -mode batch -nojournal \
  -log reports/rx_axis_board_20261016/build.log \
  -source scripts/build_ad9361_rx_board.tcl \
  -tclargs /home/yyz/work/RIS/zynq/z035/reports/rx_axis_board_20261016
```

`scripts/build_ad9361_rx_board.tcl` creates a fresh isolated snapshot and calls `scripts/publish_ad9361_rx_board.py` only after implementation checks. Original XPR GUI-run metadata is deliberately unchanged; canonical artifacts and their manifest are the source of truth for programming.
