# AD9361 官方接收前端移植

2026-10-16，PZ7035-FH + AD-FMCOMMS3 Rev.A，Vivado/Vitis 2020.2。
本目录记录源码、仿真、构建和板测证据；板测结论在完成后补充。

## 结构和来源

```
FMCOMMS3 DATA_CLK/FRAME/D[5:0] LVDS
  -> ADI ad_data_clk / ad_data_in (IBUFDS + IDELAYE2 + IDDR SAME_EDGE)
  -> ad9361_rx_lvds_if (官方沿配对、FRAME 解帧)
  -> ADI axi_ad9361_rx (4 路原始 IQ + 官方 PN 监测)
  -> 64-bit AXIS 适配 + XPM 异步 FIFO
  -> 原有 AXIS Data FIFO -> Xilinx AXI DMA SG -> MIG DDR
```

官方 HDL 固定提交：`4b12bb58a17edb4c67f63eb367b42d3d3a4e5c91`。
`PZ_UART.srcs/sources_1/adi_hdl/SOURCE_MANIFEST.json` 记录原文件 SHA256；
该目录的官方 Verilog 保持原样，附带官方许可证。
主线官方工程要求 Vivado 2025.1；这里仅移植并验证所需 Verilog，
没有运行新版官方工程 Tcl，也没有把当前工程称作官方 2020.2 工程。

`ad9361_rx_lvds_if.v` 来源于官方 `axi_ad9361_lvds_if.v`，仅改模块名，
增加 FRAME 当前/上一拍与双沿原始数据的只读调试端口，采样/配对/解帧算法不改。
新总模块为 `PZ_UART.srcs/sources_1/new/ad9361_rx_axis.v`，BD 实例 `ad9361_rx_axis_0`。
原 `rfmc6000_iq_axis` 文件保留，其旧 CDC/ILA XDC 在当前工程中禁用。
板级 `fmcomms3_io.xdc`、RIS、DMA/MIG 和顶层外部引脚沿用已有连接。

原始数据不经过数字 DC 滤波、IQ 校正或格式变换；12 位补码仅在 AXIS
适配时符号扩展到 16 位。64 位一次输出一组双 RX IQ：

| AXIS 位 | 数据 |
| --- | --- |
| `[15:0]` | RX1 I，12 位符号扩展 |
| `[31:16]` | RX1 Q，12 位符号扩展 |
| `[47:32]` | RX2 I，12 位符号扩展 |
| `[63:48]` | RX2 Q，12 位符号扩展 |

TKEEP 恒为 FF，TLAST 每 4096 组有效 IQ 输出一次，即 32768 字节一包。
背压期间 TVALID/TDATA/TLAST 保持；缓冲耗尽会锁存 overflow 并停止接纳新样本。
不承诺无限背压下持续采样无丢失，软件必须检查故障位。

## 模块接口接法

| 端口 | 当前连接/作用 |
| --- | --- |
| `rx_clk_p/n` | 子板 DATA_CLK 差分输入，实际物理采样时钟；直接顶层 + 板级 XDC |
| `rx_frame_p/n` | 子板 RX_FRAME 差分输入，直接顶层 + 板级 XDC |
| `rx_data_p/n[5:0]` | 子板 6 对 RX_DATA，直接顶层 + 板级 XDC |
| `ref_clk200` | 原有 200 MHz 参考时钟，供 IDELAYCTRL 和接收 ILA |
| `m_axis_aclk` | PS FCLK0，100 MHz，供 AXIS 输出和 S_AXI 控制 |
| `aresetn` | `rst_ps_fclk0/peripheral_aresetn`，内部按 RX/AXIS/REF 域同步释放 |
| `capture_arm` | 采集 GPIO 通道 1 bit0 |
| 六个状态输出 | 原采集 GPIO 通道 2 bit[5:0]，顺序保持 |
| `M_AXIS` | 原有 `axis_data_fifo_0/S_AXIS`，含 TDATA/TKEEP/TLAST/TVALID/TREADY |
| `S_AXI` | `axi_interconnect_1/M03_AXI`，PS GP1，32 位 AXI-Lite |

