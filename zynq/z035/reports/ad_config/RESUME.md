# AD9361 / CDCM6208 续做记录 — 2026-10-13

用户明确要求：今天停在这里，CDCM6208 的驱动和硬件支持尚未完成，明天继续。

## 当前代码和板上结果

- 配置及参考 no-OS 核心已放入 `vitis_code/key_ctrlll/src/ad_config/`。
- `ad_config.c/.h` 是应用接口；`radio_set.h` 是参考初始化参数和四组 RX/TX FIR。
- `helloworld.c` 的 main() 在 MIG 自检之后调用 `ad_config_init(&rf_config, &radio)`。
- 先使用原模板：40 MHz REF、2.4 GHz RX/TX LO、40 MSPS、20 MHz BW。
  初始化成功后才应用 7035 示例最终参数：61.44 MSPS、30.72 MHz BW、
  RX LO 200 MHz、TX LO 5997 MHz、两通道 MGC 5 dB、TX 衰减 0 dB。
- `rx_frame_pulse_mode_enable=1` 必须保留，表示 50% 占空比重复帧，符合当前采集 RTL。
  之前建议改成 0 是错误的，已向用户纠正。
- 现有 `drivers/ad9361.c/.h` 增加了 3..10 字节连续 CS 的有界 SPI 传输 API，
  保留 SPI0 EMIO / SS0 / mode 1 和原有在线检查功能。
- no-OS 的 init/reset 改名为 `ad9361_noos_init` / `ad9361_noos_reset`，避免旧驱动符号冲突。
- 适配层 RESETB 使用 PS GPIO 全局编号 54（EMIO[0]，FPGA T29），检查引脚反馈。
- 修正了参考驱动吞掉错误的问题：保留初始化原始 errno；校准读失败立即返回；
  util.c 的全部 7 个时钟设置调用传播 PLL/SPI 错误，失败后不更新成功状态。
- ARM 编译和链接通过；应用接口、平台适配、SPI 驱动、main 和修改后的 util.c
  通过严格编译（util.c 对参考代码原有 fallthrough 使用单独豁免）。
- 已用当前匹配的 bitstream/XSA 下载并执行两次。最新 ELF 在 `key_ctrlll/Debug/`。
- 最新板上 MIG 自检：9/9 PASS、0 错误、7,508,012 个 32 位字、4,802 ms。
- 最新 AD9361 配置：stage=1、result=-110；0x05E 的 BBPLL_LOCK（0x80）一直为 0。
  SPI transport_error=0，完成读 5,048 / 写 26 字节，配置尝试耗时 875 ms。
- 首次运行还出现 0x244 的 RX CP 校准超时；参考代码忽略 BBPLL 失败继续执行所致。
  修正返回传播后，最新代码正确停在第一个 0x05E / 0x80 超时。
- 尚未完成完整 RF 初始化，尚未加载最终 FIR/频点参数，capture ARM=0，DMA 未启动。
- 当前 XSA/顶层没有 CDCM6208 SPI 和控制 GPIO，不能直接执行参考时钟初始化。
  以上超时与缺少有效参考时钟一致，但尚未测量 AD9361 实际 REF 输入频率/波形。

## 明天从这里继续

1. 核对 RFMC6000 原理图、参考工程和当前主板 FMC 接线，确定 CDCM6208 所需管脚。
   参考方案使用 PS SPI1（mode 0）以及 CDCM_SYNC、REF_SELECT/REF_SELECT2 等 GPIO。
   当前只有 AD9361 SPI0 和 RESETB 已引出；不要套用示例 EMIO 编号 0..9。
2. 如需硬件改动，补充 BD、顶层和 XDC，保留当前 SPI0、RESETB、RIS GPIO、采集、DMA、MIG。
   为新增 GPIO 分配 EMIO 位并同步软件编号；检查 FPGA 引脚、IOSTANDARD、时钟和复位。
3. 实现 CDCM6208 驱动，复用参考 `spi_ctrl.c` 的 `cdcm6208_init_data[]`（40 MHz REF）。
   保留寄存器读写与锁定反馈，所有传输/等待加超时；按参考完成 SYNC 脉冲。
   参考主流程读取寄存器 21 的低四位等待 0，随后执行 SYNC。
