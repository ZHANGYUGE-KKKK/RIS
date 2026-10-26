# AD9361 差分输入缓冲与约束复查

2026-10-16。检查当前 RTL、BD/XPR、活动 XDC，以及最近一次完整布局布线的
`PZ_UART.runs/impl_1/pz7035_top_routed.dcp`。
只读取网表与约束，没有修改 RTL/XDC、重新生成 BIT 或操作板上配置。
该完整实现仍属于精简前版本；当前精简后的源文件及其独立综合结果也包含同样的输入资源。

## 结论

**接收时钟及其他差分输入已有所需缓冲。BD 上的直接连线进入模块内部的输入缓冲，不能据此认为差分信号未经处理就驱动普通逻辑。**

```text
DATA_CLK P/N → IBUFGDS → BUFG → IDDR 时钟端与 RX 域逻辑
FRAME    P/N → IBUFDS → IDELAYE2 → IDDR 数据端 → 解帧
DATA[5:0]P/N → IBUFDS → IDELAYE2 → IDDR 数据端 → 解帧
```

RTL 位置：

- [时钟输入](../../PZ_UART.srcs/sources_1/adi_hdl/library/xilinx/common/ad_data_clk.v)：IBUFGDS、BUFG。
- [数据输入](../../PZ_UART.srcs/sources_1/adi_hdl/library/xilinx/common/ad_data_in.v)：IBUFDS、IDELAYE2、IDDR。
- [实例连接](../../PZ_UART.srcs/sources_1/new/ad9361_rx_lvds_if.v)：六路 DATA、一路 FRAME、一个共享 IDELAYCTRL。

布局布线网表中确认：8 个 IBUFDS（其中一个来自时钟 IBUFGDS 的综合映射）、1 个 RX BUFG、
7 个 IDELAYE2、7 个 IDDR、1 个 IDELAYCTRL。RX BUFG 位于 `BUFGCTRL_X0Y19`。
源码中时钟 IBUFGDS 在网表里成为 IBUFDS、随后连接 BUFG，是正常的器件原语映射。
输入缓冲的 `IBUF_LOW_PWR=TRUE` 为当前官方模块的默认行为，本次未改动它。

因此，若要在 BD 额外加入差分转单端缓冲，需要先调整模块边界；当前结构不缺这一层。
BUFG 用于时钟分发，不能保证输入波形自动变好，也不会自动使 FRAME 与采样边沿对齐。

## 管脚和电气约束

实际生效文件为 [fmcomms3_io.xdc](../../PZ_UART.srcs/constrs_1/new/fmcomms3_io.xdc)。
旧 `rfmc6000_iq_axis_io.xdc` 虽保留在工程中，其所有管脚/时钟命令均已注释，不覆盖当前配置。
其他未加载的旧 XDC 文件不作为本次实际生效约束。

| 信号 | P/N 封装管脚 | 器件差分对 | Bank |
|---|---|---|---|
| DATA_CLK | R27 / T27 | IO_L14P/N_T2_SRCC_13 | HR 13 |
| FRAME | R25 / R26 | IO_L13P/N_T2_MRCC_13 | HR 13 |
| DATA0 | P21 / R21 | IO_L19P/N_T3_13 | HR 13 |
| DATA1 | N28 / P28 | IO_L3P/N_T0_13 | HR 13 |
| DATA2 | T24 / T25 | IO_L17P/N_T2_13 | HR 13 |
| DATA3 | U22 / V22 | IO_L22P/N_T3_13 | HR 13 |
| DATA4 | T30 / U30 | IO_L2P/N_T0_13 | HR 13 |
| DATA5 | N29 / P29 | IO_L4P/N_T0_13 | HR 13 |

16 个引脚均为 `IOSTANDARD=LVDS_25`、`DIFF_TERM=FALSE`。
八组管脚是匹配的器件 P/N 对；DATA_CLK 使用时钟能力管脚 SRCC。
没有设置 `CLOCK_DEDICATED_ROUTE=FALSE` 来绕过 RX 时钟专用路由规则。
这些检查证明的是封装和实现配置一致性，不能替代实物连线、电压与波形测量。

主板原理图第 18 页显示 `VDD_1V8 → R170(0Ω) → VDD_FMC_ADJ`，另一路 R171 标注 NC。
工程亦按 HR Bank 13 的 1.8 V 方案配置，未实测当前实物 VCCO。

按 UG471 第 91–93 页，HR Bank 的 LVDS_25 输入在非 2.5 V 供电时可以使用，但要求关闭片内差分终端，
并满足器件 VIN、VIDIFF、VICM 输入条件。因此不能因为名字带 `_25` 就断言当前 1.8 V 输入配置错误，
也不能直接把 `DIFF_TERM` 改为 TRUE。

