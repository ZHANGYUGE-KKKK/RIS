# RFMC6000 双通道 I/Q 采集与 DMA 接入方案

新增独立模块：`PZ_UART.srcs/sources_1/new/rfmc6000_iq_axis.v`。
本次完成接收 RTL、CDC 约束和独立验证；当前 `PZ_UART.xpr`、BD、顶层、
已导出的 XSA 和 AD9361 在线检查软件保持原来的版本。新采样模块尚未加入当前
工程的活动文件集。后续接入顶层、FIFO、DMA 后，需要重新生成 bitstream/XSA。

## 接口与数据格式

模块直接接收 AD9361 的 RX_CLK、RX_FRAME 和 RXD[5:0] 共 8 对 LVDS。
要求芯片配置为双接收通道、LVDS DDR、周期性 RX_FRAME；标准帧序列为：

| DATA_CLK 周期 | FRAME（两个边沿） | I 的 6 位 | Q 的 6 位 |
| --- | --- | --- | --- |
| 0 | 11 | RX1 I[11:6] | RX1 Q[11:6] |
| 1 | 11 | RX1 I[5:0] | RX1 Q[5:0] |
| 2 | 00 | RX2 I[11:6] | RX2 Q[11:6] |
| 3 | 00 | RX2 I[5:0] | RX2 Q[5:0] |

默认 I 在下降沿、Q 在随后的上升沿，使用 `IDDR(SAME_EDGE)` 配对。
这一边沿关系与 ADI/RFMC6000 参考接口一致。若硬件配置改变边沿选择，
可用 `I_ON_FALLING_EDGE=0` 对调 I/Q；这不替代采样时序校准。
模块不支持单通道帧格式或只在突发起始拉高一次的 FRAME 模式。

每个 AXI Stream beat 含 RX1/RX2 的一组完整复数样本，每个分量从有符号
12 位符号扩展为 16 位，不截位、不做抽取或幅度缩放：

| TDATA | 内容 | DDR 内每组样本的字节偏移 |
| --- | --- | --- |
| [15:0] | I1 | 0–1 |
| [31:16] | Q1 | 2–3 |
| [47:32] | I2 | 4–5 |
| [63:48] | Q2 | 6–7 |

`TKEEP=0xFF`；默认 `PACKET_SAMPLES=4096`，每 4096 组样本产生一次 TLAST，
每包 32768 字节。TLAST 与数据一起入 FIFO，反压期间保持不变。
数字接口提供的是 AD9361 内部滤波、抽取后的 I/Q 数据。

## 时钟、CDC 与复位

```mermaid
flowchart LR
    A[AD9361 RX LVDS] --> B[IBUFDS / IDELAY / IDDR]
    B --> C[DATA_CLK 域：四路 I/Q 组帧]
    C --> D[模块内 XPM 异步 AXIS FIFO]
    D --> E[PS FCLK0 100 MHz 域：64 位 AXI Stream]
    E --> F[外部 AXIS Data FIFO]
    F --> G[AXI DMA S2MM]
    G --> H[AXI Interconnect]
    H -->|AXI 时钟转换到 UI 200 MHz| I[MIG PL DDR]
```

- `ref_clk200`：稳定、已缓冲的 200 MHz 时钟，用于 IDELAYCTRL。复位保持至少
  64 个参考周期，RDY 经三级同步后在接收域使用。
- `rx_clk`：模块内部将差分 DATA_CLK 经 IBUFDS、BUFG 后用于 DDR 捕获。
- `m_axis_aclk`：接入 PS `processing_system7_0/FCLK_CLK0`，100 MHz。
  AXIS、外部 FIFO、DMA 数据/控制通路和采集控制 GPIO 都使用该时钟。
- `ref_clk200` 可接到 MIG `ui_clk`，先核实其实际频率确为
  200 MHz；这样无需在已有差分振荡器引脚上重复实例化输入缓冲。以后更改 MIG
  UI 频率时，需要为 IDELAYCTRL 另提供稳定的 200 MHz 参考时钟。
- I/Q 数据通过 `xpm_fifo_axis(independent_clock)` 跨域，禁止对数据总线逐位
  打拍。XPM 提供指针同步、FIFO 复位逻辑和对应的时序约束。
