# ENET1 EMIO 版 BD 检查

检查日期：2026-11-13。对象为当前已保存的 `vivado_qam/ris_ctrl_unit.srcs/sources_1/bd/ris_system/ris_system.bd`，文件保存时间为本地时间 12:41:41。

本次在 `/tmp/ris_bd_emio_audit_20261113` 创建独立检查工程，执行 `validate_bd_design -force` 成功，并生成检查用 wrapper。原 BD 的检查前后 SHA-256 一致：`525b148f442c83cc64b531bf7ed924cfd2f0073565813d0ca02f80bceef41060`。原工程的 BD、RTL、wrapper、约束和构建产物未修改，未综合或烧写。

## 已完成的配置

| 项目 | 实际配置 | 判断 |
| --- | --- | --- |
| GEM1 / ENET1 | `PCW_ENET1_PERIPHERAL_ENABLE=1` | 正确启用 |
| ENET1 数据 | `PCW_ENET1_ENET1_IO=EMIO` | 正确 |
| ENET1 MDIO | 启用，选择 EMIO | 正确 |
| 数据接口导出 | `GMII_ETHERNET_1_0`，8 位 GMII | 已导出，仍需转换到 PHY 使用的接口 |
| MDIO 导出 | `MDIO_ETHERNET_1_0` | 已导出 |
| 外部中断输入 | `ENET1_EXT_INTIN_0` → `ps7/ENET1_EXT_INTIN` | 是输入端口，方向正确 |
| 旧 EthernetLite | 已删除，旧 `0x40E00000` AXI 地址段也已删除 | 符合改用 GEM1 的方向 |
| 原 GEM0 | 保留 MIO 16–27、MDIO MIO 52–53，原复位 MIO 47 | 原 GUI 网络配置保留 |
| 原 RIS | FCLK0 100 MHz、原 AXI 与复位、`0x41200000/64K` | 保留 |

GEM1 的硬核寄存器地址为 `0xE000C000`，不需要像 EthernetLite 那样新增 PL AXI 地址段或 AXI DMA。当前 PS 配置界面中 ENET1 速率为 1000 Mbps，参考频率标注 125 MHz；EMIO 下实际 GMII 时钟来自 PL，后续需由 PHY 协商结果、转换核与固件共同配置运行速率。百兆可以作为目标，当前参数不等价于已完成百兆链路配置。

## 主要缺项：GMII-to-RGMII

当前 BD 没有 GMII-to-RGMII IP。当前只是把 PS 的 GMII 接口直接导出到了 BD 边界，尚未形成连接 J18 RTL8211 的完整通路。若 J18 为 RTL8211 的 RGMII 接线，建议将转换放在 BD 内：

| 从 | 连接到 |
| --- | --- |
| `ps7/GMII_ETHERNET_1` | `gmii_to_rgmii_0/GMII` |
| `ps7/MDIO_ETHERNET_1` | `gmii_to_rgmii_0/MDIO_GEM` |
| `gmii_to_rgmii_0/RGMII` | 导出为外部 RGMII 接口，后续接 J18 PHY |
| `gmii_to_rgmii_0/MDIO_PHY` | 导出为外部 MDIO 接口，后续接 J18 PHY |

原先直接导出的 `GMII_ETHERNET_1_0` 和 `MDIO_ETHERNET_1_0` 应由上述连接替换；让转换核位于 PS 与 PHY 之间。MDIO 需要经过转换核，转换核通过自己的 MDIO 管理地址获取速率配置，该地址不能与外部 PHY 地址冲突。Vivado 2022.2 自带该 IP 的默认管理地址是 8，但实际 PHY 地址仍需核对板级资料。