**需要核实接收端外部差分终端。** 当前所有片内终端已关闭，尚未确认实际主板/核心板的接收端是否具有合适的外部约 100Ω 终端。
代码中的 FALSE 只是合法配置的一部分，不是整个物理接收接口正确的证明。
本轮没有完成整套 PCB 终端器件核查或实物测量，不能把“缺少终端”写成已证实根因。

## 明确缺失：DDR 输入到达时间约束

重新运行 `check_timing -verbose`，明确列出以下接收端口没有输入延时：

```text
rx_frame_p
rx_data_p[0]
rx_data_p[1]
rx_data_p[2]
rx_data_p[3]
rx_data_p[4]
rx_data_p[5]
```

当前活动约束中没有它们的 `set_input_delay -min/-max`，也没有分别描述时钟上升/下降沿的 DDR 到达窗口。
`report_timing -from ...` 对这些输入路径给出 `Slack: inf`、`Path Group: (none)`。
这表示没有完整的外部时序检查，不能把 inf 解释为采样余量无限大。

因此，以前“所有指定时序约束通过”的结论只覆盖已定义的时序要求，不能据此认定 FRAME/DATA 到 IDDR 的建立/保持时间满足要求。
漏约束本身不必然使硬件出错，但会让相关问题无法被 STA 完整检出。

补充约束需要先确定：

1. 实际接收模式和 DATA_CLK 频率。
2. AD9361 输出延时范围，以及 SPI 006、010、011 对相位/数据排列的影响。
3. 子板、FMC、主板及核心板中 DATA/FRAME 相对 DATA_CLK 的传播延迟与偏差。
4. 需要验收的 FPGA IDELAY 工作点；运行时动态 tap 不会自动更新静态时序分析。

不能只照抄默认输出延时常数，就当作本板完整预算。本轮保存证据，没有填入未经确认的 min/max 数字。

## 时钟周期与当前工作点不一致

活动 XDC 与实现中的 `rfmc_rx` 为：

```tcl
create_clock -name rfmc_rx -period 4.069 [get_ports rx_clk_p]
```

它对应约 245.76 MHz，是先前 Fs=61.44 MSPS 双 RX 模式的时序目标。
最近 SPI 读回对应 Fs=15.36 MSPS，普通 2R2T 的 DATA_CLK 名义值为 61.44 MHz，周期约 16.276 ns。
相对最近确认的工作点，当前内部时序目标更高；该 XDC 不会把实际时钟倍频到 245.76 MHz。
建立外部 DDR 时序预算时应按实际模式分析，不能用更高频率的内部时序目标替代外部接口检查。

从本次实际路径报告还可看到：一个数据输入的 IBUFDS+IDELAYE2 延迟约 1.477 ns，
同一 IDDR 的时钟路径插入延迟约 3.968 ns。这些是特定工艺角、静态默认 tap 下的传播延迟估计，
不是实测抖动，也不是运行时最终相位。它们说明“时钟与 FRAME 同源”不代表到 IDDR 时两条路径的延迟相同。

## 检查范围和证据

- [routed_findings.txt](routed_findings.txt)：实际引脚属性、原语位置与时钟配置。
- [check_timing.rpt](check_timing.rpt)：接收端七个缺少输入延时的端口。
- [input_paths.rpt](input_paths.rpt)：输入数据与时钟的完整路径。
- [io.rpt](io.rpt)、[clock_networks.rpt](clock_networks.rpt)、[effective_constraints.xdc](effective_constraints.xdc)。
- [drc.rpt](drc.rpt)：4 项既有 Warning/Advisory，没有 RX 引脚标准/配对/缺少时钟缓冲的 DRC 错误。
  其中 REQP-1709 指向 MIG PLL 输出缓冲，与 RX 输入缓冲不是同一条路径；其余为无可路由负载和 DMA BRAM 写模式提示。
- [audit.log](audit.log)、[verification.json](verification.json)：运行完成标记、自动核对与输入文件 SHA256。

参考原理图（本地资料）：

- `/home/yyz/ALLdoc/zynq035/ad-fmcomms3_reva.pdf`
- `/home/yyz/ALLdoc/zynq035/05.开发板原理图/璞致PZ7035-FH PZ7045-FH PZ7100-FH平台开发板原理图.pdf`

官方依据：

- [ADI ad_data_clk](https://github.com/analogdevicesinc/hdl/blob/main/library/xilinx/common/ad_data_clk.v)
- [AMD UG471](https://docs.amd.com/v/u/en-US/ug471_7Series_SelectIO)
- [ADI AN-1441](https://www.analog.com/en/resources/app-notes/an-1441.html)
