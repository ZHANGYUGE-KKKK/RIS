# ZC706 抄板 QSPI 烧写记录

日期：2026-10-27。结果：**烧写成功，全部 13,540,368 字节通过两次完整校验**。

- FPGA：XC7Z045，JTAG IDCODE 0x23731093。
- 下载线：Digilent JTAG-HS3，序列号 210299372306。
- Flash：工具识别为 Winbond W25Q128FW，双片并行 x8，逻辑容量 32 MiB。
- 镜像：本目录 BOOT.bin；偏移 0；大小 13,540,368 字节。
- SHA256：a3b82b274cc37041d7525e57f36b0a4edce7307fbfafd415a966da1c6234ac7f。

## 实际烧写与验证

原厂参考流程在本板擦除失败。单次实验观察到，临时解除保护后 SR2=0x3E，厂商烧写工具重新初始化后 SR2=0x7F，擦除后空白检查失败。不能直接把原厂工具报告的 Erase OK 当作擦除成功。

用户明确授权解除保护后，采用临时解除保护与直接 QSPI 擦写流程，没有主动设置永久锁定位。逐块擦除并检查空白，然后写入镜像，并逐字节读回全部数据。最终结果码为 0x600D，已核对字节数 13,540,368。

随后独立运行 Vitis 2022.2 program_flash，指定 -no_erase -no_program -verify，只进行读回比较。414 个比较块共 13,540,368 字节全部相同；工具返回 Verify Operation successful、Flash Operation Successful，退出码 0。

成功日志：
- direct_flash_corrected.log：实际擦写及第一次完整校验。
- flash_independent_verify.log：厂商工具独立完整读回校验。

较早的 flash_program.log、flash_program_retry.log、direct_flash.log 等文件属于排查失败记录，不代表最终结果。
直接烧写程序保存在工程 build/flash_20261027/diagnostic/direct_flash.c 和 direct_flash.tcl；写入接口已修正为不传入接收缓冲区，防止驱动将后续发送数据替换为读操作占位数据。

## 下一步：断电启动

烧写与读回均在 JTAG 启动模式进行。尚未验证断电后 QSPI 自启动，也未验证以太网应用。
断电后，将启动开关切换为 QSPI 模式再上电。原厂 SW11.1～5 的逻辑设置为 0 0 0 1 0；抄板请按实际丝印核对方向，不能直接把逻辑值理解为 ON/OFF。
固件网络服务为 192.168.1.11:7060。应用启动后初始化 400 路全低并使能输出。
