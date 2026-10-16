# config915 执行及射频回接准备

用户文件config915（AD936x Evaluation Software 2.1.4，LTE10，REF40MHz）已编译嵌入并通过Vitis XSCT的下载脚本在开发板执行，未改动原文件，未写Flash。SHA256见result.json。现有bit/XSA保持12taps/FALLING_EDGE_DELAY1版本，本次仅修改裸机程序。

## 如何执行

默认AD_CONFIG_USE_CONFIG915=1，main调用config915专用路径，跳过原no-OS初始化和RX内部BIST，避免覆盖用户配置。ad_config/config915_data.h是原脚本的2568条操作表，保留原文件行号。执行器位于ad_config/ad_config.c的ad_config_init_915，使用现有PS SPI0/SS0和RESETB GPIO54。10个SPIRead、2543个SPIWrite、8个WAIT_CALDONE及普通等待/复位均处理；生成表的全部2543个SPIWrite已与原始行逐项比较通过。后续修改原文件时须重新生成操作表、编译下载，运行中不会读取主机文件。

## 明确的适配与补充

- 原脚本00917是外部参考旁路。FMCOMMS3使用晶体，执行时改00907，并在BBPLL校准前设置DCXO coarse8/fine4096（29208、29400、29380）。原文件本身没有DCXO调谐写入。
- RESET_FPGA映射到main对采集/FIFO/DMA的FCLK0复位；BlockWrite2,6属于ADI评估FPGA SPI分频设置，此载板继续用已验证的PS SPI约651kHz。REFCLK_Scale仅是GUI脚本变量，不作芯片寄存器写入。
- 0A3遵循原注释的masked-write语义，保存低6位，仅改高2位。
- 源文件结束仍在强制ALERT且启用了引脚控制。校准完成后补01423，使用SPI进入FDD；确认017低4位=A。
- 源文件未启用测试音。补充3F500、3F630、3F453，使用TX内部BIST给TX1发送Fs/16单音；屏蔽TX2的BIST I/Q。RX内部BIST关闭，接收数据来自真实RF输入。
- 原始010C8、0060F、03D00/03E00先按文件执行。随后测试010C8/C9两种极性、各256个006延时，无通过点；最终恢复原始010C8/0060F，未改频率、滤波器和增益设置。

## 上板结果

2568/2568操作完成，8项校准等待通过，最终01600。读回BBPLL983.04MHz、ADC/DAC245.76MHz、RX/TX Fs15.36MSPS、RX/TX LO914999999Hz。00403选择RX1A/RX2A差分输入、TX1A/TX2A输出。PLLs20/20锁定，MIG9/9通过、0错误、7520812字。

FRAME0/20、延时扫描0/512；GPIO01（READY1、LOCKED0），ARM0。未启动DMA采集，无本轮IQ文件。200MHz ILA窗口计数184325，与预期61440不符；这是诊断异常，不能直接当作物理DATA_CLK频率或认定根因。自发自收还未验证。当前TX1 BIST寄存器53已读回，但没有频谱仪/功率测量证明实际RF发射输出。

## TX/RX接线

先使用一根50欧同轴链路：**板上TX1A -> 30dB固定衰减器 -> RX1A**，TX2暂不用。文件TX1/2衰减均20dB，TX1数字BIST幅度-6dBFS，LO915MHz、单音偏移约960kHz。上/下边带取决于I/Q设置，接收基带应在±960kHz附近找峰。软件衰减不替代外部衰减器的测试保护作用；初次回接不要跳过外部衰减。若丝印简写TX1/RX1，请按FMCOMMS3的A端口对应连接，勿接FMC数字引脚或TX监测口。

当前程序保持TX测试音开启、ARM0，供接线后测试。只有FRAME修复并采到有效IQ后，才能用FFT验证RF回接，不应将配置PASS/PLL锁定等同于自发自收通过。若需停止测试音，清除3F4的bit0即可（例如写52）。

记录：uart.log、baseline_uart.log、board_memory.txt、rx_diag.csv、ddr_diag.csv、ila_status.txt、build.log、download*.log、result.json。
