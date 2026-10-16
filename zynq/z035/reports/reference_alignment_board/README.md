# 12 taps / 参考下降沿配对：XSA构建和上板调试

2026-10-15 完成。当前源码、导出的XSA、Vitis key_ctrl平台和开发板均为本版。XSA：`../../pz7035_top.xsa`；bit/LTX：`../../PZ_UART.runs/impl_1/pz7035_top.bit`、`.ltx`。原版保存在backups/before_reference_alignment_build_20261015_142514。

## 硬件与构建

D0..D5及FRAME七路均12taps，FALLING_EDGE_DELAY=1，沿配对和原参考一致。PS AXI100MHz，MIG UI/诊断ILA200MHz。Vivado GUI中重新生成BD输出、综合、布局布线、bit及XSA，最后实现和硬件ILA可在GUI查看。WNS +0.183ns、WHS +0.051ns、WPWS +0.062ns，违例端点0；脚本时序和bus skew检查通过。完整报告：../gui_rebuild_20261015_142536/。

XSA ZIP CRC与内嵌bit匹配通过；Vitis平台hw/tempdsa/export中的XSA一致，应用_ide/bitstream缓存与实现bit一致。通过Vitis XSCT更新并生成key_ctrl平台、编译应用，执行Vitis生成的下载脚本（系统复位、FPGA编程、loadhw、ps7_init/post_config、下载ELF、con）上板，未写Flash。GUI Run尝试未实际启动，随后以XSCT完成下载；不要将IDE.log旧启动记录当作本轮启动时间。实际下载记录见download_*.log。

## 对照结果

| 测试 | FRAME | MIG | IQ |
|---|---|---|---|
| 参考极性、00604、12taps/下降沿一拍 | 0/20；从未锁定 | 9/9通过 | 未启动 |
| 参考极性扫描006全部256点 | 0/256点 | 9/9通过 | 未启动 |
| DATA_CLK反相、扫描006 | 首轮67/256点，选13后20/20 | 9/9通过 | DMA128KiB完成，周期不一致2199项 |
| DATA_CLK反相、扫描67个FRAME候选点的BIST | 没有找到零错误IQ点 | 通过 | 最少518项，00669；这不是通过点 |
| 低速15.36MSPS/BW5MHz/FIR4-128、反相DATA_CLK | 0/256点 | 9/9通过 | 未启动 |
| 最终恢复61.44MSPS/BW30.72MHz/FIR2-64 | 68/256点；选12后20/20 | 9/9通过 | DMA128KiB完成，周期不一致1666项 |

所有RF配置均成功、PLL连续20次锁定。最终FMCOMMS3使用板载40MHz晶体/DCXO、RX LO200MHz、TX LO5997MHz、MGC5dB、TX衰减0dB。**必要板级适配：invert_data_clk_enable=1（010=C9），006从04开始由FRAME窗口扫描选为12。**正常极性配合参考下降沿配对无FRAME窗口；该实验说明相对沿关系的适配有效，但不证明物理时钟极性/布线是全部IQ错误的根因。

## 最终结果与限制

最终PLL20/20、FRAME20/20、APU后续GPIO读取03，MIG9/9、0错误、7520812字。DMA完成4包/131072字节/16384组IQ，内部RX BIST 3.84MHz、-6dBFS（3F4=5B）。IQ周期检查1666项不一致，故测试result=-1，**全采集链路尚未通过**。malformed=0仅表示12位符号范围符合，不是无误码证明。final_iq.bin为真实本轮DMA数据，但含错误，只供诊断；不是已验证正确的ADC数据。恢复成功，ARM=0，BIST关闭（3F4=12）。当前启动会扫描FRAME并做一次BIST，完整BIST候选扫描默认关闭。

最终200MHz ILA窗口计数245766（按CSV radix解析后的十进制），等效245.766MHz，接近预期245.76MHz。低速窗口计数129679，与预期不符；该诊断不能代替示波器，也不能唯一认定模拟时钟或CDC故障。当前200MHz ILA主要读同步状态/握手快照，不能据此直接观察全部连续原始双沿数据。

下一步需要检查输入信号与采样窗口：DATA_CLK/FRAME物理波形和终端，以及各条数据lane的延时/PN错误窗口。仅共享延时或FRAME锁定还不足以证明六条数据lane正确；当前尚未建立按lane的PN误码校准。

## 文件

- final_uart.log、final_memory.txt：最终串口及APU诊断。
- final_iq.bin：最终16384组`{I1,Q1,I2,Q2}`的little-endian int16数据，已知未通过BIST。
- rx_diag.csv、ddr_diag.csv、ila_status.txt：最终硬件ILA抓取。
- baseline_*、scan_uart.log、inverted_clock_*、bist_scan_*、lowrate_*：各阶段原始记录。
- platform_update.log、build*.log、download*.log：平台更新、编译和板端下载。
- result.json：结构化结果及XSA/bit/LTX/ELF校验值。
