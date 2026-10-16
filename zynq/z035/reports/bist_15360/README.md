# FMCOMMS3 基础 RX BIST 上板测试

2026-10-15 13:21:29，使用 Vitis 2020.2 实际下载当前 bit/ELF，PuTTY 接收串口。**测试已执行，接收接口未通过。没有本次有效 IQ 数据文件。**

最终配置：板载40MHz晶体/DCXO，双RX/双TX FDD LVDS DDR，Fs=15.36MSPS，RX/TX配置带宽5MHz，RX/TX FIR旁路，LVDS幅度150mV。RX LO200MHz、TX LO5997MHz、两路MGC5dB保留。200MHz ILA/IDELAY、100MHz AXIS和FPGA bit/XSA保持不变。

官方BIST例子：<https://ez.analog.com/cfs-file/__key/communityserver-discussions-components-files/323/AD9361BISTFAQ.pdf>。本次确实开启RX端口内部960kHz、-6dBFS测试音并回读0x3F4=0x5B；该刺激位于数字RX端口，不能代表模拟RF链路。

| 检查 | 实际结果 |
|---|---|
| SPI/RESETB/芯片ID、初始化/校准 | PASS，stage4/result0 |
| 采样率/带宽/FIR和时钟链查询 | 15.36MSPS / 5MHz / FIR旁路 |
| BBPLL/RXPLL/TXPLL | 20/20 PASS |
| RX寄存器0x006全部16×16延时扫描 | 0/256 FRAME通过点 |
| FRAME稳定性 | 0/20，GPIO状态0x01 |
| MIG CPU内存测试 | 9/9 PASS，0错误，7520812 word |
| DMA IQ / FFT / PRBS检查 | 前置FRAME未通过，未启动 |
| 结束状态 | BIST OFF(0x3F4=0x12)，ARM=0，GPIO状态连续10次为0x01 |

RX/TX时钟链均为：983.04 → 122.88 → 61.44 → 30.72 → 15.36 → 15.36 MHz。原始BBPLL寄存器041/042/043/044/045=12/5C/29/18/00，00A=B3。按双通道LVDS DDR，预期DATA_CLK=61.44MHz。

ILA中的计数不符合预期，且rx_counter_ref存在倒退，因此不能把edges_per_ms直接换算为可靠的物理频率。需要检查DATA_CLK差分波形/终端与计数CDC的健康状态，不能只根据该计数认定模拟频率或唯一根因。当前VADJ=1.8V、LVDS_25/DIFF_TERM=false；原理图未见RX外部100Ohm终端，终端/信号完整性是待核查项。

对照证据：initial_uart.log/rx_initial.csv为FIR开启、150mV；slow_slew_uart.log/rx_slow_slew.csv为调整03B时钟slew；300mv_uart.log/rx_300mv.csv为驱动300mV；fir_bypass_uart.log/rx_fir_bypass.csv为FIR旁路。以上均未找到FRAME锁定窗口。最终uart.log是在FIR旁路并提前开启BIST刺激的情况下扫描，仍未通过。0x57只是失败后恢复的原值，不是15.36MSPS的有效延时。

当前源码包含自动FRAME窗口筛选、BIST寄存器核验、16点周期检查和明确的跳过提示。原61.44MSPS软件备份位于backups/before_bist_15360_20261015。原始记录、最终诊断内存和构建日志分别是uart.log、board_memory.txt、build.log；参数和产物哈希见result.json。Vitis与PuTTY保留打开。