4. 新硬件/XSA 到位后同步 BSP/下载配置，先验证 CDCM6208 SPI 回读、状态和实际 40 MHz 输出。
5. 再重试现有 `ad_config_init()`，要求校准成功、PLL 锁定、Fs/BW/LO/增益/FIR 回读通过。
6. 记录采集 GPIO 的 ready/frame/fault 状态，再规划 RX 数据/PN 对齐和 DMA 测试。
   改变 RF 时钟可能导致采集 RTL 的锁定/错误状态变化，状态清除涉及 PL 复位，需要单独核对。

## 可复用来源与证据

- 原参考代码：`reference/rfmc6000_7035/src/`，24 个原文件已与压缩包逐文件校验一致。
- 配置来源：`/home/yyz/ALLdoc/RFMC6000/3 FPGA测试例程/adaloop_deepreads.zip` 内
  `adaloop_deepreads/vitis_7035/ad9361_app/src/`。
- 参考时钟配置：`reference/rfmc6000_7035/src/spi_ctrl.c:9`。
- 板上日志：`reports/ad_config/board_run.log`；首次结果：`board_run_initial.log`。
- 结构化结果：`reports/ad_config/result.json`；首次串口截图：`uart_initial.png`。
- 当前诊断结构：`ad_config_report` 在 PS DDR 0x0013C98C，共 33 个 32 位字段；
  `mig_test_report` 在 0x0013C8A8。重新链接后应从 ELF nm 获取地址，不要固定照抄。
- 原应用备份：`backups/before_ad_config_20261013_170327/`。
- 正式构建：source Vitis 2020.2 settings64.sh，再在 `key_ctrlll/Debug` 执行 make main-build。
  makefile.defs 对 ad_config 提供 CLI 回退，Vitis 生成对应对象后避免重复链接。

## 尚待收尾的验证/文档

- SPI 适配层 host 测试已写在 `/tmp/ad_config_tests/test_port.c`，最后编译未完成：
  借用的旧 stub xil_types.h 缺 s32。需要补 host stub 后运行；这是测试环境问题，
  实际 ARM 代码已编译并在板上执行。不要把该测试记为通过。
- 还没有为 src/ad_config 写模块 README；继续时补充接口、来源、修改点和硬件依赖。
- 用户此前不希望工程里出现无必要 Python 脚本；本次只使用临时/内联脚本。

## 可用工具与设备

- Vivado/Vitis 2020.2：`/home/yyz/vivado2020.2/main/`。
- hw_server：localhost:3121；JTAG-HS1 210512180081；device xc7z035。
- 串口：/dev/ttyUSB0（PuTTY 已占用），不要额外进程抢读。
- 下载前验证 cable/device 目标唯一；避免使用泛匹配 APU* 操作其他项目的板。
- 当前 bitstream：`PZ_UART.runs/impl_1/pz7035_top.bit`；XSA：`pz7035_top.xsa`。
- 当前 Vitis app：key_ctrlll；platform：key_ctrl。

## 2026-10-14 已恢复：连线核查完成

SPI1/GPIO 接法已核对，详见 [CDCM6208_CONNECTIONS.md](CDCM6208_CONNECTIONS.md)。
按 FMC 触点编号映射，不能只匹配 LAxx 标签；尚未修改 BD 或实现 CDCM6208 驱动。

## 2026-10-14 顶层和 XDC 已更新

用户新 BD 的 SPI1 外部接口实际名为 SPI_6208；wrapper 生成时间 11:34:28。
已在 pz7035_top.v 引出 io0/io1/sck/ss 四根线，SS1/SS2 仅在例化端悬空。
key_ctrl_55_jm1.xdc 已绑定 AK26/AE26/AA30/AJ26，LVCMOS18，CS 上拉。
Vivado RTL 展开和引脚检查通过；无 DEFAULT IOSTANDARD、无未绑定顶层引脚、无重复绑定。
现有端口/宽度/连线及既有 XDC 命令已与备份校验保持一致。
用户新 BD 的 GPIO EMIO 宽度仍为 1，因此 CDCM_SYNC/REF_SELECT2/REF_SELECT 尚未接入。
若补齐三个控制引脚，先将 BD GPIO 改为 4 位并重新生成 wrapper，再同步顶层与约束。
尚未重新运行完整综合/布局布线或导出本次 XSA。

## 2026-10-14 11:55 本次 XSA 已生成