- `capture_arm` 由 PS FCLK0 100 MHz 域的控制寄存器驱动。模块先在该域登记，再
  三级同步到 RX 域。采集控制 GPIO 与 `m_axis_aclk` 使用同一 FCLK0。
- 状态位在 RX 域登记后分别三级同步到输出域；它们是独立电平，不能当作同一
  周期的原子状态快照。
- `aresetn` 复位整个采集模块和内部 FIFO。各时钟域异步断言、同步释放。
  正常释放复位前应保证三个时钟有效；DATA_CLK 尚未产生时可保持复位。
- 直接控制 FIFO RAM 读写使能的寄存器使用同步复位，防止异步复位断言改变
  RAM 控制引脚。接收时钟停止时，输出域仍屏蔽旧数据；接收时钟恢复后再完成
  FIFO 清空和启动。

配套 `PZ_UART.srcs/constrs_1/new/rfmc6000_iq_axis_cdc.xdc` 仅排除手写同步器
第一级的异步输入路径，后续级仍正常计时。XPM 自己的约束必须保留，不能用宽泛
的时钟组异常覆盖其 Gray 指针的最大延迟/总线偏斜约束。

后续将文件加入工程时：

```tcl
set_property XPM_LIBRARIES {XPM_CDC XPM_FIFO XPM_MEMORY} [current_project]
# 在加入约束文件后，限定它只作用于此接收模块：
set_property SCOPED_TO_REF rfmc6000_iq_axis [get_files *rfmc6000_iq_axis_cdc.xdc]
```

## 启动与完整性

1. 软件完成 AD9361 参考时钟、双 RX 数字接口和接收通路初始化，确认 DATA_CLK
   及 FRAME 格式。当前的 SPI ID 检查软件还没有完成这些配置。
2. 复位采集模块及外部 FIFO，准备 DMA 描述符/目标缓冲区并启动 S2MM。
3. 等待 `rx_ready=1`、`frame_locked=1`，再将 `capture_arm` 置高。
4. ARM 在 RX 域锁存，之后连续采集完整 I/Q 组。ARM 拉低不会中途截断包；
   本版本停止/重启采集使用复位。复位会丢弃内部未搬完的数据，软件必须先定义
   采集窗口边界，不能把复位时的半包当作有效数据。

ADC 无法响应 TREADY。内部 FIFO 默认 4096 beat，约 32 KiB 有效数据缓冲；
还含随数据保存的 AXIS sideband。额外弹性寄存器保证 FIFO 入口反压时稳定。
接收器从完整 `11,11,00,00` 序列取得锁定，避免从半个样本开始输出。

| 状态 | 含义 |
| --- | --- |
| rx_ready | IDELAY 已就绪、FIFO 已启动 |
| frame_locked | 已观察到完整双 RX 帧序列 |
| capture_active | 已 ARM 且没有采集错误；不表示 DMA 已写完 DDR |
| overflow | 缓冲区无法接纳新样本，已发生漏样 |
| frame_error | 锁定后帧序列不符 |
| delay_error | 启动后 IDELAYCTRL 丢失 RDY |

三个错误位锁存到复位，并停止接纳新样本。已排队的数据继续遵守 AXIS 握手，
不会撤回一个被反压的有效 beat。任一错误都表示该次采集不能被认定为完整记录；
软件应处理/中止当前 DMA 包，清空采集和外部 FIFO 后重新开始。
有效记录还必须检查 DMA 完成状态、实际字节数及缓冲区边界。

## 后续 BD 接线

| 项目 | 配置/连接 |
| --- | --- |
| 外部 AXIS Data FIFO | 64 位，启用 TKEEP/TLAST，共同时钟，Packet Mode 关闭 |
| FIFO 时钟 | s_axis_aclk / m_axis_aclk 均使用 PS FCLK0 100 MHz；模块内已完成 RX→100 MHz CDC |
| 外部 FIFO 深度 | 初始建议 16384 beat（128 KiB 数据），结合剩余 BRAM 和实测停顿调整 |
| AXI DMA | 仅 S2MM，开启 Scatter Gather，单通道；连续记录使用预先排队的描述符 |
| DMA Stream 宽度 | 64 位，与本模块一致 |
| DMA M_AXI_S2MM 宽度 | 初始采用 64 位，由 Interconnect 转换成 MIG 的 256 位 |
| DMA 数据/SG 时钟 | m_axi_s2mm_aclk / m_axi_sg_aclk 使用 PS FCLK0 100 MHz |
| DMA 控制时钟 | s_axi_lite_aclk 使用同一 FCLK0；DMA 主/控制时钟同步，并连接匹配的 100 MHz 域复位 |
| DMA 数据写口 | M_AXI_S2MM → Interconnect（100→200 MHz、64→256 位）→ MIG/S_AXI，与 GP0 共享 MIG |
| DMA SG 口 | M_AXI_SG → 描述符存储器；建议增加可被 PS 和 SG 都访问的 BRAM |
| PS 控制口 | GP1 连接 DMA S_AXI_LITE 与新增采集控制/状态寄存器；保留 RIS GPIO 原地址 |
| 中断 | DMA s2mm_introut → PS IRQ_F2P，软件检查描述符及错误状态 |

