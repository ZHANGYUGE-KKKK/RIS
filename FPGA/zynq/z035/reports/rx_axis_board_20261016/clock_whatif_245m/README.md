# Routed receiver clock audit

This audit opened the previously built `pz7035_top_routed.dcp` in a separate Vivado session, then replaced only the in-memory `rfmc_rx` period with 4.069010 ns (Vivado rounds to 4.069 ns). No RTL, active constraints, project, checkpoint, BIT, LTX, or XSA was modified. Reproduce using `scripts/check_rx_clock_whatif.tcl`.

The implemented path is `rx_clk_p/n` R27/T27 → `u_clock_input` IBUFDS at IOB_X0Y222 → `u_rx_clock` BUFG at BUFGCTRL_X0Y19 → all seven IDDR clock inputs and RX logic. There is no PLL/MMCM or divider on this path. `physical_clock_path.txt` and the expanded timing reports show the exact path.

The pin map independently matches the local schematics:

- `/home/yyz/ALLdoc/zynq035/ad-fmcomms3_reva.pdf`, page 3: DATA_CLK_P/N are FMC G6/G7 (test points TP212/TP213).
- `/home/yyz/ALLdoc/zynq035/05.开发板原理图/璞致PZ7035-FH PZ7045-FH PZ7100-FH平台开发板原理图.pdf`, page 18: FMC G6/G7 (LA00_P_CC/LA00_N_CC) map to FPGA R27/T27.

At the hypothetical 245.76 MHz clock, the existing placement/routing has WNS −2.736 ns and TNS −28.836 ns with 83 failing setup endpoints. Hold remains +0.054 ns. All setup failures belong to:

| Paths | Count | Worst slack | Worst data path |
|---|---:|---:|---:|
| RX synchronized reset distribution, including IDDR half-cycle reset checks | 61 | −2.736 ns | 4.200 ns at worst-slack endpoint |
| FRAME IDDR → sample-data clock enable | 22 | −0.210 ns | 3.763 ns |

The frequency counters have substantial steady-state timing margin even under this hypothetical clock:

| Counter | Worst setup slack | Data path delay |
|---|---:|---:|
| `edge_counter_rx[23:0]` | +2.772 ns | 1.309 ns |
| ADI `up_clock_mon.d_count[32:0]` | +2.152 ns | 1.904 ns |

These results do not measure the physical DATA_CLK frequency or exclude irregular/short input pulses. They do show that a regular 170–245.76 MHz clock alone is insufficient evidence for binary-counter carry failure. The ADI clock monitor has no failing endpoint in the complete hypothetical RX-domain setup analysis.

A 24-bit modulo counter sampled every 100 ms wraps more than once above 167.77216 MHz: for example 184.32 MHz would be misreported as 16.54784 MHz by a single modulo subtraction over that window. Five-millisecond subwindows avoid this ambiguity. The independent ADI clock monitor uses a 16-bit UP-clock measurement window and a 33-bit device counter, offering a separate cross-check.

If a further diagnostic image becomes necessary, explicit high-performance IBUF mode (`IBUF_LOW_PWR=FALSE`) plus conservative 4.069 ns implementation constraints is a useful controlled comparison without changing SPI, VCCO, or termination. An independent 200 MHz sampler of raw clock level has aliasing above 100 MHz; for frequency measurement, a small RX-clock prescaler synchronized into the reference domain is preferable. Neither method replaces analog signal-integrity observation.