对于本机 IP 的常用配置（Shared Logic in Core、内部生成 GMII 时钟），Zynq-7000 的 `clkin` 使用稳定 200 MHz，可由新增 FCLK1 或 Clocking Wizard 提供；原 RIS 的 FCLK0 100 MHz 保持。转换核的 `tx_reset`、`rx_reset` 为高有效，需按其时钟与复位要求连接，不能直接把低有效的 `peripheral_aresetn` 当作高有效复位使用。若选择外部时钟或外置共享逻辑，应按所选配置补齐对应输入。

PS 的 GMII TX/RX 时钟当前通过 GMII 外部总线接口引出；在未添加转换核前，BD 中没有内部产生这些外部输入时钟的逻辑。普通 `get_bd_nets` 标量查询不能完整表示打包接口的连接；检查用生成 HDL 已确认其接到外部 GMII 端口，并非据此断言该接口内部断线。

## ENET1_EXT_INTIN

`ENET1_EXT_INTIN` 是 GEM1 接收外部中断的输入，可用于接入 PHY 的中断事件；它不承担 GEM1 的常规收包数据通路。GEM1 自身的收发中断通过 PS 内部的中断控制器处理，无需经过 `IRQ_F2P`。

如暂不使用 PHY 中断、由固件通过 MDIO 轮询链路状态，建议删除 `ENET1_EXT_INTIN_0` 外部端口，将 `ps7/ENET1_EXT_INTIN` 接常量 0。本机 PS7 IP 元数据为该未使用输入设置的默认值也是 0。如需接 PHY 的 INTB，应先确认板上确实引出该信号，再处理有效极性、电平与固件中断支持，不能直接假定低有效 PHY INTB 可原样连接。

## 旧中断残留

`xlconcat_0/In0` 已没有驱动源，但 `xlconcat_0/dout` 仍连接 PS `IRQ_F2P`。检查用生成 HDL 将 In0 自动接为 `1'b0`，因此当前没有通过这条线产生中断。可以删除这个 concat 及未使用的 `IRQ_F2P` 配置；若需要为后续 PL 外设保留，应明确接常量 0。它不需要与 ENET1_EXT_INTIN 连接，也不承担 GEM1 收发中断。

## PHY 复位、顶层与约束

- PS 仍选择 `Share reset pin`，实际启用的是 GEM0 的 MIO47；ENET1 没有单独配置复位输出。是否能复位 J18 PHY，取决于板上两个 PHY 是否实际共用这根线。若未共用，应通过合适的 GPIO/EMIO 输出或复位逻辑连接 J18 PHY RESETB，并按完整 PHY 型号实现上电与复位时序。
- 当前工程中的旧 wrapper 和手写顶层 `rtl/ris_ctrl_unit_top.v` 仍没有新增网口端口；完成 BD 后需重新生成 wrapper、同步顶层连接。
- 当前工程的 XDC 仍只有原 RIS 引脚与时序约束。J18 的 RGMII、MDIO、PHY 复位、可选 INTB 引脚、电压和 RGMII 时序/延时配置待补齐；仍需实际板卡的对应原理图或厂家约束表。
- 双网口固件、接收结果回传、发送数据比对及 GUI 展示尚未因这次 BD 配置自动实现。现有创建工程脚本也尚未同步该手工配置。

## 检查范围与依据

Vivado BD 校验通过仅说明当前接口连接在结构上可接受；外部 GMII/MDIO 和中断输入被视为由工程外部提供。此次未执行综合、实现、板级时序收敛或实板通信验证。Vivado 日志中的 Tcl Store 无写权限提示来自独立检查环境。

- [AMD PG160：GMII-to-RGMII 的 I/O 和 200 MHz 参考时钟](https://docs.amd.com/r/en-US/pg160-gmii-to-rgmii/Input/Output-Signals)
- [AMD PG082：PS7 端口定义](https://docs.amd.com/api/khub/documents/5SmKudM_4jpvP8OtqGslWA/content)
- 本机 Vivado 2022.2 的 `gmii_to_rgmii_v4_1/component.xml` 与 `processing_system7_v5_5/component.xml`；当前 BD/XCI 和检查用生成 HDL。
