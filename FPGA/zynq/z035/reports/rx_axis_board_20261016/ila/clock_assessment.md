# 首轮实板 DATA_CLK / FRAME 独立复核

当前证据不能证明 DATA_CLK 实际为 245.76 MHz。当前 SPI 配置对应的正常接口应为 `DATA_CLK = 4 × 15.36 MSPS = 61.44 MHz`；实板收到的数字边沿、FRAME 和 tag 不满足这个关系，也不满足一个稳定的 245.76 MHz 时钟与 15.36 MHz FRAME 的关系。

## 官方接口定义与当前寄存器

- UG-570 第 107 页说明 LVDS DATA_CLK 是 AD9361 输出的源同步 DDR 时钟；第 109–110 页规定 2R2T 的八半字交织顺序，FRAME 在前四半字为高、后四半字为低。因此每个双通道 IQ 样本需要四个 DATA_CLK 周期。手册没有规定 DATA_CLK 始终等于 ADC_CLK。[ADI UG-570](https://www.analog.com/media/en/technical-documentation/user-guides/AD9361_Reference_Manual_UG-570.pdf)
- AN-1441 明确用 `DATA_CLK = 4 × I/Q rate` 解释 61.44 MSPS 对应 245.76 MHz；245.76 MHz 是该最大采样率例子的接口频率。[ADI AN-1441](https://www.analog.com/en/resources/app-notes/an-1441.html)
- ADI 官方支持回复进一步确认 LVDS 的这个比例适用于各采样率，并给出 1.344 MSPS 对应 5.376 MHz DATA_CLK 的例子。[ADI 官方采样率与时钟答复](https://ez.analog.com/rf/wide-band-rf-transceivers/design-support/f/q-a/541238/ad9361-sampling-rate-and-clock/406629)
- 当前 `002=003=DE` 开启两收两发，并选择 HB3/HB2/HB1/FIR 均为二倍抽取/插值。结合 `00A=02`、BBPLL 约 983.04 MHz，RX 链为 `245.76 → 122.88 → 61.44 → 30.72 → 15.36 MHz`。这里的 ADC_CLK=245.76 MHz 与最终接口采样率不同。
- `010=C8`：重复 FRAME、I/Q 不交换、通道不交换、DATA_CLK 不反相；`010[2]=0` 表示按实际使能通道数确定时序，两路均使能仍为 2R2T。
- `011=00`：不反相 FRAME，不增加整半字的 DATA/FRAME 相对移位。`012=10`：LVDS、DDR、双端口、全双工、RX/TX 等速。
- `006=0F` 只选择 clock delay code=0 和 data/FRAME delay code=15；它是相位/延迟设置，不是频率分频器。UG-671 给出的 0.3 ns/code 是典型值。

寄存器解释依据仓库已有 [UG-671 原文](../../../reference/rfmc6000_7035/docs/AD9361_Register_Map_Reference_Manual_UG-671.pdf) 第 4–10 页，当前完整寄存器读回和参考频率假设见 [SPI audit](../../spi_config_audit_20261016_160523/README.md)。未修改 AD9361 配置。

## 当前实板数据

从 [board_results.json](../board_results.json) 的每个窗口计算 `(pair00+pair01+pair10+pair11) × timer_hz / ticks`：

| 状态 | histogram 推导的表观 RX 边沿率中位数 | 最小值 | 最大值 |
| --- | ---: | ---: | ---: |
| baseline | 171.782 MHz | 170.781 MHz | 182.165 MHz |
| PN | 178.643 MHz | 178.112 MHz | 179.077 MHz |
| restored | 171.203 MHz | 170.155 MHz | 172.064 MHz |

这些是 FPGA 内部计数结果，不是差分引脚的独立频率测量。数值随普通数据/PN 状态变化，不能据此认定一个稳定的 245.76 MHz 输入。100 ms 窗口中，171 MHz 会使总时钟的 24 位计数器越过一圈；因此直接读取模 2²⁴ 的差值只能得到约 3–4 MHz 的表观结果。若实际是理想 245.76 MHz，同样窗口的一圈剩余值应约 78 MHz，而非当前数值。

从三份 [raw CSV 解码数据](decoded/rx_0_raw_records.csv) 获得：

| 捕获 | valid 记录 | 首末 tag 跨度 | tag 增量/ILA 行间隔 | early/late DATA 相同 |
| --- | ---: | ---: | ---: | ---: |
| rx_0 | 4096 | 7048 | 1.721123 | 2748/4096 |
| rx_1 | 4096 | 6948 | 1.696703 | 2823/4096 |
| rx_2 | 4096 | 7027 | 1.715995 | 2735/4096 |

三次 raw 均 ready=1、locked=0、sample_valid=0、fault=0；FRAME pair 只有 `00` 和 `11`。从未获得锁定时，fault=0 不表示正常。

tag 不仅出现满 FIFO 可以解释的前向跳步，还存在重复和倒退：rx_0 有约 −221 后 +221、−7 后 +8；rx_1 有 −1；rx_2 有三次重复。理想源计数器经过只丢弃记录的 FIFO 不可能生成倒退/重复。这说明至少计数器、打包/存储或观测路径中的某处已经不可靠，不能将每个 tag 都当作完全可信的外部时钟记录。

额外利用 raw 中的八位 FRAME history 补全缺失记录，并按 tag 对重叠半字投票：三次分别重建 14106、13906、14064 个半字，分别仅 10、12、6 个位置存在冲突。该重建是诊断推断，不替代无丢失的真实记录。恢复的完整 FRAME 高/低段几乎均为 10 或 12 半字；上升周期以 20/22/24 半字为主。正常 2R2T 应为每段 4 半字、周期 8 半字；若将 15.36 MHz FRAME 与理想 245.76 MHz 时钟配对，则应是每段 16 半字、周期 32 半字，两者均与观测不符。

## 与既有证据的一致性和下一步边界

[先前 SPI audit](../../spi_config_audit_20261016_160523/README.md) 在相同 `006=0F` 下记录：`010=C8` 时内部估算约 179 MHz，`010=C9` 时约 145 MHz；只反相 DATA_CLK 不应改变其真正频率。因此当前异常并非由本轮诊断 ABI 才首次出现。

可确认接收/计数行为异常；尚不能区分差分输入波形/终端问题、错误连接、额外输入跳变，以及实际输入超出已约束时序后发生的内部错误。需要在 AD9361 输出和 FPGA 接收端独立核对 DATA_CLK 的差分周期、占空比、幅度、共模及过冲/重复过阈值，同时核对 FRAME 相对 DATA_CLK 的周期关系。已有 61.44 MHz 的实现时序结果只适用于所声明的时钟模型；修改 `create_clock` 为 245.76 MHz 不会改变真实输入，也不能单独证明故障原因或接口时序闭合。
