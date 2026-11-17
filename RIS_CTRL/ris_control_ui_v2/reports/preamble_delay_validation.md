# 带延时MT前导码验证（2026-11-10）

统一400路MT、64QAM和256QAM前导码支持非零T。每行M、T均为0–100%，M+T≤100%；先低T%，再高M%，剩余部分低。每行占一个完整PWM周期，与相偏补偿、正式数据及下一帧共用周期边界。前导码仍最多10行。

上位机新增共享的行校验和脉冲量化；M+T=100%时限制高电平在本周期内，避免独立舍入产生一时钟/时间片伪回绕。QAM前导码编译为低/高/低事件（恒定电平合并为单事件），保持B/S/P索引及原协议。统一MT仍通过原有MT时段编译器播放。正式MT表原有M+T>100%的回绕功能保留。

预览显示输入及量化M、T。JSON预设和离线ZIP保留延时；ZIP编译器核对delay_slots及delay_zero，并兼容缺少delay_slots的旧零延时包。未修改RTL、板端C固件、时钟或Flash镜像，也未连接真实板卡。

本轮56项Python测试通过：MT编译11项、旧合帧6项、独立前缀/C解析6项、统一预设9项、新增延时4项、64QAM6项、相偏补偿6项、MT前导码GUI4项、完整滚动预览3项、真实Tk/TCP/Python客户端/C解析链路1项。覆盖0/100%电平、非零T、M+T=100%舍入、超界拒绝、完整4096字节、10行前导码与4参考点、预设/ZIP复现、旧ZIP兼容、预览滚动及总下发约束。

日志：[延时与QAM回归](preamble_delay_core.log)、[GUI及TCP链路](preamble_delay_gui.log)。MT/旧合帧/独立前缀/预设共32项在本轮终端测试运行通过。

两组既有RTL、厂商ODDR和50片595模型的仿真均通过逐事件400-bit源波形oracle：

- 256QAM、64 slice、120 kHz、3行带延时前导码、4参考点、全部256符号、K=1：263周期、8836次锁存，单次及循环边界通过。[日志](../../../FPGA/ris_qam_backend/reports/preamble_delay/rtl_delayed_user256.log)
- 64QAM、64 slice、160 kHz、10行前导码（含延时、恒定电平和舍入边界）、4参考点、全部64符号、K=3：214周期、7009次锁存，单次及循环边界通过。[日志](../../../FPGA/ris_qam_backend/reports/preamble_delay/rtl_delayed_full64.log)

示例：[preamble_mt_with_delay.txt](../examples/preamble_mt_with_delay.txt)。界面：[统一MT波形](../preview/32_mt_delayed_preamble.png)、[256QAM](../preview/33_qam256_delayed_preamble.png)、[64QAM](../preview/34_qam64_delayed_preamble.png)。
