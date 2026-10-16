# RX FRAME 200 MHz 内部 ILA

`ila_rx_frame` 使用接收模块的 `ref_clk200`，当前 BD 接到 MIG `ui_clk`（200 MHz）。ILA 深度 2048，输入流水线 2 级。MIG 时钟及 debug hub 运行后，即使外部 AD9361 DATA_CLK 停止，也可以操作此 ILA。

RX 域锁存首次锁定后的 FRAME 错误上下文，通过 `xpm_cdc_handshake` 整体传到 200 MHz 域。若1048575个RX周期后仍未锁定，则改为锁存未锁定上下文，便于观察从未锁定时的实际FRAME序列。`diag_flags_ref[6]`区分原因：1为锁定后的首次故障，0为未锁定超时快照。RX 边沿计数通过 `xpm_cdc_gray` 传输。所有 ILA 探针均在 200 MHz 域。

| 探针 | 位宽 | 信号 / 含义 |
|---|---:|---|
| probe0 | 1 | `diag_snapshot_valid_ref`，快照有效，保持到采集系统复位 |
| probe1 | 1 | `diag_snapshot_pulse_ref`，收到故障或未锁定超时快照的单周期脉冲 |
| probe2 | 1 | `rx_clock_active_ref`，上一完整 1 ms 窗口是否有 RX 边沿 |
| probe3 | 24 | `rx_edges_per_ms_ref`，每毫秒 RX 边沿数，数值等于 DATA_CLK 的 kHz |
| probe4 | 24 | `rx_counter_ref`，实时同步的 RX 边沿计数 |
| probe5 | 24 | `diag_rx_counter_ref`，错误时 RX 边沿计数 |
| probe6 | 16 | `diag_frame_history_ref`，错误前 8 个 FRAME 对，最早位于 [15:14] |
| probe7 | 64 | `diag_sample_data_ref`，错误前最后完整采样 `{Q2,I2,Q1,I1}` |
| probe8 | 12 | `diag_rx_data_pair_ref`，错误时配对的数据总线 |
| probe9 | 7 | `diag_lane_fall_ref`，所选下降沿值，bit6 为 FRAME；FALLING_EDGE_DELAY=0时为同周期Q2，=1时再延迟一周期 |
| probe10 | 7 | `diag_lane_rise_ref`，错误时上升沿值，bit6 为 FRAME |
| probe11 | 2 | `diag_frame_pair_ref`，错误时的 FRAME 对 |
| probe12 | 2 | `diag_phase_ref`，错误时解码 phase（0..3） |
| probe13 | 8 | `diag_flags_ref`，错误时状态 |

flags[7:0] 依次为 previous_low、locked、ready、fifo_booted、armed、overflow、delay_error、sample_valid。

使用匹配本次 bitstream 的 `PZ_UART.runs/impl_1/pz7035_top.ltx`。既有 `ila_ddr` 保留。

完成 CDCM6208、AD9361 和 MIG 初始化后，保持 ARM=0，先立即触发。probe0=1 时可以直接读取首次错误快照；probe3 需要至少一个完整 1 ms 窗口才有意义。外部时钟停止后最多两个窗口内 probe2/probe3 会变为 0。

重新抓首次错误时，将 probe1 设为 1 触发，先 arm ILA，再用现有采集系统复位清除接收器和快照并释放复位。写 ARM=0 或单独复位 DMA 不会清除锁存错误。RX 域快照传输仍需要源域时钟完成发送，但已经传到参考域的快照不依赖后续 RX 时钟。

快照记录的是解码器作出错误判断时所看到的值；frame history 不包括 probe11 中的当前错误 FRAME 对。此版本增加诊断，FRAME_ERROR 根因、射频 IQ 和 DMA 全链路仍需根据上板观测确认。
