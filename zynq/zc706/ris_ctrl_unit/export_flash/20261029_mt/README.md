# RIS MT 控制版 QSPI 完整启动镜像

生成日期：2026-10-29。适用 ZC706 / XC7Z045、双片并行 x8 QSPI。

**2026-10-29 实板结果：已烧写，全部 13,556,752 字节通过两次完整读回校验。记录见 `FLASH_REPORT.md` 和 `hardware_programming.json`；当前镜像的断电启动尚待验收。**

烧写文件为本目录 **BOOT.bin**，13,556,752 字节（约 12.93 MiB），包含依次执行的三个分区：

1. `fsbl.elf`：由当前 MT XSA 对应平台生成的启动程序，初始化 PS/DDR/QSPI。
2. `ris_ctrl_unit.bit`：当前 MT 硬件配置，配置 PL。
3. `ris_all_io.elf`：支持 MT 表上传和播放的 ARM 网络固件。

本包来自 `export_mt/` 已验证文件，不使用 2026-10-27 的旧应用或旧 BIT。
已离线检查启动头/分区头校验、分区地址与范围、所有分区的实际数据，以及 BIT/XSA 和 FSBL 初始化代码一致性；详见 `validation.json`、`source_provenance.json` 和 `reports/`。
`SHA256SUMS`、`manifest.json` 可核对全部文件。

## 烧写参数

| 项目 | 值 |
| --- | --- |
| Image File | 本目录 `BOOT.bin` |
| Offset | `0x0` |
| Flash Type | `qspi-x8-dual_parallel` |
| FSBL File | 本目录 `fsbl.elf` |
| 烧写后校验 | 开启，核对完整镜像 |

此前该抄板的标准工具擦除流程曾失败，既有处理及实板记录见相邻 `../20261027/FLASH_REPORT.md`。
烧写时应复用该板已确认的流程，不能仅依据工具的 Erase OK 判断成功；需要完整读回比较。
启动模式开关沿用该板已确认的 JTAG 烧写/QSPI 启动配置。

当前镜像已在下载线 `210299372306` 对应板卡烧写成功；切回 QSPI 启动模式并重新上电后再进行上电验收。

## 上电与 MT 使用

上电后启动 `192.168.1.11:7060` 网络服务，初始化 400 路全低并使能输出；不会自动播放 MT 表。
使用当前工程的上位机加载 MT 文本表、设置频率并启动。MT 表存于运行时 RAM，断电后需重新上传。
M+T>100% 时超出部分回绕到**该周期的开头**，不影响下一周期，例如 `(50,80)` 为高30%、低50%、高20%。
该规则由当前上位机编译，不能搭配此前使用跨周期延续规则的旧上位机。
`MT_CONTROL.md` 是本次打包时的控制说明快照，内附 `matlab/` 生成脚本和示例。

## 重建与验证

在本目录运行 `bash rebuild_boot.sh`，用随包的 FSBL、BIT、ELF 重建并验证镜像；可用环境变量 `RIS_BOOTGEN` 指定已有 Bootgen 路径。
在工程根目录运行 `python3 -B scripts/build_mt_boot.py` 可从已验收 MT 包重新打包并生成 ZIP；如修改过硬件或固件，先执行 `bash scripts/build_mt.sh`。

Bootgen 的两个 memory range overlap 警告来自 PL 分区默认 load_address=0；该分区属性是 PL，FSBL 经 PCAP 配置，不作为 ARM 内存映像加载。
本包已独立检查 Flash 存储范围不重叠、ELF 加载地址正确，没有修改分区地址或压制警告。

完整包：`../RIS_ZC706_MT_QSPI_20261029.zip`。
