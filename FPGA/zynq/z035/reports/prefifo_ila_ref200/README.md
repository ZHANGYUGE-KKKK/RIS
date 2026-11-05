# FIFO 前 200 MHz ILA

`ila_rx_prefifo` 和原 `ila_rx_frame` 均使用 MIG UI 的 ref_clk200。

接收信号在外部 DATA_CLK 域记录到专用双口 RAM，每块连续64拍，写满冻结。
full 信号经 XPM 单比特 CDC 同步后，200 MHz 域逐拍读取；读完经 ACK 握手
归还存储空间。冻结期间 RX 不再写这块 RAM；ACK 返回低后才允许下一块。
因此不会直接在200 MHz ILA里采样异步多位总线，也不改变功能 FIFO 的流控。

仅 `prefifo_valid_ref=1` 的拍属于记录；`prefifo_index_ref=0..63` 标记块内顺序，
`prefifo_batch_ref` 区分块。块内 rx_edge_counter 应每拍+1；块间有采集空隙。
200 MHz ILA 的横轴表示记录回放周期，不能据此换算 DATA_CLK 的物理周期。
顶层引脚、9361配置、功能采样状态机和 DMA/AXIS 数据路径保持原样。

探针见 probes.txt。lane_rise/lane_fall 的 bit6 是 FRAME，低6位为 DATA；
frame_pair 为使用配置的下降沿延迟后的 FRAME 对，dbg_alt_frame_pair 为
无额外下降沿延迟的对照。dbg_frame_window 是前后两对的4位窗口。
参考工程允许窗口0011/1111/1100/0000；顺序检查还要求这四种窗口依次循环。
错误累计是复位以来的饱和计数，分析最终配置时要结合当前事件和当前记录。

每次生成 bitstream 后必须导出包含该 BIT 的匹配 XSA；同步 Vitis 平台及下载
BIT，重新编译，通过 Vitis/XSCT 下载并初始化9361，再用匹配LTX抓取。

## 本轮构建与上板结果（2026-10-15）

综合、布局布线、BIT、LTX、XSA均完成。最终WNS +0.183ns、WHS +0.050ns、
WPWS +0.062ns，无失败端点；总线偏斜检查通过。CDC报告将新增full/ack
识别为3级XPM同步链。XSA内嵌BIT已校验与实现结果一致，Vitis hw/export的
XSA以及应用下载BIT缓存也已校验一致。通过Vitis XSCT完成下载并运行原有
config915程序：MIG9/9、0错误；FRAME0/20、扫描0/512，ARM仍为0。

新ILA在16:24:34、16:24:36、16:24:37均正常ARM并触发，不再报clock stopped。
3次2048点抓取共有2619条有效记录、39个完整64拍块。块内序号、RX计数递增
以及FRAME窗口对齐检查均无错误。prefifo_0/1/2.csv和对应.ila为原始证据。

当前下降沿额外延迟1拍后的FRAME对出现01/10，3次抓取分别有294/286/289
条非法4位窗口，全部记录不符合预期四拍循环。未额外延迟的对照只有00/11，
但完整块内部的高/低持续时间均为6个RX周期，而当前双通道解码要求各2拍。
因此可以确认异常在功能FIFO之前，当前节拍/配对规则不匹配；取消额外延迟
本身还不能消除六拍与两拍的节拍差异。不能将这一数字观察直接等同于
物理时钟频率测量或认定板级信号完整性故障。下一步应核对DATA_CLK实际
波形/频率与9361接口输出节拍，再决定配对方式；本轮未更改这些功能配置。

prefifo_valid_ref=1才是有效回放；同一batch中index连续。ILA横轴仍是200MHz，
不要把高/低6拍误读成6个200MHz周期。查看原始FRAME应取lane_rise/fall的bit6。

2026-10-15 16:39：增加软件显示探针RX1_I、RX1_Q、RX2_I、RX2_Q，分别映射原probe12的11:0、23:12、35:24、47:36，均为12位有符号十进制；新增RECORD_VALID和REFERENCE_IQ_VALID作为观察辅助。iq_split.csv/ila为新抓取，2048拍四路切片逐项与48位原总线校验一致。配置脚本scripts/configure_rx_iq_view.tcl已接入抓取脚本，刷新LTX后会自动恢复显示探针。本次只调整ILA显示，无RTL、BIT或XSA改动。
