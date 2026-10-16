# FMC 时钟引脚验证

RTL/XDC 现已按用户后续要求加入原 ris_board_test.xpr 并运行标准 synth_1/impl_1 流程；说明见 ../CLOCK_TEST.md，结果见 project_run/。下文“原 xpr 未修改”指此前独立内存工程验证阶段。

当前有效的 LPC 改脚方案请见 [LPC_CLOCK_REWIRE.md](LPC_CLOCK_REWIRE.md)。下文保留此前 HPC 验证及纠错历史。

> 接口更正：用户确认使用 FMC_LPC。本文件早期的 FMC_HPC 球位表和测试不适用于当前连接。正确映射见 lpc_pin_mapping.csv；普通 I/O 的新验证见 lpc_valid16 目录。LPC 的 C2/C3 对应 AB2/AB1（GTX TX），C6/C7 对应 AC4/AC3（GTX RX）。

> 更正：此前将 FMC H2/H3 映射到 AE22/AF22 是错误的。载板原理图 PDF 第 26 页显示 AE22/AF22 实际接 FMC H4/H5，H2 为 PRSNT_M2C_L，H3 为地。G36/G37 → N26/N27 正确。proposed20 的 Vivado 通过仅证明 FPGA 球位可实现，不证明此前建议的 FMC H2/H3 接线可行。子板 H4/H5 已连接 DATA_U15/DATA_U16，因此不能直接将时钟改到 H4/H5。原四脚修改方案撤销，需重新核对并分配。

结论：20 路同源时钟输出在器件资源上可行，但当前子板的第 1、3 组使用了 GTX 专用引脚，原引脚方案不能全部实现。

## 核对范围与依据

- 子板 `SCH_Schematic1_2026-10-10.pdf` PDF 第 3 页 U55（FMC 连接器），第 2 页移位寄存器。
- 载板 `ZC706_Rev2_0.pdf` 图纸页 24、26（FMC），4、5（PL I/O），8（GTX）。
- 原工程 `ris_board_test.xpr` 配置为 `xc7z045ffg900-2` / ZC706；原工程尚无 RTL/XDC。
- 使用本机 Vivado 2020.2 实际综合、布局布线、DRC 和 bitstream 生成。未下载到硬件。
- 原工程 xpr 未修改；所有验证材料均在此目录，使用内存工程。

## 原方案失败的四脚

| 子板信号 | FMC 引脚 | FPGA 球位 | 载板连接 | 结论 |
|---|---|---|---|---|
| SHIFT_CLK1 | C2 | AK10 | GTX TX P | 无普通 OBUF/ODDR |
| LATCH_CLK1 | C3 | AK9 | GTX TX N | 无普通 OBUF/ODDR |
| SHIFT_CLK3 | C6 | AH10 | GTX RX P | 专用输入，不能输出 |
| LATCH_CLK3 | C7 | AH9 | GTX RX N | 专用输入，不能输出 |

GTX TX 是一对专用差分串行输出，不能将 P/N 当作两路同相 LVCMOS 时钟。RX 为专用输入。XDC 或 CLOCK_DEDICATED_ROUTE 设置不能改变其物理功能。

完整的 20 路映射见 `pin_mapping.csv`。

## 实测

- `original20`：严格按原理图约束全部 20 路；Vivado 12-1411 拒绝四个引脚的 LOC，随后工具自动为这些端口选择其他位置，因此布局布线完成不代表原约束成立。最终 UCIO-1 指出四个端口无有效用户 LOC，bitstream 失败。见 `original20.console.txt`、`original20/drc.rpt`、`original20/result.txt`。
- `valid16`：第 2、4、5、6、7、8、9、10 组共 16 路，原引脚不变；综合、布局布线及 bitstream 生成通过。1 BUFG、16 ODDR、16 OBUF。见 `valid16/result.txt`、`valid16/io.rpt`、`valid16/utilization.rpt`、`valid16/route_status.rpt`。
- `proposed20`：保留其余 16 路，仅按下表替换四脚；综合、布局布线及 bitstream 生成通过，1 BUFG、20 ODDR、20 OBUF，布线错误为 0；结果见 `proposed20/result.txt`。此为待改子板方案，不能直接用于现有子板。

## 撤销的改脚方案（H4/H5 已占用）

| 信号 | 原引脚 | 建议引脚 | FPGA 球位 | 载板网络 |
|---|---|---|---|---|
| SHIFT_CLK1 | C2 | H4（已被 DATA_U15 占用） | AE22 | FMC_HPC_CLK0_M2C_P |
| LATCH_CLK1 | C3 | H5（已被 DATA_U16 占用） | AF22 | FMC_HPC_CLK0_M2C_N |
| SHIFT_CLK3 | C6 | G36 | N26 | FMC_HPC_LA33_P |
| LATCH_CLK3 | C7 | G37 | N27 | FMC_HPC_LA33_N |

子板 H2/H3、G36/G37 均为未连接（绿色叉号），可用于改接。此前将 G36/G37 判断为接地，是把相邻 G35 的接地连线看错位，现已纠正。原 C2/C3/C6/C7 与相应时钟的连接也须移除。载板 H4/H5 的 CLK0_M2C 接的是双向 PL I/O，名字中的 M2C 不限制该 FPGA 引脚作为输出。各 P/N 在本验证中独立使用 LVCMOS25，同相输出，并非差分输出。

## 验证设计与边界

输入为载板 SYSCLK H9/G9，约束 200 MHz；IBUFDS → 一个 BUFG → 每输出一路 ODDR（D1=1、D2=0）→ OBUF。所有输出同源，20 路不需要 20 个 BUFG，也不要求每个输出引脚为 MRCC/SRCC。AMD UG471 的 Clock Forwarding 章节描述该 ODDR 用法：https://docs.amd.com/v/u/en-US/ug471_7Series_SelectIO 。

LVCMOS25 / DRIVE 8 / SLEW SLOW 是本次验证条件。子板 74LVC8T595 的输入侧 VCC(A) 接 VDD_2V5；实际使用需确认载板 VADJ_FPGA 为 2.5 V。Vivado 不测量板上电压，也不验证外部负载和走线。

200 MHz 仅用于 FPGA 资源和布线验证，不能当作子板允许的工作频率。本设计未约束外部芯片 setup/hold、板级传播延迟及负载，不证明实际 595 工作时序通过。各输出同源、逻辑同相，但 FPGA 输出延迟、PCB 走线和负载带来实际 skew，不保证引脚边沿零偏差。真实设计应保持 SHIFT 组内同步、LATCH 组内同步，并按移位/锁存协议驱动两类信号。

最小 PL 验证工程未实例化 PS7，DRC 保留 ZPS7-1 警告；通过的设计未放宽 DRC、未使用 CLOCK_DEDICATED_ROUTE FALSE。

## 复现

在本目录执行（将 Vivado 替换为本机路径）：

```bash
/home/yyz/vivado2020.2/main/Vivado/2020.2/bin/vivado -mode batch -source run.tcl -tclargs valid16 -log valid16.log -journal valid16.jou
/home/yyz/vivado2020.2/main/Vivado/2020.2/bin/vivado -mode batch -source run.tcl -tclargs original20 -log original20.log -journal original20.jou
/home/yyz/vivado2020.2/main/Vivado/2020.2/bin/vivado -mode batch -source run.tcl -tclargs proposed20 -log proposed20.log -journal proposed20.jou
```

`generate.py` 从载板 PDF 提取映射并生成 original20 / valid16 源文件；proposed20 文件包含手动建议映射。