在当前 Vivado GUI 内完成全新 synth_1 / impl_1 / write_bitstream，并导出含 bitstream 的 pz7035_top.xsa。
建立 WNS +0.183 ns、保持 WHS +0.052 ns、脉宽 WPWS +0.062 ns；失败端点均为 0，bus skew 最小裕量 +3.364 ns。
DRC 0 Errors / 2 Warnings / 2 Advisories；未降低任何 DRC 严重级别或放宽时序约束。
XSA ZIP CRC、内嵌 bitstream 与 impl_1 一致、HWH 与 Output Products 一致、SPI1 EMIO 启用均已核验。
SPI1 基址 0xE0007000，GPIO EMIO 仍为 1 位，仅 RESETB；CDCM_SYNC / REF_SELECT2 / REF_SELECT 三个控制引脚仍待后续 BD 修改。
ILA 文件为 PZ_UART.runs/impl_1/pz7035_top.ltx（亦有同内容 debug_nets.ltx）。
当前 GUI 保持最终 Implemented Design，显示本次时序摘要。未更新 Vitis 平台/BSP，未向板卡下载。
证据：reports/gui_rebuild_20261014_114817/xsa_verification.json、timing_route.rpt、bus_skew.rpt、drc.rpt、vivado_final.png。
XSA SHA256：0060a537c2b998bafe40ebe740239790f38dedc234bc6565d91c542db88bcb81。

## 2026-10-14 CDCM6208 驱动和板上 RF 配置已通过


新增 drivers/cdcm6208.c/.h，SPI1 EMIO/SS0/Mode0/651041 Hz，32位连续CS帧，20ms传输超时，独立SPI1实例。
R40=0x0102，R0..20共21个配置回读全部通过，R21=0，R3.5执行软件同步。
R4从参考0x306C改为0x206C，强制板载主参考，不依赖REF_SELECT2。
根因已确认：未引出的AG26被FPGA默认下拉，物理CDCM_SYNC低禁止输出，故CDCM内部锁定但AD9361 BBPLL超时。
仅改变unused-pin下拉的临时bitstream使AD9361初始化立即通过；正式方案新增顶层cdcm_sync在AG26/LVCMOS18固定输出高，保留其他unused-pin原设置。
未修改BD、wrapper或IQ接收RTL，GPIO EMIO仍为1位RESETB。未来GPIO驱动SYNC需先移除常量输出避免引脚冲突。

正式综合/实现/bitstream/XSA在Vivado GUI完成：reports/gui_rebuild_20261014_121349。
WNS +0.183 ns/WHS +0.052 ns/WPWS +0.062 ns，bus skew +3.364 ns，DRC 0 Errors。
XSA ZIP、内嵌bit、HWH校验通过；HWH与上一版相同，接口/地址/BSP定义不变。
Vitis GUI已更新key_ctrl硬件规格并Build平台和key_ctrlll应用，托管构建已包含新驱动。
平台hw/tempdsa/export和应用_ide bit/psinit均已同步。开发板已实际JTAG下载，未写Flash。

main先通过SLCR FPGA_RST_CTRL[0]保持采集/FIFO/DMA/GPIO复位，配置CDCM、RESETB和AD9361全套RF，再释放复位、初始化PL驱动。
最终GUI构建的ELF经两次完整重下载复测，CDCM result=0、AD_CONFIG stage=4/result=0、RF_CLOCK_TEST 20/20连续2秒锁定，全部通过。
Rx/Tx Fs61440000，BW30720000，RxLO200MHz/TxLO5997MHz，MGC5dB，FIR均开启；BBPLL=80/81，RxPLL=02，TxPLL=02，校准寄存器016=00。
尚未测量真实参考时钟频率/幅度/抖动；本次通过的是寄存器回读、RF校准和连续数字PLL锁定。

