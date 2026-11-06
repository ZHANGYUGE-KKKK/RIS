# 2026-11-05 64QAM Flash实板记录

已烧写并通过两次完整读回比较，全部13,556,752字节与BOOT.bin一致。

- 板卡/线缆：XC7Z045，IDCODE 23731093，下载线210299372306。
- Flash：JEDEC ef6018，qspi-x8-dual_parallel，偏移0x0。
- 镜像SHA-256：`e46e934f0f573209868e18f195cc27d5ad67fe0671c3f2272eb9807f32491665`。
- 写入时已读回JTAG启动模式0；沿用该板已验证的直接QSPI流程，仅修改易失配置，未主动设置永久保护位。
- 第一次：擦除后逐块空白检查、写入、全部数据逐字节比较，返回0x600D。
- 第二次：厂商program_flash明确-no_erase -no_program -verify，414个比较块、全部字节相同，退出成功。
- 断电启动：已通过：用户断电切回QSPI后，模式1、QAM1及64QAM FPGA能力、配套ARM固件就绪、错误0、TCP监听器初始化均核对成功。
- TCP：已通过只读TCP STATUS检查，64QAM能力、29-tick最短事件及300 MHz时钟均与新文件相符。
- 动态QAM播放及空口星座尚未实测。

证据见hardware_programming.json与reports/内对应日志。BOOT.bin的内容与原打包时相同；本次仅增加烧写/启动验收记录并更新包校验与ZIP。
