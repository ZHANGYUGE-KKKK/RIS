# GEM1 / PL Ethernet BD 完成记录

日期：2026-11-13。当前 `vivado_qam/ris_ctrl_unit.srcs/sources_1/bd/ris_system/ris_system.bd` 已在原 Vivado GUI 进程内完成并保存；已执行 `validate_bd_design -force`，通过校验。生成的 wrapper 同步更新，原 Vivado 进程保持运行。

## 已完成的连接

| 功能 | 连接或设置 |
| --- | --- |
| GEM1 数据 | `ps7/GMII_ETHERNET_1` → `gmii_to_rgmii_0/GMII` |
| GEM1 管理 | `ps7/MDIO_ETHERNET_1` → `gmii_to_rgmii_0/MDIO_GEM` |
| PHY 数据 | 转换核 `RGMII` → 外部接口 `pl_eth_rgmii` |
| PHY 管理 | 转换核 `MDIO_PHY` → 外部接口 `pl_eth_mdio` |
| 转换核配置 | 核内共享逻辑、内部生成 GMII 时钟、核内 IDELAYCTRL |
| 网口参考时钟 | PS FCLK1 = 200 MHz → 转换核 `clkin` 和 `reset_eth/slowest_sync_clk` |
| 复位输入 | PS `FCLK_RESET1_N` → `reset_eth/ext_reset_in`，自动传播为低有效 |
| 数据通路复位 | `reset_eth/peripheral_reset` → 转换核 `tx_reset`、`rx_reset`，高有效 |
| PHY RESETB 控制 | PS EMIO GPIO[0]，GPIO 编号 54 → `pl_eth_reset_n[0:0]` |
| GPIO 反馈 | `GPIO_O` 反馈到 `GPIO_I`，只反映内部输出值，不代表外部电平实测 |
| 可选 PHY 事件中断 | `ps7/ENET1_EXT_INTIN` 接常量 0；不再导出外部中断输入 |
| 旧 PL 中断 | 已删除无驱动的 `xlconcat_0`，关闭 Fabric Interrupt |

转换核管理地址设为 8。这是转换核在 MDIO 总线上的地址，必须与板上实际 PHY 地址不同。TXC 偏斜配置为 `Skew Added by PHY`，正式固件需按实际 RTL8211 型号及板级接线设置 PHY 延时、协商速率和转换核速率；这些板级配置不由 BD 结构校验确认。

`pl_eth_reset_n` 是独立的输出信号，直接来自 PS GPIO 输出寄存器。输出数据复位为 0；后续固件应初始化 GPIO54，并按 PHY 手册完成保持低电平、释放复位及等待稳定的过程。原 MIO47 对 GEM0 的控制保留。

## 检查结果

- 在独立临时工程中运行完成脚本两次，检查可重复执行且外部接口名称不变化；强制 BD 校验通过。
- 在原 GUI 进程内运行脚本并再次校验、保存，更新 wrapper，导出 `completed_bd.tcl`。
- IP 状态报告中 8 个 IP 均为 Up-to-date。
- 对比确认：原 RIS 控制器参数、地址映射、原有信号连接、FCLK0 100 MHz、GEM0、DDR、QSPI 和 UART1 配置保留。
- 原手写顶层、原 XDC、PS preset 和原创建工程脚本的 SHA-256 保持；详情见 `verification.json`。
- GPIO 的 O/I 成员被有意拆开连接，Vivado 产生两条 BD 41-1306 接口覆盖提示；生成 HDL 已确认 GPIO 输出、反馈及外部复位端口的实际连接。无 BD 校验错误。

当前 BD 的 SHA-256：`97973fc93c1f8015cd8716859f3f606a8f18e30dbc3cf515635ab8ab1b892a9f`。

## 备份与恢复说明

`before/` 保存修改前的磁盘 BD、XCI、XPR、wrapper、手写顶层、原约束及 GUI 操作日志。GUI 自动化过程中曾误关闭 BD 视图；未保存的 GMII/MDIO 接线与中断关闭操作已依据原 GUI journal 恢复，在继续配置前保存为 `before_user_memory.bd` 和 `before_user_bd.tcl`。当前完成版包含这些连接。

关闭 Vivado 进程的尝试被自动审批拒绝，未执行终止；后续通过同一个 GUI 进程的 Tcl 控制台完成全部写入，未绕过该拒绝。

## 后续集成边界

本次完成 BD 内部连接并更新生成 wrapper，没有执行综合、实现、BIT/XSA/Flash 生成或烧写。

后续仍需：

1. 将新增 wrapper 端口接入手写 `rtl/ris_ctrl_unit_top.v`。
2. 依据实际 J18 原理图或抄板厂家约束表补齐 PL 管脚、电压与 RGMII 时序。官方 ZC706 的 PS MIO 网口管脚不能直接绑定为 PL RGMII 管脚。
3. 导出配套硬件平台，更新双网口固件及 GPIO54 / PHY / 转换核初始化，再接入结果回传、比对和 GUI 展示。
4. 若要从头重建工程，在原 `create_project.tcl` 中纳入本次配置；目前完成脚本供已打开的 `ris_system` 使用，不会自动修改原创建脚本。

完成脚本：`../../scripts/configure_pl_eth_bd.tcl`。记录包括 `validation_summary.txt`、`ip_status.txt`、`gui_apply.log`、`scratch_validation.log`、`verification.json` 和 `completed_bd.tcl`。
