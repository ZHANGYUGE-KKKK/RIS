# ZC706 FMC_LPC 时钟修改方案

本方案仅适用于载板 J5 FMC_LPC，器件 xc7z045ffg900-2。子板源 PDF 为 SCH_Schematic1_2026-10-10.pdf。

## 四路改线

| 信号 | 原 FMC 接点 | 新 FMC 接点 | 载板网络 | FPGA 球位 |
|---|---|---|---|---|
| SHIFT_CLK1 | C2 | G36 | FMC_LPC_LA33_P | Y30 |
| LATCH_CLK1 | C3 | G37 | FMC_LPC_LA33_N | AA30 |
| SHIFT_CLK3 | C6 | H37 | FMC_LPC_LA32_P | Y26 |
| LATCH_CLK3 | C7 | H38 | FMC_LPC_LA32_N | Y27 |

G36、G37、H37 在子板原图中标为未连接；H38 当前接 VADJ，须先删除该电源连接，再接 LATCH_CLK3。删除上述四个信号到 C2/C3/C6/C7 的旧连接。其余 16 路 CLK 和 DATA/OE/MR 信号位置保持原图。P/N 独立配置为单端 LVCMOS25。

载板 PDF 第 28 页明确标注 G36/G37 为 LA33 P/N、H37/H38 为 LA32 P/N；第 5 页列出 FPGA 球位 Y30/AA30/Y26/Y27。完整改后表见 lpc_revised20_mapping.csv，XDC 见 lpc_revised20.xdc。

## 同时需要修正的 VADJ 引脚错位

这是逐脚对照已发现的原图错误，Vivado 无法检测子板上的短路。载板 J5 的正确定义为：

| 接点 | ZC706 定义 | 子板当前连接 | 必要修改 |
|---|---|---|---|
| H38 | LA32_N（Y27） | VADJ | 断开 VADJ，接 LATCH_CLK3 |
| H39 | GND | VADJ | 改为 GND |
| H40 | VADJ | GND | 改为 VADJ |
| G38 | GND | VADJ | 改为 GND |
| G39 | VADJ | VADJ | 保留 |
| G40 | GND | GND | 保留 |

按当前子板原图插接会通过 H39、H40、G38 的错误连线把载板 VADJ 与地短接。完成以上修改前，不应按当前图直接插接上电。此处是已核对的 VADJ 局部修正，不代表其余电源、接地引脚已全面审查。

## FPGA 验证

使用本机 Vivado 2020.2，在独立内存工程验证全部 20 路同源输出：200 MHz SYSCLK → IBUFDS → 1 BUFG → 20 ODDR → 20 OBUF。每个输出使用 LVCMOS25、DRIVE 8、SLEW SLOW。

实际结果：综合、布局、布线和 bitstream 生成全部通过；22 个端口（20 输出及 2 输入）的球位比对全部一致；布线错误为 0。仅保留未实例化 PS7 的 ZPS7-1 警告，无错误或严重警告。最终运行结果见 lpc_revised20/result.txt；最终引脚逐项比对见 lpc_revised20/pin_verification.txt；布线/DRC/资源报告在同目录。未修改原 xpr、未下载硬件。测试验证 FPGA 引脚与资源合法性，不验证子板 595 的工作频率、板级时序或外部负载。

复现（在当前目录）：

```bash
/home/yyz/vivado2020.2/main/Vivado/2020.2/bin/vivado -mode batch -source run.tcl -tclargs lpc_revised20 -log lpc_revised20.log -journal lpc_revised20.jou
```
