# 2026-11-10 QPR1 Flash烧写记录

QPR1镜像已写入开发板双并行QSPI Flash，写入偏移0，镜像大小13,556,752字节。下载线210299372306，XC7Z045，烧写前只读确认BOOT_MODE=0。

已开始的直接烧写程序完成擦除、写入及其内置完整比较，返回0x600D，打印RIS_QPR1_FLASH_DIRECT_PASS。用户随后要求烧写成功后不额外读回，因此未执行独立program_flash读回，不声称两次读回验收。

镜像：export_flash/20261109_qpr1/BOOT.bin；SHA-256：de9e51fa88438930c1bd5ae929c8ceac9eba67ad9544e3a5a848ef256e8557bd。

下一步由用户断电切回QSPI启动模式后上电。未执行断电启动、TCP STATUS、动态QAM或射频验收。原烧写包及BOOT.bin保持不变；实板事件以本目录hardware_programming.json和日志为准。
