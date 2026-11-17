# J18 结果回传链路：BD 检查记录

检查日期：2026-11-13。检查对象为当前 GUI 中已保存的 `vivado_qam/ris_ctrl_unit.srcs/sources_1/bd/ris_system/ris_system.bd`。

用户目标：收端通过 J18 向发端回传接收结果，发端核对后供 RIS GUI 展示。用户确认 J18 附近 PHY 为 RTL8211 系列，百兆速率即可；完整芯片后缀、J18 实际接线及管脚表尚未提供。

## 检查结论

当前 BD 的 AXI、时钟、中断和地址连接基本完整；在临时工程中执行 `validate_bd_design -force` 成功，生成了检查用的新 wrapper，IP 状态均为 Up-to-date。该结果只验证 BD 内部结构，不代表 J18 接口、电气时序、软件网络及实板通信已经可用。此次没有综合、生成新的配套 BIT/XSA/Flash 或烧写。

原 BD 的检查前后 SHA-256 一致：

`d3d58db567af4f05b6abcb97825f6b33a44a46dd76c7423a55347990c08b7f6d`

原工程的 BD、XCI、wrapper、RTL 和约束均未因本次检查修改。检查工程位于 `/tmp/ris_bd_eth_audit_20261113`；持久化的日志和摘要位于本目录。日志中的 Tcl Store 无写权限提示来自检查环境，不是 BD 连接错误。

## 已有连接

| 项目 | 当前配置 | 判断 |
| --- | --- | --- |
| 新增网口 IP | `xilinx.com:ip:axi_ethernetlite:3.0` | 百兆 MII MAC，非千兆 AXI Ethernet |
| CPU 访问 | PS `M_AXI_GP0` → `control_bus/M01_AXI` → EthernetLite `S_AXI` | 已连接 |
| AXI 时钟 | PS `FCLK_CLK0`，100 MHz | 与总线同域 |
| 中断 | `ip2intc_irpt` → `xlconcat_0/In0` → PS `IRQ_F2P` | 已连接 |
| EthernetLite 地址 | `0x40E00000`，64 KiB | 与 RIS 控制器不重叠 |
| RIS 控制器地址 | `0x41200000`，64 KiB | 保留 |
| 外部接口 | `MII_0`、`MDIO_0` | 已导出到 BD 边界 |
| AXI 复位 | `reset_pl/interconnect_aresetn` | 同域、低有效；后续整理时建议外设使用 `peripheral_aresetn` |
| PS 复位极性 | `C_EXT_RESET_HIGH=0` | 与 `FCLK_RESET0_N` 匹配 |

EthernetLite 当前启用 MDIO、全双工、收发 ping-pong 缓冲，不要求另加 AXI DMA。

## 尚未完成的部分

1. **MAC—PHY 接口待匹配。** EthernetLite 输出 MII。RTL8211 必须按完整型号、模式配置和板上实际走线核对。例如 RTL8211F 在 10/100/1000 Mbps 下均使用 RGMII，选择 100 Mbps 不会将该接口变成 MII。不能将现有 MII 信号直接重命名后连接 RGMII PHY。
2. **工程顶层没有网口连接。** 当前 `rtl/ris_ctrl_unit_top.v` 只连接 DDR、FIXED_IO 和 RIS 输出；当前工程中的旧 `ris_system_wrapper.v` 也没有新增的 MII/MDIO 端口。临时工程生成的新 wrapper 已包含 MII、MDC 和带 IOBUF 的双向 MDIO。正式实现需同时更新 wrapper 和手写顶层。
3. **缺少板级约束。** 当前工程只引用 `ris_lpc.xdc` 和 `ris_fast.xdc`，没有 J18 的网口数据、时钟、MDIO、复位引脚及相应电平、时序约束。不能套用官方 ZC706 的引脚：官方板 J18 是 FMC VADJ 跳线，与用户提供的丝印信息不一致。
4. **固件目前只初始化原 PS 网口。** `software/network/ris_network.c` 的 `xemac_add()` 仍使用 `XPAR_XEMACPS_0_BASEADDR`，并调用 PS GEM 专用的接收恢复函数。新增 BD IP 不会自动启用第二个网络接口；需要更新 XSA/BSP、双接口初始化和轮询、结果回传服务及 GUI 查询接口。
5. **结果校验和展示尚未实现。** 当前 RIS 网络服务用于控制请求。已查看的收端程序主要提供原始 IQ 采集下载；不能据此认为已有完整 QAM 解调结果回传功能。需要接入实际解调输出，再定义结果格式。
6. **工程重建脚本尚未同步。** `scripts/create_project.tcl` 仍只建立原 RIS 总线和控制器；若直接重建，将不会包含此次手工增加的网口。选定最终方案后应同步脚本。