Interconnect 的 DMA/GP 输入侧使用 FCLK0 100 MHz，MIG 输出侧使用 `ui_clk`
200 MHz，并配置 AXI 时钟转换；两侧复位分别使用对应时钟域的复位。
内部异步 FIFO 负责 RX→100 MHz，AXI Interconnect 负责 100 MHz→MIG 200 MHz。

## ADC 数据时钟接法

`rx_clk_p/n` 是 AD9361 向 FPGA 输出的 DATA_CLK 接收输入，接子板的
RX_CLK_P/N：FMC H4/H5 → FPGA AB27/AC27。将这两个模块引脚 Make External，
与 `rx_frame_p/n`、`rx_data_p/n[5:0]` 一起引到顶层；按顶层实际端口名添加 XDC。
模块已内置 IBUFDS 和 BUFG，外部直接接差分管脚即可。

```verilog
// 端口名按实际顶层保持一致；物理引脚是 AB27 / AC27。
input wire rx_clk_p;
input wire rx_clk_n;
// 实例连接：.rx_clk_p(rx_clk_p), .rx_clk_n(rx_clk_n)
```

```tcl
set_property -dict {PACKAGE_PIN AB27 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports rx_clk_p]
set_property -dict {PACKAGE_PIN AC27 IOSTANDARD LVDS_25 DIFF_TERM false} [get_ports rx_clk_n]
```

采样率由 AD9361 的参考时钟、内部时钟树及 SPI 配置决定。对于本模块采用的
标准双 RX LVDS 格式，DATA_CLK 为每通道 I/Q 样本率的 4 倍：例如 30.72 MSPS
对应 122.88 MHz，61.44 MSPS 对应 245.76 MHz。PS FCLK0 用于消费解串后的样本，
无需与 DATA_CLK 同频。当前芯片在线检查程序还没有启动这套采样时钟/接口配置。

当前 MIG 为 32 位 DDR3、4:1 PHY、256 位 AXI，地址 `0x40000000–0x7FFFFFFF`。
DMA 的地址映射必须单独给出这一段，不能只保留 CPU/GP0 的映射。其 SG 主口也
必须能读写描述符存储器。建议目标地址至少按 32 字节对齐，使用 32 KiB 整包；
这与 MIG 不支持窄突发的设置匹配。DMA 内存口也可配置为 256 位，省去 S2MM
数据口的外部宽度转换，接 BD 时再统一确定。

默认每包 32 KiB，描述符缓冲区长度至少 32 KiB。固定采集窗口优先使用有限、
预排队的 SG 描述符；环形采集必须另有消费指针和覆盖检测，避免写满后覆盖
尚未保存的数据。有限窗口还需采样数/包数控制及结束后的源端停止/复位流程，
不能依靠停掉 DMA 让 ADC 停止输出。这部分属于后续控制和搬运设计。

双 RX 的数据率为 `8 × Fs` 字节/秒。若每通道为 61.44 MSPS，则为
491.52 MB/s；内部 4096-beat FIFO 约能吸收 66.7 μs 的停顿，外部 16384-beat
FIFO 再增加约 266.7 μs。实际可承受停顿与占用有关。必须实测 DMA/DDR 持续
有效吞吐和最长停顿；FIFO 不能补偿长期吞吐不足。完整 1 GiB 存储空间在此速率
下约容纳 2.18 秒数据，实际窗口要扣除保留区，不能承诺无限时长记录。

## 管脚与板上时序