剩余独立问题：采集GPIO=0x11（READY=1/FRAME_LOCKED=0/FRAME_ERROR=1），DMA init返回-8，MIG本次因采集/DMA前置条件而跳过，不是发现DDR内存错误。
因此整体main返回1，不能把本次RF配置通过称为IQ采集通过。ARM一直为0，没有启动DMA。
临时扫描RX时钟delay 0..15未发现FRAME窗口；实验已从正式main移除，最终006仍0x04。
后续需检查参考RX_FRAME时序、RTL IDDR/配对/解码、实际引脚和采样窗口，再做PN和DMA验证。
本次GUI/下载最后运行均以正式bit而非诊断Pullnone bit完成，仍保持默认unused-pin策略。
证据和最新成功结果：reports/cdcm6208/result.json、uart.log、gui_run1_memory.txt、gui_run2_memory.txt、uart_final.png。
当前报告地址：cdcm6208_report=0x0013C8E8、ad_config_report=0x0013C97C、rf_clock_test_report=0x0013CAE4，之后重新链接须从ELF nm重取。
串口设备重枚举为/dev/ttyUSB1，已重开PuTTY固定CP2102 by-id路径，115200 8N1并开启日志。
最终 XSA SHA256：7d5ece8adb4b3492312ce72cb707e12e49de62a2b452a9341dbba8d07e5345c3。

## 2026-10-14 内部 RX ILA 与新的 FRAME 排查状态

新增MARK_DEBUG及implementation-only的rfmc6000_iq_axis_ila.xdc，ila_rx_frame为19探针/105bits、2048深度、两级输入流水线，现版时钟仍为RX BUFG。采集功能RTL、BD、顶层和既有约束未改变，四组仿真通过。综合/布局布线/bitstream/XSA已完成，WNS+0.183ns、WHS+0.052ns、WPWS+0.062ns、DRC 0 Errors。匹配bit/LTX为PZ_UART.runs/impl_1/pz7035_top.bit/.ltx，Vitis缓存已同步。

用户在Vitis GUI于14:51:43下载新bit和原有正式ELF，RF配置及20次锁定检测均通过，但ILA2仍报clock stopped，尚未有有效RX ILA波形。实现网表确认ILA2与IDDR使用同一RX BUFG。ARM=0采集复位诊断，释放10ms/110ms后均恢复0x11，说明RX路径有活动并重新触发帧错误，不证明连续时钟频率。

用户要求ILA2使用ref_clk200，随后要求先重新定位并讨论是否必须使用ILA；当时仅建立备份before_ila_ref200_20261014_150114。rx_frame_pulse_mode_enable=1在ADI定义中就是50%周期FRAME，当前配置并无此项矛盾。详细证据reports/rx_frame_ila/verification.json、clock_netlist_summary.txt、pl_reset_diagnostic.txt、diagnosis.md。

## 2026-10-14 15:31 200 MHz ILA 版本已导出

按用户要求完成ref_clk200诊断版本至XSA。RX域锁存首个锁定后FRAME故障及前8个FRAME对，通过XPM握手整体传入200MHz；RX计数通过XPM Gray CDC跨域，每1ms测量时钟活动和频率。原采样/AXIS功能未改变。ILA2为14探针/193bits，深度2048、输入流水线2级，实际时钟周期5.000ns（MIG ui_clk），已有DDR ILA保留。

Vivado GUI完成综合、布局布线、bitstream和XSA，最终Implemented Design及时序报告保持打开。WNS+0.183ns、WHS+0.052ns、WPWS+0.062ns、失败端点0、bus skew最小裕量+3.337ns，DRC 0 Errors。四组接收仿真通过，新增快照完整性、245.76MHz频率测量和外部停钟后诊断保留测试通过。

XSA ZIP CRC/内嵌bit匹配实现bit/LTX探针匹配均已核验；HWH规范化内容与上一版相同，ps7_init.c/tcl未改变。Vitis key_ctrl的hw/tempdsa/export和key_ctrlll的_ide bit缓存已同步。此版本尚未下载到板卡，FRAME_ERROR根因及射频/DMA全链路尚未确认。

文件：pz7035_top.xsa、PZ_UART.runs/impl_1/pz7035_top.bit/.ltx。XSA SHA256=34f1d285b6cc6dbf86e6b55001e25474882e9a92e2503ac2661b7bbb49b87733。报告：reports/gui_rebuild_20261014_152018，探针说明：reports/rx_frame_ila/README.md。

## 2026-10-15 当前默认子板切换为 FMCOMMS3 Rev.A，初始化已实测通过

