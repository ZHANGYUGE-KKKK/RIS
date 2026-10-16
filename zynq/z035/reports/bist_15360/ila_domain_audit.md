# 实现网表的 ILA 时钟域核查

2026-10-15，通过现有Vivado GUI查询impl_1和Hardware Manager，未改设计。

hw_ila_2对应ila_rx_frame，采样时钟clk_pll_i，周期5.000ns，来自MIG ui_clk/ref_clk200。全部14组探针共193位的驱动寄存器时钟均为同一个clk_pll_i。probe4的rx_counter_ref实际由XPM Gray CDC的dest_out_bin_ff_reg驱动，3级同步、目的域输出寄存；probe3/probe2为目的域计算的计数和活动标志；probe0/1/5..13为XPM握手快照在ref_clk200域的寄存结果。没有直接把原始RX总线接入此ILA。

RX源时钟是rfmc_rx，诊断Gray和握手模块的src_clk=rfmc_rx、dest_clk=clk_pll_i。源域与ILA不同，但过CDC后探针与ILA相同。probe5..13是首次故障/超时上下文快照，不能当作连续原始RX波形。

RX探针到ILA输入管线最差setup裕量+3.344ns、hold+0.095ns。此结果排除“ILA2直接使用200MHz异步采原始RX多位总线”这一接法错误，不等于证明CDC复位、源计数器或输入时钟完全正常。

hw_ila_1对应ila_ddr，时钟sys_clk_p，是板载差分200MHz经缓冲的时钟；部分探针源属于MIG clk_pll_i域。两者同频但不同域，具有共同参考和可分析的相位关系；探针路径在STA中受检查，最差setup+1.176ns、hold+0.817ns。LOCKED是MMCM状态输出，不能把它视为普通数据寄存器信号。

逐探针驱动/时钟见ila_clock_domains.txt，时序和实际硬件core编号见ila_probe_timing.txt。当前计数异常不能归因于ILA采样时钟域接错；仍需继续审查源计数/CDC复位与输入信号。