内部已包含差分输入缓冲和采样原语，BD 不再加 IOBUF。
采集 GPIO bit1 名称为兼容原 API 仍叫 FRAME_LOCKED，现表示官方 `adc_status`；
它不是完整数据正确性判据，必须结合 PN 校验。
ARM 锁存后，写零不会停止正在进行的采集；重新采集需复位并重新初始化。

## 地址和软件

| 地址 | 功能 |
| --- | --- |
| `80010000` | 原 RIS GPIO |
| `80020000` | 原采集 GPIO |
| `81000000` | 原 Xilinx AXI DMA 控制 |
| `82000000..8200FFFF` | 新官方 RX 核 AXI-Lite |
| `40000000..7FFFFFFF` | 原 MIG DDR，CPU / DMA SG / DMA S2MM |

新 `src/drivers/rx_9361.c/.h` 初始化官方核、四路 enable、旁路设置、7 路 IDELAY，
支持 PN 状态检查。常用官方偏移：版本 0000，复位 0040，控制 0044，状态 005C，
每路控制 0400+40*n、状态 0404+40*n、PN 选择 0418+40*n，延时 0800+4*lane。
适配器额外只读寄存器：1000 有效 ADC 样本计数，1004 RX 周期计数，1008 签名 ADRX。
两个 24 位计数器经 Gray CDC 进入 AXI 域，PN 检查要求计数增长，避免无时钟/无 valid 假通过。

AD9361 RX 内置 BIST 使用 PN 选择 **0**（官方 `AXI_ADC_PN9`，芯片专用 I/Q 序列）；
选择 9 对应官方 FPGA TX PRBS 发生器的标准序列，不能混用。
依据官方 no-OS 的 `ad9361_bist_prbs(BIST_INJ_RX)` 写 3F4=09，暂时保存并恢复原 BIST/掩码/环回设置。
默认 main 先运行用户 config915，再执行有界 PN 测试与延时扫描：
先扫芯片两种 RX 时钟极性、16x16 时钟/数据延时；无窗口再扫 FPGA 32x32 FRAME/统一 DATA 延时。
选择通过区间中点并连续复核 3 次；失败恢复原延时，保持 ARM=0。
PN 结果保存在 `official_rx_report`，重新链接后用 ELF 符号查找地址。
测试完成恢复普通 RX 和原 TX BIST；此时 PN 监测收到普通 RF 数据会报不匹配，这是正常现象。
`rf_capture_reset(0)` 每次释放 FCLK0 外设复位后都重新初始化官方 RX 寄存器。

## 200 MHz ILA

核名 `ila_ad9361_rx`，2048 深度，时钟严格为 `ref_clk200`。
RX 域独立 64 行双时钟 RAM 记录连续 RX 周期；写满后冻结整组，
通过所有权请求/确认同步交接给 200 MHz 域读取，读完确认后才允许下一组写入。
记录器不对实际 IQ 链路施加背压。ILA 不直接采样异步 RX 总线。

只在 `prefifo_valid_ref=1` 时解析，每组按 `prefifo_batch_ref` 分开，
`prefifo_index_ref=0..63` 是相邻 RX 周期；不同组之间存在空隙，不能拼成连续 RF 时间线。
四路独立 12 位探针是 `rx1_i_ref/rx1_q_ref/rx2_i_ref/rx2_q_ref`，
只在同一行 `prefifo_official_valid_ref=1` 时视为新 IQ。
另有原始 FRAME 当前/上一拍、上下降沿 6 位 DATA、官方复位/状态/valid、
AXIS 打包数据、pending/FIFO 握手、ARM/错误和源域周期计数。
`rx_edges_per_ms_ref` 是每 200000 个参考周期的 RX 边沿计数；需参考时钟实际为 200 MHz 才能按 kHz 解读。