| 输入 | FPGA P / N |
| --- | --- |
| RX_CLK | AB27 / AC27 |
| RX_FRAME | T30 / U30 |
| RXD[0] | W29 / W30 |
| RXD[1] | U24 / V24 |
| RXD[2] | T24 / T25 |
| RXD[3] | N28 / P28 |
| RXD[4] | U22 / V22 |
| RXD[5] | P21 / R21 |

按当前 BANK12/13 的 1.8 V 供电，使用接收型 LVDS_25、关闭内部 DIFF_TERM，
核实接收端外部差分端接。IO 原语已指定这些属性。`INPUT_DELAY_TAPS` 的七个
字段分别为数据 D0..D5、FRAME，各范围 0..31；板上需通过 AD9361 测试图样/PN
及相位扫描选择可靠窗口，并补齐基于器件输出时序和板级偏斜的 DDR input delay。
零 tap、行为仿真和独立综合均不能代替最终板级时序验证。

## 验证

`tests/run_rfmc6000_iq_axis.sh` 使用 Vivado 2020.2 实际 UNISIM 和 XPM 模型，
编译/运行输出全部放在临时目录。测试输入 DATA_CLK 为 245.76 MHz，输出时钟为
PS 的 100 MHz，参考时钟保持 200 MHz，覆盖：

- 连续 I1/Q1/I2/Q2、正负数和极值、字序、随机 TREADY、整个 4096-sample 包。
- 7-sample 非 2 次幂包、1-sample 包及对调 I/Q 边沿配置。
- FIFO 满、FRAME 单边沿异常、IDELAY RDY 丢失、错误锁存及停止。
- 反压期间 DATA/KEEP/LAST/VALID 保持，内部 RAM 实际读写使能保护。
- RX 时钟停止时断言复位、恢复时钟再释放复位、旧数据清除。

2020.2 XPM 的可选 SVA 对异步 read pointer 使用了单周期比较，并对 AXIS 的
原始 VALID/full 行为作非握手语义检查。本模块使用其默认 `SIM_ASSERT_CHK=0`；
测试台独立检查真实 RAM 使能、完整数据序列和 AXIS 握手。

```bash
./tests/run_rfmc6000_iq_axis.sh
# 从临时目录运行独立综合/CDC，不改动主工程：
vivado -mode batch -source /home/yyz/work/RIS/zynq/z035/scripts/verify_rfmc6000_iq_axis.tcl
# 加 route 参数可复现独立模块的内部布局布线检查：
vivado -mode batch -source /home/yyz/work/RIS/zynq/z035/scripts/verify_rfmc6000_iq_axis.tcl -tclargs route
```

三组仿真通过；独立综合无逻辑警告，CDC 报告只有已识别的三级单比特同步链。
默认配置约使用 180 LUT、551 寄存器、9.5 个 BRAM36 等效资源、7 个 IDELAY、
7 个 IDDR 和 1 个 IDELAYCTRL。资源会随参数和整机优化变化。
已将前次独立布局布线的网表按 RX 245.76 MHz、AXIS 100 MHz、参考 200 MHz
重新检查，并将 FIFO Gray 指针延迟/偏斜约束更新为实际时钟周期：
WNS=0.194 ns、WHS=0.068 ns，setup/hold 无失败端点，指针总线偏斜满足
4.069 ns 的上限。RAM 异步控制告警已消除。该检查只有 16 个 LVDS IO 按真实板卡定位，其余
内部接口在独立顶层中按虚拟外部端口处理；DRC 的 UCIO-1、缺少 PS7 是这一
检查环境的边界，不是已接入主工程的 bitstream 检查结果。不生成独立 bitstream。
当前没有把 DMA/MIG 集成链路运行在板上，不能把这些验证当作实际 DDR 记录结果。

参考：[ADI UG-570](https://www.analog.com/media/en/technical-documentation/user-guides/AD9361_Reference_Manual_UG-570.pdf)、
[ADI LVDS 接口 RTL](https://github.com/analogdevicesinc/hdl/blob/main/library/axi_ad9361/xilinx/axi_ad9361_lvds_if.v)、
[AMD AXI DMA PG021](https://www.amd.com/content/dam/xilinx/support/documents/ip_documentation/axi_dma/v7_1/pg021_axi_dma.pdf)，
及本地 RFMC6000 子板/载板原理图。实现为本项目独立编写。
