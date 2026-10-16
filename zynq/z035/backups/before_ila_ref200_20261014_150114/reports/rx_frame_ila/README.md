# RX FRAME 内部 ILA

ILA 名称：`ila_rx_frame`。采样时钟为接收模块内部 BUFG 后的 `rx_clk`（AD9361 DATA_CLK），当前最高配置245.76 MHz。

采集深度2048、普通触发、每个探针输入均有两级流水线。流水线只增加调试观测延迟，所有探针保持同周期对齐，不改变接收逻辑。

通过接收RTL上的MARK_DEBUG及 `rfmc6000_iq_axis_ila.xdc` 插入。该XDC只用于implementation、处理顺序LATE，不新增BD端口或顶层引脚。

| 探针 | 位宽 | RX域信号 |
|---|---:|---|
| probe0 | 1 | `lane_rise[6]` |
| probe1 | 1 | `lane_fall[6]` |
| probe2 | 1 | `lane_fall_d[6]` |
| probe3 | 2 | `frame_pair[1:0]` |
| probe4 | 2 | `phase[1:0]` |
| probe5 | 1 | `previous_low` |
| probe6 | 1 | `locked_rx` |
| probe7 | 1 | `frame_error_rx` |
| probe8 | 1 | `sample_valid` |
| probe9 | 1 | `rx_resetn` |
| probe10 | 1 | `ready_pipe[2]` |
| probe11 | 1 | `fifo_booted_rx` |
| probe12 | 1 | `armed_rx` |
| probe13 | 1 | `overflow_rx` |
| probe14 | 1 | `delay_error_rx` |
| probe15 | 6 | `lane_rise[5:0]` |
| probe16 | 6 | `lane_fall[5:0]` |
| probe17 | 12 | `rx_data_pair[11:0]` |
| probe18 | 64 | `sample_data[63:0]` |

phase仅观察有效状态0..3的低两位。probe15/16为两沿的六条数据线，probe18为已解码的 `{Q2,I2,Q1,I1}`（每项有符号16位）。

所有被采集信号都在RX时钟域；ready_pipe[2]为已有同步器的最后一级输出，不观察中间级。下降沿探针从对应IDDR的Q2引脚取网，综合后显示为lane_fall_orig。未将PS100 MHz或REF200 MHz域的原始信号直接接入RX ILA。

## 使用

加载与本次bitstream匹配的 `PZ_UART.runs/impl_1/pz7035_top.ltx`；既有 `ila_ddr` 保留。
RX时钟必须正在运行，debug hub的200 MHz时钟也必须运行。AD9361硬件复位/配置过程中DATA_CLK可能暂停，此时RX ILA不能正常采集。

1. 先完成CDCM6208和AD9361初始化，保持DMA和ARM=0。
2. 选择ila_rx_frame，将frame_error_rx（probe7）的触发比较设为上升沿R。
3. 2048点窗口中触发位置建议1536，保留75%触发前波形。
4. 在ILA已等待触发后，再使用现有FCLK0/采集系统复位清除接收器的锁存错误，然后释放复位。单独复位AD9361、DMA或把ARM写0不会清除接收器FRAME_ERROR。
5. 观察probe0/1（原始IDDR FRAME）、probe2（延迟后的下降沿）、probe3（配对FRAME）、probe4（解码phase）和probe7的首次置位。

若FRAME_ERROR已为1而未先清除，上升沿触发不会再次发生。可以先Run Trigger Immediate查看当前波形，再按上述流程抓取首次错误。
此ILA只提供定位信息，本次没有修复FRAME_ERROR，也没有验证IQ PN/射频/DMA采样通过。