在 Vitis 完成匹配硬件/软件的下载后，在 Vivado GUI 执行：

```tcl
source /home/yyz/work/RIS/zynq/z035/scripts/capture_ad9361_rx.tcl
```

## 检查与复现

`tests/run_ad9361_rx_axis.sh`：Vivado xsim，包长 1/7/4096，
未修改的官方 LVDS 模块作为 oracle 逐周期比较；检查四路 IQ、符号、TLAST、
背压稳定性、overflow 停采、FRAME 故障、停钟复位、AXI-Lite/IDELAY/计数器、
官方标准 PRBS 及 AD9361 专用 PN 的四路锁定和错误注入，
并逐行核对源域记录与 200 MHz 回放数据。日志 `simulation_final.log`。

硬件构建在现有 Vivado GUI 执行：

```tcl
source /home/yyz/work/RIS/zynq/z035/scripts/build_ad9361_official_rx.tcl
```

脚本更新 BD、综合、布局布线，核对时序/总线 skew/DRC，生成 BIT 并导出含 BIT 的 XSA，
最终核对 ILA 周期为 5 ns 并生成匹配 LTX。`build_status.txt` 记录结果和报告目录。
外部 LVDS 输入当前没有完整板级 input-delay 预算；内部时序通过不能单独证明外部采样眼图。
实际数字接口验收以板上 PN 结果为准。

官方来源：
- https://github.com/analogdevicesinc/hdl/tree/4b12bb58a17edb4c67f63eb367b42d3d3a4e5c91/library/axi_ad9361
- https://github.com/analogdevicesinc/no-OS/blob/main/drivers/rf-transceiver/ad9361/ad9361_conv.c
- https://analogdevicesinc.github.io/hdl/library/axi_ad9361/index.html

首轮构建时序未通过（WNS -2.411 ns）：遗漏了已随源码保留的官方
`up_clock_mon_constr.xdc`，以及适配器诊断计数器直接使用跨域全局复位。
第二轮补入官方监测器配套约束，并让计数器使用 RX 本域三拍同步释放的复位；
保留第一轮报告供核对，没有通过降低检查级别或全时钟组 false-path 绕过问题。

另修正调试 RAM 的控制复位：读写地址、所有权状态和使能使用本域同步复位，
避免异步控制直接驱动 BRAM。记录器只受全局同步复位控制，独立于官方核复位与调 tap，
因此可记录 `official_rst=1` 的时段，也不会因单独复位官方核而提前释放冻结记录。
仿真加入单独 AXI 复位官方核时的回放完整性和复位探针检查。
软件结束 PN 测试后会回读确认 SPI 010/006/3F4/3F5/3F6，确保延时和原 BIST/环回状态实际恢复，
`restore/readback=0` 才表示恢复检查成功。

## 初次上板（最终所有权请求寄存器收尾前）

初次 BIT/XSA 已通过内部时序，WNS +0.183 ns。CDC 报告另有一项记录器请求
在同步器前的组合复位掩码（CDC-10），后续改为独立请求寄存器，最终构建加入
Critical CDC 阻断检查，不将初次结果当作最终 CDC 验收。
初次硬件/配套 XSA/LTX 备份于 `backups/before_adi_recorder_request_register_20261016_1135/`。
使用 Vitis XSCT 下载，官方 RX 版本读回 000A0300、配置 0000000F（PL 处理旁路），
签名 ADRX 正确。PN 四路均为 00000002（out-of-sync），1537 点扫描 0 个通过，
恢复及回读成功、ARM=0。MIG 自检 9/9、0 错误、7520812 字通过。
详见 `uart_preliminary.log`、`board_result_preliminary.json` 和 `board_registers.txt`。
官方 PS FCLK100 时钟监测器另外连续读到约 173.6/174.0/174.4 MHz 的 RX 边沿计数，
与 Fs15.36MSPS 的双通道 DDR 预期 61.44 MHz 不符；这是 FPGA 数字计数证据，
不能据此单独确定模拟时钟频率、波形或硬件根因，仍需结合原始 ILA 和外部测量。