## 推荐实现方向（尚未修改）

对于百兆、由 ARM 固件处理解调结果的回传用途，建议使用空闲的 PS GEM1，经 EMIO 及 PL 内的 GMII-to-RGMII IP 接 J18 的 RTL8211，保留 GEM0 作为电脑 GUI 的连接。物理网口仍使用 PL 引脚。

```text
接收端解调结果
    → 收端固件封包
    → 收端 J18（RTL8211）
    → 网线
    → 发端 J18（RTL8211）
    → RGMII / GMII-to-RGMII / PS GEM1
    → 发端固件核对
    → 原 GEM0 连接
    → RIS GUI 展示
```

此方案使用 PS 自带的 MAC 和 DMA，由 PL 完成接口转换。需要配置转换 IP 的参考时钟、复位、MDIO 地址、速率同步，以及 PHY 的延时和自协商策略；网络时钟按 IP 要求设置，RIS 既有控制时序不因此改变。当前 PS 仅启用 GEM0，GEM1 尚未接入。

如后续明确要求 MAC 本身位于 PL，可改用具有 RGMII 接口的 AXI Ethernet 子系统，并配套与固件匹配的收发数据通路。当前 EthernetLite 不宜作为未核实的 RGMII 直连方案。

## 建议的结果核对方式

每次发送为正式信息保存一份参考副本，并分配任务编号。收端在完成前导码同步、相偏处理和 QAM 判决后，回传任务编号、结果序号、调制类型、有效符号数、解调符号及封包校验值；封包长度应有明确上限，较长结果分块返回。

发端分别检查：

- 回传包编号、长度、偏移和校验值，识别截断、重复、乱序或过期结果。
- 解调符号与对应任务的原始正式信息逐符号比较，统计错误位置、误符号率；明确比特打包规则后再统计 BER。

前导码、相偏补偿点和每符号 K 次 PWM 重复不计入正式信息长度。回传封包校验通过只说明返回的数据包完整，解调正确性由与参考数据的比较决定。GUI 应展示待接收、校验通过、不一致、超时等状态及相应数据；以任务编号防止旧结果被认作本次结果。任务编号如何在接收端关联空口帧，需在联调协议中明确。

正式修改所需的硬件资料：**J18 / RTL8211 这一页原理图或厂家引脚表**，包含完整 PHY 型号、PL 引脚、I/O 电压、PHY 复位、时钟、MDIO 地址和 RGMII 延时配置。

## 依据

- [AMD PG135：EthernetLite 的 10/100 Mbps MII 接口](https://docs.amd.com/r/en-US/pg135-axi-ethernetlite/Introduction)
- [Realtek RTL8211F 官方产品说明：10/100/1000 Mbps 均使用 RGMII](https://www.realtek.com/Product/Index?cate_id=786&id=3975)
- [AMD PG160：PS GEM 经 EMIO 和 PL 的 GMII-to-RGMII 接口转换](https://docs.amd.com/r/en-US/pg160-gmii-to-rgmii/Applications)
- [AMD UG954：官方 ZC706 的接口与 J18 定义](https://docs.amd.com/api/khub/documents/m4fPXowvxKd5JZRfe046WQ/content)
