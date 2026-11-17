# 发端 RIS 工程：GEM1 EMIO / SGMII 与上行回传开发记录

日期：2026-11-13。工程：`/home/wenhan/PROJECTS/RIS/FPGA/ris_qam_backend`。本次开发并实测发端。固件经 JTAG 临时运行，收端由 Linux 网卡模拟。双板和射频联调待收端就绪。

## 原理图结论与物理绑定

依据厂家文件 `1_四川真为电子_ZC706_SCH.pdf`，PDF 第46页（图纸49/58）的 J18 / U48 RTL8211FS 采用 MODE[2:0]=011，即 UTP ↔ SGMII。TXD/TXCTL/TXCLK 未接 FPGA，RXD/RXCTL/RXCLK 只接本页配置电阻。因此以 PCS/PMA SGMII 替换之前的 GMII-to-RGMII。

| 新顶层端口 | FPGA 管脚 | 说明 |
| --- | --- | --- |
| pl_eth_sgmii_txp / txn | Y2 / Y1 | Bank111 GTX channel 1 → PHY HSIP/HSIN |
| pl_eth_sgmii_rxp / rxn | AB6 / AB5 | PHY HSOP/HSON → GTX |
| pl_eth_refclk_clk_p / n | W8 / W7 | Si5324 CKOUT2，经 C165/C166 |
| pl_eth_mdio_mdc | L13 | Bank35 LVCMOS15，经 U70 转3.3V |
| pl_eth_mdio_mdio_io | K13 | Bank35 LVCMOS15，经 U70 转3.3V |
| pl_eth_reset_n | H14 | GPIO54，Bank35 LVCMOS15 |
| pl_eth_si5324_reset_n | W23 | GPIO55，Bank11 VADJ，沿用工程2.5V |

源图还核对了 PDF 第4、7、8、9、36、43、45页。实板读取 PHY2 ID `001C:C916`。时钟实装为 Si5326 Rev C，驱动识别 Si5324 和 Si5326。详细映射见 `schematic_mapping.json`。

## 工程与驱动变更

- 原 Vivado GUI 会话内完成 BD 修改、强制校验、生成输出和 wrapper；顶层接入新增端口，加载 `constraints/ris_pl_eth.xdc`。创建工程脚本同步纳入该配置，可独立从源码重建。
- GEM1 EMIO GMII 接入 `gig_ethernet_pcs_pma:16.2` 的 GEM 适配接口，SGMII MAC 模式、GTXE2、内置共享逻辑。PCS MDIO 地址8，板上PHY地址2。显式连接 MDIO 三态控制，外部 MDIO 由生成 wrapper 的 IOBUF 实现。
- 保持 RIS FCLK0 100MHz、AXI `0x41200000/64K`、控制器参数及原 RIS 数据/时钟/复位通路；FCLK1 200MHz供 PCS 独立时钟。
- PS I2C0 MIO50/51 经 PCA9548A(0x74)通道4访问 Si5324(0x68)。MIO46控制MUX复位；GPIO55释放时钟芯片，配置 CKOUT2=125MHz并验证读回/锁定后才释放 GPIO54 PHY复位。板级初始化有20秒总截止时间。
- 官方125MHz表的CKOUT2原为关闭，本板驱动将reg10改为0x00开启两路输出。分频配置对应114.285MHz晶体、5.25GHz VCO、125MHz输出。
- 新生成 BSP 的补丁仅作用于工程内 `vitis_uplink`，不修改 Vitis 安装文件。修正双GEM的全局配置/网口/链路速度状态，GEM1使用有限MDIO事务、PHY2/PCS8身份检查和异步100/1000全双工协商；无网线不会等待协商结束。初始化及DMA失败向上返回错误。
- 双GEM各预占64个RX pbuf，独立BSP设置 PBUF_POOL_SIZE=256、MEM_SIZE=262144。原 GEM0 Marvell 初始化路径和TCP7060命令服务保留。

## 发端回传接口

| 用途 | 发端接口 | 地址 |
| --- | --- | --- |
| 原 RIS 控制 | GEM0 / PS Ethernet | 192.168.1.11:7060 TCP |
| 接收收端回传 | GEM1 / PL Ethernet | 192.168.2.11:7061 UDP |
| 向上位机报告 | GEM0 / PS Ethernet | 192.168.1.11:7070 TCP JSONL |

回传默认对端为 `192.168.2.12:7061`，RUP1协议校验来源、实际网口、版本、长度和CRC32，最多1024字节payload/包；8包有界队列，背压与丢弃计数可见。数据不会进入RIS命令解析器。完整协议及监视命令见工程根目录 `UPLINK.md`。SSH开发主机地址192.168.43.11与上述开发板地址不同。

## 已完成验证

