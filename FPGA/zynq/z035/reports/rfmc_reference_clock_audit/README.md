# RFMC6000 示例与当前 FMCOMMS3 的时钟核对

核对对象：adaloop_deepreads.zip中的vitis_7035/ad9361_app/src与pldma_test硬件。原硬件器件xc7z035fbg676-2、顶层dma_demo、活动约束adaloopfx180.xdc，不能直接套到当前xc7z035ffg900-2。本次为只读核对，没有更改当前软硬件配置。

## 参考时钟和最终参数

- radio_set.h设置reference_clk_rate=40000000、xo_disable_use_ext_refclk_enable=1，使用外部40MHz输入。main先配置CDCM6208并等锁定，再初始化AD9361。spi_ctrl.c的配置表标注40MHz参考；原板10MHz基准经CDCM6208生成AD9361参考。当前FMCOMMS3是板载40MHz晶体，必须保留内部DCXO使能（use_ext_refclk=0），不调用CDCM6208。
- 模板初始40MSPS、RX/TX LO2.4GHz、BW20MHz；main随后应用61.44MSPS、RX LO200MHz、TX LO5997MHz、BW30.72MHz、MGC5dB、TX衰减0dB。
- 61.44MSPS选择2倍/64taps FIR；15.36MSPS按同一参考选择逻辑应选4倍/128taps FIR。当前基础测试则是15.36MSPS、FIR旁路、BW5MHz，两者不等价。

使用参考原函数ad9361_calculate_rf_clock_chain在主机离线计算（rate_governor=1，RX/TX同速），结果见calculated_clock_chains.txt；它表示驱动规划，不是实测频率：

| 设置 | RX链：BBPLL/ADC/R2/R1/RF/样本，MHz | TX链：BBPLL/DAC/T2/T1/TF/样本，MHz |
|---|---|---|
| 原最终61.44MSPS，FIR2 | 983.04/491.52/245.76/122.88/122.88/61.44 | 983.04/245.76/122.88/122.88/122.88/61.44 |
| 按参考降到15.36MSPS，FIR4 | 983.04/491.52/245.76/122.88/61.44/15.36 | 983.04/245.76/122.88/61.44/61.44/15.36 |
| 当前15.36MSPS，FIR旁路 | 983.04/122.88/61.44/30.72/15.36/15.36 | 同RX链 |

40MHz参考到983.04MHz由分数N PLL实现，不要求整数倍频。

## FPGA时钟和采样细节

- RX DATA_CLK经IBUFDS+BUFG，作为IDDR、解码、DDS和TX ODDR的时钟；双RX LVDS DDR最终61.44MSPS对应DATA_CLK245.76MHz。若同接口降到15.36MSPS，则应为61.44MHz。
- 参考BD提供PS FCLK0=200MHz、FCLK1=100MHz、FCLK2=200MHz；AXI控制用FCLK1，IDELAYCTRL及延时加载用FCLK2。当前AXIS/AXI用PS100MHz，IDELAY/诊断用MIG UI200MHz，可在频率和用途上对应。
- 参考200MHz并非由AD9361 DATA_CLK倍频生成，不应强求它与RX固定相位；跨RX和PS/MIG域要用CDC。相同频率不代表同域。
- 原main写idelay_sel=0x7F、idelay=12，对数据和FRAME七路加载12taps；当前七路默认8taps。
- 原RX寄存器006=04；TX模板007=70但main随后写40。当前RX应用57（15.36MSPS测试未通过的恢复值）、TX40。
- 原SAME_EDGE_PIPELINED IDDR的下降沿再寄存一次，与上升沿配对；当前FMCOMMS3选择FALLING_EDGE_DELAY=0，二者不同，需要成套对照，不能只比较频率。
- 原活动XDC对RX时钟、FRAME和数据正端启用LVDS_25/DIFF_TERM=true；当前1.8V HR银行使用false。此差异需按实际VCCO和物理终端核对，不能直接照抄开启。

结论：软件时钟链和频率规划可以复现；40MHz参考源模式、板级引脚/电气约束、IDELAY及沿配对必须适配。完整trxloop还包含TX LVDS接口和DDS，当前RX采集RTL不能直接等同于完整示例。频率规划一致不代表FRAME/IQ已经正确，需上板检查。
