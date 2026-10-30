# 当前 MT 镜像实板烧写记录

日期：2026-10-29。**烧写成功，全部 13,556,752 字节经两次完整读回比较，均与本目录 BOOT.bin 一致。**

- 板卡：ZC706 抄板 / XC7Z045，IDCODE `23731093`。
- 下载线：Digilent JTAG-HS3，序列号 `210299372306`。
- Flash JEDEC ID：`ef6018`，Winbond 双片并行 QSPI，逻辑容量 32 MiB。
- Flash 类型：`qspi-x8-dual_parallel`；写入偏移：`0x0`。
- BOOT.bin SHA256：`be69f78bdbdce3f4f3406c180f225e75002d7e77bd99a546dc0179c98d4760f0`。

用户确认切换为 JTAG 启动并重上电后，脚本再次核对启动模式寄存器为 0，并按下载线序列号选择唯一目标。
使用该板此前成功的直接 QSPI 流程，仅修改运行时易失保护配置，未设置永久保护位。
逐块擦除并读取检查空白，再写入镜像，最后逐字节比较完整镜像；返回 `0x600D`，确认字节数 13,556,752。

随后使用 Vitis 2022.2 `program_flash` 的 `-no_erase -no_program -verify` 执行独立只读校验。
全部 414 个比较块合计 13,556,752 字节一致，工具返回 `Verify Operation successful`、`Flash Operation Successful`，退出码 0。

证据：`direct_program.log`、`independent_verify.log`、`hardware_programming.json`。
烧写程序和目标选择脚本保存在工程 `build/flash_mt_20261029/`；源文件复用此前实板验证成功的写入流程，重新链接当前 MT BSP。

## 尚待进行的上电验收

本次烧写与校验在 JTAG 启动模式下完成，尚未完成当前镜像的 QSPI 断电启动验收。
请断电、按该板已确认的开关配置切回 QSPI 模式，再重新上电。
上电程序预期初始化 400 路全低并使能输出，提供 `192.168.1.11:7060` 网络控制服务。

RIS GUI 已启动，MATLAB 示例脚本已在编辑器打开。电脑当前有线接口在另一网段，未进行板卡 TCP 状态/MT 播放测试。
后续需要将电脑与板卡以太网正确相连，并使用同网段地址，再在 GUI 中连接和上传 MT 表。