- 临时BD配置连续执行两次、强制校验、全量IP生成及RTL展开通过；PCS许可Included，全部13个IP Up-to-date。
- 原GUI与独立重建的组件、地址映射和功能参数一致；HWH仅存在关闭的debug/Fabric IRQ字段默认值表示差异，详见hardware中的比较JSON。
- 综合、布局、布线、物理优化、BIT与XSA导出通过。WNS +0.064ns，WHS 0.000ns，TNS/THS均0；hold余量接近报告精度，应保留完整报告供后续版本比较。
- DRC无Error/Critical Warning，31,256条网络完成布线、routing errors为0；check_timing无未约束内部端点和缺失IO delay。
- 实际GT站点GTXE2_CHANNEL_X0Y9；参考时钟缓冲器IBUFDS_GTE2_X0Y5，验证了专用时钟路径与全部新增管脚。
- 回传C解析/网络适配mock、8项Python测试通过；板级I2C/时钟/复位17个场景通过，包括慢I2C的总截止时间。日志和源SHA见 `software/`。
- PHY/PCS故障mock与补丁幂等测试通过，覆盖无网线、MDIO卡死、身份/配置错误、100/1000切换、掉线重连及双GEM状态隔离，日志见 `software/uplink_bsp_fault_tests.log`。
- 新双GEM/I2C0 BSP完整交叉编译和最终ARM ELF链接通过；已从ELF符号核验包含新驱动、从配置核验缓冲池，并逐字节比对应用编译副本与当前源码、导出库与已修补BSP库。
- 最终XSA的HWH与BSP硬件描述匹配；外部BIT与XSA内嵌BIT完全匹配。配套清单见 `../../export_uplink/hardware_manifest.json`、`../../export_uplink/firmware_manifest.json`。

## 构建与产物

从工程根目录执行：

```bash
bash scripts/build_uplink.sh
bash scripts/build_uplink_firmware.sh
python3 -B tests/run_uplink_tests.py
python3 -B tests/run_pl_eth_board_tests.py
python3 -B tests/run_uplink_bsp_tests.py
```

独立产物为 `export_uplink/ris_ctrl_unit.bit`、`ris_ctrl_unit.xsa`、`ris_uplink_network.elf`、`ps7_init.tcl`。未替换 `export_qam/` 或任何现有Flash启动包；原开发阶段的 JTAG 验证之后，已另行生成并写入新 BOOT.bin。

本次修改前的主工程文件备份位于 `before/`，GUI内存BD导出为 `before_gui_bd.tcl`。原GUI保持运行；临时切换的输入法已恢复为libpinyin。独立构建产生的根目录临时时序文件已归档，原先clean版本已恢复。其他已有用户改动保留。

## 发端实板验证

- JTAG 模式下临时加载配套 BIT 和 ELF。原版本返回 `init_error=-5`，在时钟 ID 检查处通过硬件断点读得寄存器 134/135 为 `01 A2`，对应 Si5326 Rev C。按芯片手册新增 `0x01a` 型号识别，保留 Si5324 的 `0x018` 和未知型号拒绝。修复后串口报告 CKOUT2 125 MHz 配置完成并锁定。 [Si5326 数据手册](https://www.skyworksinc.com/-/media/Skyworks/SL/documents/public/data-sheets/Si5326.pdf)
- 实测 PHY2 `001C:C916`、PCS8 `0174:0C00`，GEM1 为 1000 Mbps 全双工。串口的 EMAC type 提示来自 Vitis 2022.2 `xadapter.c` 中 switch 分支落入 default，两个 GEM 的实际数据通路均已验证。
- Linux USB 网卡 `192.168.2.12` 模拟收端，从 J18 发送 18 字节文本和 1024 字节二进制，PS 口 `192.168.1.11:7070` 收到完全一致的内容。四包测试中合法包转发 2，CRC 拒绝 1，源端口拒绝 1，队列丢包 0。
- 实际 `monitor_uplink.py` 显示了另一条测试消息。监视客户端连接期间，`7060` 的只读 STATUS 正常，错误计数 0。
- 证据见 `board_test/result.json` 以及同目录串口、XSCT、网络和回归日志。临时加载通过的 ELF 已归档到 `export_uplink/` 并更新 SHA-256 清单。本次范围是发端有线验证，实际收端板与射频链路待联调。

## QSPI 烧写与冷启动

- `export_flash/20261113_uplink/BOOT.bin` 为当前发端启动镜像，包含配套 FSBL、已上板验证的 BIT 和支持 Si5326 的 ELF。Bootgen 生成后逐分区核对了启动头、校验和与输入内容。
- 在 JTAG 模式写入双并行 QSPI 的偏移 `0x0`，13,573,136 字节逐字节回读一致，写入程序返回 `0x600D`。
- 断电切回 QSPI 后，`BOOT_MODE=1`，FPGA 的 QAM、QAM64、QPR1 标识及应用状态均正常。PL 网口协商到 1 Gbps 全双工。
- `7060` 的控制状态无错误。电脑模拟收端发送 4 个数据包，合法文本和二进制各转发 1 包，CRC 错误和源端口错误各拒绝 1 包，队列丢包为 0。
- 烧写和冷启动证据保存在 `reports/flash_uplink_20261113/`，原 QPR1 回退镜像位于 `export_flash/20261109_qpr1/BOOT.bin`。

接口技术依据：[AMD PG047 GEM/SGMII适配](https://docs.amd.com/r/16.2-English/pg047-gig-eth-pcs-pma/Additional-Client-Side-SGMII-Logic)、[MDIO管理](https://docs.amd.com/r/16.2-English/pg047-gig-eth-pcs-pma/Management-Options)、厂家原理图及本机Vivado/Vitis 2022.2 IP/驱动源码。
