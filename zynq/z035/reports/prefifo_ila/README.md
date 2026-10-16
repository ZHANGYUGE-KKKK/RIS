> 此目录是旧接收时钟ILA版本；当前已换成200MHz，见 ../prefifo_ila_ref200/README.md。

# 接收异步 FIFO 前诊断

新增 `ila_rx_prefifo`，使用外部 AD9361 DATA_CLK（内部 rx_clk）。原 `ila_rx_frame` 继续使用 MIG UI 200 MHz。
2048 拍、统一两级 ILA 输入流水，无存储筛选；可以看到逐 DATA_CLK 的 FRAME 和 DATA。
顶层引脚、AD9361 配置、功能解码器、FIFO/AXIS 路径均未改动。

探针完整清单见 probes.txt。三个位置应分别观察：

- lane_rise/lane_fall：IDELAY 后 IDDR 输出，bit6 是 FRAME，bit5:0 是 DATA。
- lane_fall_d、rx_data_pair、frame_pair：下降沿额外延迟之后的配对；dbg_alt_frame_pair 是不额外延迟的对照，仅作观察，不改变采样路径。
- sample_data/sample_valid：原状态机拼出的四路 IQ；pending_data/pending_valid/pending_last/fifo_source_ready：异步 FIFO 写入接口。握手为 pending_valid && fifo_source_ready。

各流水级有真实的一拍延迟，比较同一物理数据时必须按时序对齐。ILA 自己对所有探针统一增加两拍。

新增旁路诊断不依赖 ARM、FIFO 状态或功能解码器是否已报错停止：

- dbg_frame_window = {上一拍 frame_pair, 当前 frame_pair}。
- dbg_monitor_valid：IDELAY 就绪且监控流水填满后有效。
- dbg_window_bad：不在参考代码允许的 0011、1111、1100、0000 中。
- dbg_sequence_bad：不符合循环 0011 -> 1111 -> 1100 -> 0000 -> 0011。可以检出参考允许列表无法检出的 FRAME 卡高/卡低。
- dbg_window_errors/dbg_sequence_errors：16 位饱和累计，复位清零；配置过程中的历史错误不能视为最终配置仍异常，应以当前事件和连续波形判断。
- dbg_reference_iq = {Q2,I2,Q1,I1}，每项12位；参考式旁路拼接，不受功能解码器错误影响。dbg_reference_valid 仅表示遇到 0000 窗口，不保证完整序列或 IQ 正确。

这里的“原始 FRAME”是引脚经 IBUFDS/IDELAY/IDDR 后的数字观察值，无法用 ILA 测量模拟电平、眼图或证明 DATA_CLK 的物理频率正确。

建议先立即触发抓取连续流，再以 dbg_sequence_bad=1（内部已由 monitor_valid 限定）触发，触发位置设置为1024，观察错误前后。若无错误触发，应保留立即触发采样，不能因未触发就宣布通过。