用户已换板，今后使用AD-FMCOMMS3-EBZ Rev.A，原理图为/home/yyz/ALLdoc/zynq035/ad-fmcomms3_reva.pdf。旧板key_ctrl_55_jm1.xdc内SPI0/SPI1/RESETB/CDCM_SYNC命令及rfmc6000_iq_axis_io.xdc命令全部注释保留，新板约束集中fmcomms3_io.xdc。SPI0 MOSI/MISO/SCLK/CS改为AF30/AG30/AK30/AJ30；RESETB为AC29（FMC H31），仍是EMIO0/GPIO54。RX clock为R27/T27、FRAME为R25/R26；数据映射见新XDC和reports/fmcomms3/README.md。

新板没有CDCM6208，软件停止其初始化和锁定检查，启用Y101 40MHz晶体/DCXO（xo_disable_use_ext_refclk_enable=0，tune={8,5920}），新增0x009旁路位回读。顶层固定ENABLE/TXNRX/EN_AGC/SYNC_IN为低，ENSM由SPI控制。BD撤去SPI_6208外部接口并内部固定输入，避免悬空IOBUF布局失败；SPI1仍在PS中启用，其他PS/IP参数、软件地址和ps7_init保持不变。没有修改接收解码/AXIS/CDC功能或200MHz ILA。

Vivado GUI完整构建、XSA导出通过，最终报告reports/gui_rebuild_20261015_120023。WNS+0.183ns/WHS+0.052ns/WPWS+0.062ns，失败端点0，bus skew最小裕量+3.148ns，DRC0 Errors。XSA内嵌bit核验通过，Vitis平台hw/tempdsa/export与应用_ide bit已同步，软件编译通过。

12:09:31通过JTAG下载新bit/ELF并ps7_init/post_config执行，未写Flash。串口实测ID0x0A、8次稳定读取、复位反馈0/1、AD_CONFIG stage4/result0/653ms，0x009=07且XO_BYPASS=0。RF CLOCK TEST20/20通过，BBPLL80、RXPLL02、TXPLL02。保留运行配置RX/TX Fs61.44MSPS、BW30.72MHz、RX LO200MHz/TX LO5997MHz、MGC5dB。程序先报告FMCOMMS3 INITIALIZATION PASS再执行MIG测试，MIG9/9通过、0错误、7520812字、4752ms。

当前ARM=0，采集状态0x01：READY1、FRAME_LOCKED0、错误0。200MHz ILA已实际采到2048点，RX活动1、每毫秒245766边沿（约245.766MHz）；首次帧错误快照有效位0。DDR ILA：ui_rst0、aresetn1、locked1、calib_complete1。新板初始化和DDR内存测试通过，但IQ帧未锁定，RF到DDR完整采集仍未验证。载板VADJ1.8V；HR LVDS_25内部终端不能在该电压下直接开启，原理图未见RX外部100Ohm，终端/信号完整性待核对。

证据：reports/fmcomms3/result.json、uart.log、board_run.log、rx_diag.csv、ddr_diag.csv。当前XSA SHA256=345fe02b3710e6cddcce3d3b311a3c372c25950f68241e2d592427f03b5669ec。当前ad_config_report=0x0013C93C、rf_clock_test_report=0x0013CAA8、mig_test_report=0x0013C9C4；重新链接后从ELF符号重新获取。

2026-10-15 13:21最新状态（更新以上历史结果）：用户要求执行ADI基础BIST方案。软件改为15.36MSPS、5MHz带宽、RX/TX FIR旁路，960kHz Fs/16测试音、-6dBFS，回读0x3F4=0x5B。保留40MHz晶体/DCXO、RX LO200MHz、TX LO5997MHz、MGC5dB、150mV LVDS。通过Vitis GUI实际下载并执行。时钟链RX/TX均983.04/122.88/61.44/30.72/15.36/15.36MHz；SPI/reset/RF校准/PLL20次/MIG9项通过。但RX延时16×16扫描0通过点，FRAME0/20，状态0x01，故DMA/PRBS未启动，不能宣称环回或IQ通过。最终BIST关闭(3F4=12)、ARM=0，APU连续10次GPIO读数01。ILA时钟计数异常且存在倒退，不可直接作为精确物理频率；需要检查DATA_CLK差分波形/终端及计数CDC健康状态，尚未确定唯一根因。

