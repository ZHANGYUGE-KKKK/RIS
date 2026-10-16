> 最新：已执行用户config915（915MHz/Fs15.36MSPS），晶体模式适配及TX1内部测试音开启；PLL/MIG通过，FRAME0/512未锁定，尚无射频回接验证。见 [config915报告](../config915/README.md)。

> 最新：12taps/参考下降沿配对的新XSA已生成并上板。DATA_CLK反相后FRAME20/20、MIG9/9、DMA128KiB完成；IQ周期仍有1666项不一致，未通过。见 [最新报告](../reference_alignment_board/README.md)。

> 最新测试：2026-10-15 14:15:18，已切换RFMC6000最终61.44MSPS/FIR2参考配置。芯片配置与PLL通过，FRAME失败，DMA未启动。详见 [本轮报告](../reference_profile_run/README.md)。以下保留历史测试记录。

# FMCOMMS3 Rev.A / PZ7035-FH

**当前状态已更新：** 15.36MSPS / 960kHz基础BIST测试已通过Vitis下载并执行，初始化/PLL/MIG通过，但FRAME延时扫描0/256，DMA与PRBS未启动。最终配置、对照结果和原始证据见[基础BIST记录](../bist_15360/README.md)。以下为早期迁移记录，不能当作当前运行结果。

2026-10-15已完成硬件构建、XSA导出、软件编译和真实JTAG下载。AD9361 ID=0x0A、8次稳定读取、复位反馈0/1、RF校准和参数回读通过，晶体旁路位为0；20/20次PLL锁定检测通过。MIG内存测试9/9通过、0错误。原始记录见`uart.log`、`board_run.log`和`result.json`。

首次新板200MHz ILA采集：RX时钟活动=1，每1ms测得245766个边沿（约245.766MHz），DDR校准完成=1。采集状态0x01（READY=1、FRAME_LOCKED=0、错误=0），没有首次帧错误快照。当前只能确认初始化及DDR内存测试通过，不能宣称IQ帧锁定或RF到DDR数据采集通过。

后续通过Vitis GUI清理重建及实际下载，再次确认初始化/PLL/MIG通过。ARM=0扫描寄存器0x006的全部16x16时钟/数据延迟，未发现帧锁定窗口，扫描结束恢复0x04。扫描代码保留在main同文件，`FMCOMMS3_RX_DELAY_SCAN=0`默认关闭。接收诊断增加1048575周期未锁定超时快照；功能解码逻辑保持不变。证据见`vitis_uart.log`、`rx_delay_scan_uart.log`和后续诊断记录。

当前子板为 AD-FMCOMMS3-EBZ Rev.A。原理图：`/home/yyz/ALLdoc/zynq035/ad-fmcomms3_reva.pdf`；载板原理图第18页为J26 FMC-HPC映射。

旧RFMC6000约束保留：`key_ctrl_55_jm1.xdc`的SPI0/SPI1/RESETB/CDCM_SYNC约束已注释，载板时钟/复位/KEY/JM1约束继续生效；`rfmc6000_iq_axis_io.xdc`所有命令已注释。新板物理约束集中在`fmcomms3_io.xdc`。现有接收RTL、FIFO/DMA/MIG和200MHz ILA继续使用，通用CDC/ILA约束保留。

| 信号 | FMC | FPGA |
|---|---|---|
| SPI DI / MOSI | C26 | AF30 |
| SPI DO / MISO | C27 | AG30 |
| SPI CLK | D27 | AK30 |
| SPI ENB / CS0 | D26 | AJ30 |
| RESETB | H31 | AC29 |
| DATA_CLK P/N | G6/G7 | R27/T27 |
| RX_FRAME P/N | D8/D9 | R25/R26 |
| RX_D0 P/N | H7/H8 | P21/R21 |
| RX_D1 P/N | G9/G10 | N28/P28 |
| RX_D2 P/N | H10/H11 | T24/T25 |
| RX_D3 P/N | D11/D12 | U22/V22 |
| RX_D4 P/N | C10/C11 | T30/U30 |
| RX_D5 P/N | H13/H14 | N29/P29 |
| ENABLE | G18 | P25 |
| TXNRX | G19 | P26 |
| EN_AGC | H22 | T22 |
| SYNC_IN | H23 | T23 |

SPI0保留Mode1、SS0、MSB-first、四线、PCLK/256；GPIO EMIO[0]仍是XGpioPs pin54，物理RESETB位置变为AC29。顶层固定ENABLE/TXNRX/EN_AGC/SYNC_IN为低，ENSM和MGC通过SPI配置。旧SPI1和CDCM_SYNC不再引出：BD撤去SPI_6208外部接口，SPI1的MOSI/MISO/SCLK输入接0、SS输入接1，避免生成无物理管脚的IOBUF。PS外设参数和地址定义保持不变。

Y101是40MHz晶体，启用AD9361内部DCXO：`xo_disable_use_ext_refclk_enable=0`、DCXO tune={8,5920}。AD9361初始化及连续20次PLL锁定检测不再访问CDCM6208；其旧驱动仅保留源码。RX配置仍为2R2T FDD/LVDS DDR、61.44MSPS、30.72MHz带宽、RX LO200MHz、TX LO5997MHz、MGC5dB，RX1/RX2选择A口。FIR和数据格式沿用已有链路。新板采样延迟需要重新实测，不把旧板延迟值当作已验证结果。

程序顺序：保持采集/FIFO/DMA复位；SPI与硬件复位、8次ID核验；DCXO/RF初始化和校准；参数与0x009的XO_BYPASS=0回读；释放采集复位；初始化PL驱动；连续20次BBPLL/RXPLL/TXPLL检测。`FMCOMMS3 INITIALIZATION PASS`仅表示上述AD9361初始化与锁定检测成功。ARM保持0；采集帧锁定、DDR/DMA、射频IQ是否正确仍分别报告。

载板默认VADJ及LA Bank为1.8V；单端使用LVCMOS18，LVDS输入为LVDS_25/DIFF_TERM=false。UG471第49页要求HR银行的内部100Ohm LVDS_25终端在VCCO=2.5V下使用，故不能在当前1.8V下直接启用。新子板图中未见RX端外部100Ohm终端；采样信号完整性和终端方案仍需验证，SPI/RF初始化通过不代表无丢样采集。

重建：`vivado -mode gui -source scripts/build_fmcomms3.tcl`。软件：source Vitis2020.2 settings64.sh后，在`vitis_code/key_ctrlll/Debug`执行`make main-build`。

初始化参数与ADI FMCOMMS参考一致：
[ADI no-OS 2019_R1 main.c](https://github.com/analogdevicesinc/no-OS/blob/2019_R1/ad9361/sw/main.c)；[ADI FMCOMMS2/3设备树](https://github.com/analogdevicesinc/linux/blob/main/arch/arm/boot/dts/adi-fmcomms2.dtsi)。