Vitis 2020.2 更新注意：`platform generate -quick` 会生成新的 BSP 源码，
本次更新后导出 include/lib 尚需重新构建。完整 generate（包括指定 standalone_domain）
在本机编库后仍试图再启动 Eclipse，遇到工作区启动异常。可在 quick 更新后，
直接 make 新生成的 standalone BSP，并同步其 include/lib 到平台导出目录，再 make 应用；
不要误把缺失驱动头文件当作 RTL 或地址问题。

## 最终交付和板测结果

最终构建：`reports/gui_rebuild_20261016_113741/`，
WNS **+0.183 ns**、TNS **0**，Hold slack **+0.051 ns**；总线 skew 通过。
CDC 报告 **0 Critical**；保留官方稳定数据/时钟使能结构与 MIG 的原有警告，
接收 RAM 异步控制告警已消除。构建脚本已核验接收 ILA 时钟周期 **5 ns**。
最终 BIT/LTX/XSA 已生成，并用 Vitis XSCT 完成 FPGA 和应用的易失性下载。
根目录 XSA、平台 hw XSA、平台 export XSA 的 SHA256 完全一致，
XSA 内嵌 BIT 与实现 BIT、应用下载 BIT 完全一致。摘要见 `artifacts.sha256`、`platform_xsa.sha256`。

- 官方 RX 核版本 **000A0300**，旁路配置 **0000000F**，四路 enable=1，PN 选择=0。
- 板上 PN：**0/1537** 个测试点通过，四路状态均 **00000002（PN out-of-sync）**。
- 原 SPI 延时 C8/0F、BIST 53/30/00 已恢复并回读确认，restore/readback=0。
- MIG：**9/9 PASS，0 错误，7520812 个 32 位字，4755 ms**。
- 当前采集 **ARM=0**；没有执行有效 IQ 的 DMA 搬运验收，不能将 MIG 测试解释为 RX 数据通过。

200 MHz ILA `ila_ad9361_rx`（当前硬件窗口 `hw_ila_2`）成功抓取三次；
Vivado 已切换到该核并显示 RECORD_VALID、IQ_VALID、四路独立有符号 IQ、FRAME 等新信号。
界面脚本 `scripts/configure_ad9361_rx_view.tcl` 会替换旧模块名的波形配置；无需重新生成 BIT。
记录文件见 `ila/rx_0..2.csv/.ila`，界面截图 `ila/vivado_rx.png`。

实测 2552 条有效回放行、39 个完整 64 行记录组。记录 index 顺序连续，
但源域 RX 周期计数有 **3 处差分异常**，不能把本次数据视为无错误连续采样。
FRAME 双沿对有 448/2552 条为 **01/10**；完整组内部的 00/11 段多数持续
**4 或 5 个 RX 周期**，与目标 2R2T 的每段 2 周期不符。
每 200000 个参考周期的 RX 边沿计数为 **172295..173956**，与预期 61440 不符。
详情 `ila/analysis.json`；`ila/raw_debug_iq.csv` 仅供调试，**未经 PN 验证，不能当作可信 RF 数据**。

这些结果说明换为官方接收逻辑后，板上数字输入异常仍存在。
仿真与静态 CDC 检查通过，不足以排除板上动态时钟/电气或其他实现问题；
不能仅凭计数异常断言硬件根因，也不能把 FRAME 错误当成只需换一个 CDC 参数的问题。
下一步应以示波器核对 FMC G6/G7（DATA_CLK）及 D8/D9（RX_FRAME）的真实频率、
波形和相位，再结合当前 LVDS 终端、VADJ 和 AD9361 并行口配置判断；
PN 未通过前保持 ARM=0。已向用户询问示波器/探头条件，尚未得到答复。
