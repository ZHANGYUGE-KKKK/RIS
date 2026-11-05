# ZC706 RIS 控制器 QSPI 固化包

**2026-10-27 实板更新：抄板已烧写成功，全部镜像通过直接比较与厂商工具两次校验。实际 Flash 为 Winbond，烧写排查与最终结果见 [FLASH_REPORT.md](FLASH_REPORT.md)。以下为原始构建和原厂参考参数。**

生成日期：2026-10-27。工具：Vivado/Vitis/Bootgen 2022.2。
适用：ZC706 / XC7Z045 / 板载双 QSPI Flash，RIS 400 路网络高速控制工程。

## 应烧写的文件

**`BOOT.bin`**，大小 13,540,368 字节（12.913 MiB）。
顺序包含：`fsbl.elf` → `ris_ctrl_unit.bit` → `ris_flash_network.elf`。
不要把单独的 `.bit` 当作本工程的完整 QSPI 上电启动镜像。

原 JTAG 工程关闭了 QSPI。本包已在独立工程中启用 PS QSPI，
保持 ZC706 预设的双并行 x8 模式，完整重建硬件，再用新 XSA 生成 FSBL/BSP 和网络应用。
原工程及原已验收交付包未覆盖。构建目录：`../../build/flash_20261027/`。

## Vitis Program Flash 参数

| 项目 | 设置 |
| --- | --- |
| Image File | 本目录 `BOOT.bin` |
| Offset | `0x0` |
| Flash Type | `qspi-x8-dual_parallel` |
| FSBL File | 本目录 `fsbl.elf` |
| Verify after flash | 勾选 |

烧写时使用 JTAG 启动模式，并选择正确的 ZC706 JTAG 目标。
按板卡手册 UG954 表1-2，SW11.1～SW11.5 的 JTAG 配置为 `0 0 0 0 0`。
烧写且校验完成后，断电，切换 QSPI 配置 `0 0 0 1 0`，再重新上电。
这里的0/1为手册表格定义，操作时请对照实际板卡开关编号与丝印。

原厂参考命令（本抄板实际烧写流程见 FLASH_REPORT.md）：

```bash
cd /home/wenhan/PROJECTS/RIS/zynq/zc706/ris_ctrl_unit/export_flash/20261027
/home/wenhan/SOFTWARE/VIVADO2022.2/Vitis/2022.2/bin/program_flash \
  -f BOOT.bin -offset 0 -flash_type qspi-x8-dual_parallel \
  -fsbl fsbl.elf -verify
```

## 上电后的行为

FSBL 初始化 PS/DDR/QSPI，经 PCAP 配置 FPGA，再启动 ARM 网络控制程序。
应用初始化时400路全低并使能输出，不自动启动高速方波或播放电脑保存的图案。
网络服务为 `192.168.1.11:7060`，串口为115200 8N1。
电脑有线地址应与板卡同网段，例如192.168.1.20/24；随后可通过现有Python GUI连接。
FPC—RIS空间映射与图案库仍保存在电脑端，由GUI加载。

## 已完成的检查

- 综合、布局布线、BIT/XSA导出通过；WNS +0.158 ns、WHS +0.062 ns、WPWS +1.267 ns，失败端点0。
- 最终DRC违规0，全部23534个可布线网络已完成。
- FSBL、BSP、ARM应用均从本轮QSPI硬件重新构建；FSBL的QSPI连接模式为2（dual parallel），含InitQspi/QspiAccess。
- Bootgen成功生成并重新读取3个分区；启动头及全部分区头校验通过，Flash分区无重叠，容量低于32MiB。
- BIT与XSA内嵌BIT逐字节一致。`validation.json`和`reports/`保留检查结果。
- Bootgen产生的两个load-address重叠警告源于PL分区的默认load_addr=0。
  已核对PL属性为0x20，FSBL走PCAP分支；各Flash存储区间不重叠。
  FSBL先配置PL，再装载0x00100000处的ARM程序。没有抑制警告或改写分区加载地址。

**本次只生成并检查文件，未擦写Flash、未下载板卡，也未完成实际断电启动验收。**

## 文件说明

- `BOOT.bif`：三分区打包描述；`rebuild_boot.sh`可用当前组件重新打包。
- `fsbl.elf`：启动分区，同时供Program Flash初始化使用。
- `ris_ctrl_unit.bit` / `.xsa`：配套QSPI版本硬件。
- `ris_flash_network.elf`：400路网络控制和可编程高速方波应用。
- `ps7_init.tcl`：本轮硬件PS初始化脚本。
- `SHA256SUMS`：可用 `sha256sum -c SHA256SUMS` 检查文件完整性。

参考：
- [AMD ZC706 UG954](https://docs.amd.com/v/u/en-US/ug954-zc706-eval-board-xc7z045-ap-soc)，Flash与SW11配置。
- [AMD Zynq-7000 FSBL](https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/439124055/Zynq-7000+FSBL)，启动分区与PCAP加载。