本次完整记录reports/bist_15360/README.md、uart.log、board_memory.txt、result.json；对照包含FIR启用、slew、300mV和FIR旁路，均未获FRAME窗口。代码在ad_config.h统一采样率/带宽/BIST周期，main加入自动FRAME窗口筛选与明确SKIPPED提示；PS诊断缓存刷新后可由APU读取。61.44MSPS旧软件备份backups/before_bist_15360_20261015。硬件没有因本次软件测试改动，仍为此前FALLING_EDGE_DELAY=0的bit/XSA；此前61.44MSPS曾通过FRAME20/20但IQ周期检查失败。最新结果以reports/bist_15360/result.json为准，不使用早期迁移JSON。Vitis、Vivado、PuTTY仍打开。


## 2026-10-15 14:15 复现参考最终配置
当前源码/ELF/开发板为61.44MSPS、30.72MHz、FIR2/64、RX LO200MHz、TX LO5997MHz、MGC5dB、TX衰减0、00604、00740，FMCOMMS3晶体模式0；自动延时扫描关闭、普通RX检查后才允许BIST。Vitis Run已执行，芯片配置PASS、PLL20/20；FRAME0/20最终11，DMA初始化-8、MIG CPU测试因前置条件跳过、无IQ采集。ILA窗口十进制245766，接近预期245.76MHz，故障快照C3C3。ARM0、BIST关闭。FPGA保持8taps/FALLING_EDGE_DELAY0，尚未改成参考12taps/下降沿延迟。详情reports/reference_profile_run/README.md。原低速源码备份backups/before_reference_profile_20261015_141426。


## 2026-10-15 参考输入延时/沿配对对齐
用户要求与参考对齐，已改RTL默认及BD实例INPUT_DELAY_TAPS=0x318C6318C(七路12 taps)、FALLING_EDGE_DELAY=1，构建脚本同步，Vivado GUI module reference更新、BD validate/save通过。未启动综合/布局布线，旧bit/XSA/开发板仍8taps/FALL_DELAY0，不要误认为改动已上板。测试与说明见reports/reference_input_alignment/。


## 2026-10-15 14:45 最新硬件构建和板端状态
七路12taps/FALLING_EDGE_DELAY1已完成综合/布局布线/bit/XSA，WNS+.183 WHS+.051 WPWS+.062，报告gui_rebuild_20261015_142536。XSA已更新key_ctrl平台、编译应用，并由Vitis生成的XSCT下载脚本上板。正常DATA_CLK极性FRAME扫描0/256；反相后67/256（最终68/256），FRAME20/20/MIG9/9/DMA128KiB成功，但IQ有错误。67候选BIST扫描最少518项（00669）仍失败。低速15.36/FIR4-128对照FRAME0/256，已恢复61.44/FIR2-64最终配置。当前软件DATA_CLK反相(010C9)，启动扫描006，最终选12，单次BIST16384组/131072字节周期不一致1666项，ARM0/BIST关闭，GPIO03。完整BIST扫描默认0，RxFRAME扫描1。当前bit/XSA已不是旧8taps版本。详见reports/reference_alignment_board/README.md和result.json，真实但有错误IQ在final_iq.bin。


## 2026-10-15 config915 最新状态
用户GUI2.1.4 config915已执行上板。原文件SHA28e37b4bc2a75e6dae62f51df779383cbeb23f7c2b2ae34e46cee9dcfdfef2fc未改，生成ad_config/config915_data.h并在ad_config.c增加执行器，ad_config.h默认AD_CONFIG_USE_CONFIG915=1，main专用路径绕过noOS/RX BIST。00917->07/DCXO8-4096、ADI FPGA命令映射、0A3 masked-write、末尾01423进FDD，并补TX1 BIST3F453/3F630/3F500。2568命令/8校准通过，RX/TX LO914999999Hz、Fs15.36MSPS、ADC/DAC245.76MHz；PLL20/MIG9通过。010C8/C9两极性各256点FRAME无通过，已恢复010C8/0060F/03D00/03E00；GPIO01 ARM0，TX BIST ON，RX BIST OFF。未采IQ/未验证实际RF回接或发射功率；接线TX1A->30dB衰减器->RX1A，TX软件衰减20dB。XSA/bit未改还是12taps/FALL1。备份backups/before_config915_20261015_150955。完整记录reports/config915/README.md。


