# FRAME_ERROR 定位状态

2026-10-14 15:31，ref_clk200版本已实现并完成综合、布局布线、时序、bitstream和含bit的XSA导出。ILA时钟在实现网表中为clk_pll_i、周期5.000ns；14探针/193bits。新增RX域首个错误快照、XPM握手CDC及Gray计数CDC；四组功能仿真与时钟频率/停钟诊断仿真均通过。新bit尚未下载到板卡，因此以下旧板上现象仍需用新诊断核重新观测。探针使用方法见README.md，构建核验见verification.json。

2026-10-14 14:51:43，Vitis IDE.log确认下载当前新bitstream和key_ctrlll.elf，并执行ps7_init/ps7_post_config/con。串口AD_CONFIG PASS及RF_CLOCK_TEST 20/20 PASS；ARM=0，采集状态0x11。

实现网表中ILA2、FRAME IDDR、RX BUFG都属于rfmc_rx时钟，驱动为i_rx_clk_global/O，未接到FRAME或门控时钟。

在ARM=0时，仅通过SLCR FPGA_RST_CTRL[0]复位采集/FIFO/DMA/GPIO，保持PS及射频配置。复位前0x11，释放10ms及110ms后均重新0x11。结合BD复位连接和RTL，说明释放后RX域曾运行并重新出现FRAME_ERROR。这不证明时钟连续、频率正确或信号质量合格，也不能只凭ILA clock stopped推断DATA_CLK始终不存在。

FRAME_ERROR为获得锁定后发生的锁存错误，停止新的IQ入FIFO；本次尚未证明DMA/MIG/IQ有效。50%占空比FRAME的pulse模式在0x010[3]=1时开启，当前0x010=C8、配置rx_frame_pulse_mode_enable=1正确，并非名称矛盾。

建议最小诊断：内部ref_clk200域测RX时钟活动/频率；在RX域锁存首次错误的phase、frame_pair及前几周期FRAME，用完整快照CDC读出。ILA并非唯一手段。若200MHz ILA观察原始RX域总线，必须解决CDC且不能假设每个245.76MHz接收周期都被记录。
