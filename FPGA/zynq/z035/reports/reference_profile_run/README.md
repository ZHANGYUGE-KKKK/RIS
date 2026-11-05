# RFMC6000 示例最终配置上板测试

2026-10-15 14:15:18 通过 Vitis Run 下载并启动。保留 FMCOMMS3 板载 40 MHz 晶体/DCXO 模式，未调用 CDCM6208。编译成功，无 warning/error。当前程序及开发板保持本配置，ARM=0，BIST 关闭。

## 配置

Fs=61.44 MSPS，BW=30.72 MHz，RX/TX FIR 均使能（2倍、64 taps），RX LO=200 MHz，TX LO=5997 MHz，MGC=5/5 dB，TX 衰减=0/0 dB，RX 延时寄存器006=04，TX 007=40。关闭自动延时扫描，普通RX先做FRAME检查；仅稳定通过才允许内部RX BIST/DMA。

软件按原 main.c/ad9361_config.c 的最终配置顺序设置，保留 FMCOMMS3 的 SPI/RESETB/DCXO 适配。radio_set.h 的 FIR 系数与原参考相同。未修改RTL、BD、XDC或重新生成硬件；当前FPGA输入IDELAY=8 taps、FALLING_EDGE_DELAY=0，与原参考的12 taps及下降沿额外延迟不同。本次是复现芯片软件配置，不是原例完整TX/RX HDL。

## 实测结论

- 芯片配置PASS：stage=4、result=0、676ms，采样率/带宽/LO/增益/FIR使能读回通过。009=07，XO_BYPASS=0；05E=81、247=02、287=02、016=00。
- 20/20次PLL检查通过。RX链：983.04/491.52/245.76/122.88/122.88/61.44 MHz；TX链：983.04/245.76/122.88/122.88/122.88/61.44 MHz。
- GPIO初始化读到03（短暂锁定）；随后20/20次FRAME稳定性检查均未通过，最终11（READY=1，FRAME_LOCKED=0，FRAME_ERROR=1）。APU随后连续10次读取均为11。
- 200MHz ILA窗口计数 rx_edges_per_ms_ref 为**十进制245766**，2048条相同，等效245.766MHz，接近预期245.76MHz；当前短窗口的Gray计数增量只有1/2、无倒退。此为RTL窗口计数，非示波器物理时钟测量，也不证明信号质量或所有CDC正确。
- FRAME故障快照history=C3C3、pair=2、flags=70，快照非连续实时RX波形。还不能单凭该快照确定具体错位来源。
- MIG ILA：ui_rst=0、aresetn=1、locked=1、init_calib_complete=1。DMA初始化因采集器锁存FRAME错误返回-8，本轮CPU DDR自测被前置条件阻止（0阶段，result=-100），不是已发现DDR存储错误。
- DMA/BIST采集未启动，无本轮IQ文件；全链路测试尚未通过。最后关闭BIST（3F4=12），ARM=0。

下一步应针对当前采样接口与参考的IDELAY和沿配对差异做对照；本轮结果不支持继续只调整采样率解决FRAME问题。

串口：uart.log；板端报告：board_memory.txt；ILA：rx_diag.csv、ddr_diag.csv；构建：build.log；结构化结果和固件SHA256：result.json。