2026-10-15 用户要求：FIFO前独立ILA也必须使用ref_clk200（200MHz）；接收域连续记录后经安全CDC回放。以后每次生成比特流后都必须导出匹配XSA，并通过Vitis下载到开发板验证。当前实现/验证记录见reports/prefifo_ila_ref200。

2026-10-15 16:26 已完成200MHz FIFO前ILA版本：BIT/XSA导出、Vitis平台quick更新与make编译、Vitis XSCT下载均通过；Vivado GUI已显示hw_ila_3(ila_rx_prefifo)波形。3次抓取2619条有效记录，39个完整64拍块，序号/计数/窗口对齐0错误。不额外延迟的FRAME对00/11各持续6个RX周期（368个完整内部run全部长度6），当前解码预期各2周期；FALLING_EDGE_DELAY=1后边界出现01/10。异常已定位到功能FIFO之前，尚不能确定实际时钟/信号完整性/配置根因；未改功能配对或9361配置。当前ARM0、RX BIST OFF、TX BIST ON，MIG9/9 PASS。详见reports/prefifo_ila_ref200/README.md/result.json/analysis.json。平台更新使用platform generate -quick，避免不必要FSBL生成时启动Eclipse工作区错误。当前DMA地址是0x81000000（以xparameters.h为准）。

## 2026-10-16 官方 RX 接收逻辑已移植并完成最终上板

当前接收模块已经改为 `ad9361_rx_axis_0`（RTL `ad9361_rx_axis.v`），
基于官方 HDL 固定提交 4b12bb58a17edb4c67f63eb367b42d3d3a4e5c91。
保留原始 IQ，PL 旁路 DC/格式/IQ 校正，加入官方 PN；LVDS 沿配对/解帧按官方原样。
原 RFMC 接收 RTL/XDC 保留，旧 CDC/ILA 约束禁用。新 AXI-Lite **0x82000000**；
原 AXIS FIFO、DMA **0x81000000**、MIG **40000000..7FFFFFFF**、RIS 地址保持。
新 `drivers/rx_9361.c/.h`，FCLK0 复位释放后必须重新初始化官方 RX 寄存器。
默认 main 仍是用户 config915，但会暂开 RX PRBS（3F4=09），PNSEL=0，
扫描/复核后恢复原 BIST/延时并回读。PNSEL=9 是 FPGA TX 标准 PRBS，不能混用。

**当前有效构建入口改用 `scripts/build_ad9361_official_rx.tcl`；旧 `build_fmcomms3.tcl`
仍指向已替换的模块，不能用于当前 BD。** 最终报告 `reports/gui_rebuild_20261016_113741/`。
WNS +0.183 ns，TNS 0，Critical CDC 0，BIT/LTX/XSA 配套，Vitis 平台/应用已更新并下载。
最终 XSA SHA256 b7a66addcc0727aff253cdf89fd819bf394004e59516c6f73831073bdabcc578。

200 MHz ILA 核名 `ila_ad9361_rx`，目前 Vivado `hw_ila_2`。
新捕获脚本 `capture_ad9361_rx.tcl`，界面脚本 `configure_ad9361_rx_view.tcl`。
RX 域 64 行冻结记录、REF200 域回放；四路独立 12 位有符号 IQ 已在 GUI 显示。
只在 RECORD_VALID=1 解析记录，同组 index0..63；IQ_VALID=1 才是官方新数据。

**板测没有通过接收完整性：PN 四路 OOS，0/1537 点；ARM=0，未验收 DMA IQ。**
MIG 9/9 PASS、0 错误、7520812 字。ILA 三次抓到原始 FRAME 含大量 01/10，
00/11 段多数长4/5周期（目标2），RX计数约172k..174k/参考毫秒，且3处计数跳变。
详细说明/日志/结构化结果/截图：`reports/ad9361_official_port/README.md`。
不要将 GPIO bit1=1 解释为完整数据已正确；现在它只是官方 adc_status。
下一步需要核对 DATA_CLK（FMC G6/G7）/FRAME（D8/D9）实测波形与接口配置。
已异步询问用户有无示波器/差分探头，尚无回复。不能只凭数字计数归因或盲目更改 VADJ/终端。
Vitis 本机完整 platform generate 会尝试启动第二个 Eclipse 并失败；本次使用 quick
更新元数据，再 make standalone BSP 并同步 include/lib 到 export，应用已实际编译下载。
