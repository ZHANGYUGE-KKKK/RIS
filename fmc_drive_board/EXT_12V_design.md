# 外接 12 V 电源修订

2026-09-28，在现有 `ris_drive_board_v1.eprj2` 中保留并修订 **EXT_12V**、**PWR_CTRL**，将原 `RIS_1V5` 页改为 **BATTERY_GND**。1.5 V 稳压电路已移除；144 路输出仍保留网络标记，未增加 RIS 连接器，也未进行 PCB 布局。

## 电源结构

```text
12 V 稳压适配器，5.5 × 2.5 mm，中心正极
  → J2 → F1 保险丝 → D1 防反接 → SW1 总电源开关
  → 输入电容 / D2 TVS → U21 TPS54302 降压 → VCC33_LOCAL（标称 3.3 V）
                         └─ U1～U18 的 VCCB：144 路 3.3 V 控制输出

外部干电池组单独提供 RIS 的 1.5 V；J3 为 1×4、2.54 mm 电池盒 GND 汇接排针

FMC VADJ（2.5 V）→ U1～U18 VCCA、控制逻辑及状态上拉
FMC GND、子板 GND、外接适配器负端和 RIS GND 共地
```

两种输入共地，没有电气隔离。本地 3.3 V 和 12 V 均不接入 FMC 电源脚，避免与载板电源直接并联。FMC **C35、C37、C39、D32、D36、D38、D40 均 NC**；G39/H40 保留 VADJ。3.3 V 控制输出与 RIS 的独立负载电源不是同一概念。

## 输入与降压器件

| 位号 | 器件 / 参数 | 作用 |
| --- | --- | --- |
| J2 | Same Sky / CUI PJ-102B，C22359713 | 匹配 5.5 × 2.5 mm 插头；1 脚中心正极，2 脚套筒 GND，3 脚切换触点 NC |
| F1 | 046701.5NR，1.5 A 快断，C99559 | 输入保险丝 |
| D1 | SS54，40 V / 5 A，C22452 | 串联肖特基防反接；A 接保险丝，K 接受保护输入 |
| SW1 | C&K 1101M2S3AQE2，C23405856，SPDT On-None-On | 子板主电源开关；2 脚为公共端，ON 档接 1 脚，OFF 档接 NC 的 3 脚；4/5 为机械脚 NC；额定 6 A / 28 VDC |
| D2 | SMBJ15A，单向 TVS，C357961 | K 接受保护输入，A 接 GND；15 V 反向工作电压 |
| C61 | 47 µF / 35 V，EEEFK1V470P，C178565 | 输入电解储能 |
| C62/C63 | 各 10 µF / 50 V，C13585 | 输入陶瓷电容 |
| C64/C65 | 各 100 nF，C14663 | VIN 去耦 / BOOT-SW 自举；C65 下端必须接 SW |
| U21 | TPS54302DDCR，C311983 | 同步降压，标称 400 kHz |
| L1 | SRP7050TA-6R8M，6.8 µH，C2046414 | 额定 RMS 电流 5.5 A，饱和电流 8.5 A |
| C66/C67 | 各 22 µF / 25 V，C12891 | 本地 3.3 V 输出电容 |
| R15/R16 | 100 kΩ / 22.1 kΩ，均 0.1% | FB 分压；标称输出 0.596 × (1 + 100/22.1) = 3.293 V |
| C68 | 47 pF，C1671 | 并联 R15 的前馈电容 |
| R17/R18 | 511 kΩ / 105 kΩ | EN 欠压门限，受保护输入端典型启动约 6.86 V、关闭约 5.66 V |
| R21 + D3 | 1 kΩ + LTST-C190KRKT，C94869 | 接在 VCC33_LOCAL 后级；红色 LED 约 1.3 mA，表示本地 3.3 V 已建立 |

建议使用正规 **12 V / 2 A、中心正极**稳压适配器。SW1 额定 28 VDC / 6 A，高于本板的 12 V / 2 A 输入目标；仍须在 PCB 上给开关和输入铜箔留出足够爬电、载流及机械空间。插头外径和内径依据 PJ-102B 原厂机械图的 mating plug 尺寸，图中还有约 9.5 mm 的插入长度要求；采购及布板时复核配合尺寸、插座焊盘和板边空间。

本地 3.3 V 以 **2 A 总电流**为布局和热设计目标；TPS54302 的 3 A 器件规格不等于本板已经验证的连续供电能力。SW1 只负责切断 12 V 后级，D3/R21 只表示 VCC33_LOCAL 出现，精确的 3.3 V 状态仍看 PWR_READY。按 6.6 W 输出、85% 效率举例，12 V 输入约 0.65 A，实际还取决于工作点和二极管损耗。当前 3.3 V 负载预算主要包括 18 片 595 的 VCCB、输出电流和去耦瞬态。

反馈参考全温最大 0.611 V 加上两个 0.1% 电阻的最坏组合，直流输出上限计算约 **3.381 V**。这个计算不包括纹波和瞬态，布板后必须检查启动、插拔和负载跳变峰值。保险丝、串联二极管和 TVS 提供基本输入保护，不代表可以使用任意电压的适配器，也不保证持续过压故障安全。

## 独立电源的输出使能联锁

| 位号 / 网络 | 实现 |
| --- | --- |
| U22 | TPS3808G33DBVR，C43698；VDD 接 VADJ，SENSE 接 VCC33_LOCAL，标称门限 3.07 V |
| U22 MR# | 接 VADJ；仅监测本地 VCC33_LOCAL，不再依赖板上 1.5 V |
| U22 CT | 按手册留空，典型释放延时约 20 ms |
| PWR_READY | U22 开漏 RESET# 经 R19 10 kΩ 上拉 VADJ，并接 **FMC D18 / LA13_N / ZC706 Bank 10**，作为 FPGA 输入 |
| U23 | SN74LVC2G00DCUR，C206109；VCC 接 VADJ，第一门反相 OE_N，第二门与 PWR_READY 组合 |
| OE_SAFE_N | `OE_N OR NOT(PWR_READY)`，R20 10 kΩ 上拉 VADJ；连接全部 18 个寄存器的 18 脚 |
| C69/C70 | 各 100 nF，分别靠近 U22/U23 电源脚 |

FPGA 原 OE_N 仍在 H16；18 路 DS、SHIFT_CLK、LATCH_CLK、MR_N 和 LED 引脚映射均保留。新增 D18 后共占用 26 路 FPGA 信号，保持同一个 Bank 10。状态信号按 VADJ=2.5 V 使用 LVCMOS25。

| PWR_READY | FPGA OE_N | 寄存器 OE_SAFE_N | Q 输出 |
| --- | --- | --- | --- |
| 0 | 任意 | 1 | 高阻 |
| 1 | 1 | 1 | 高阻 |
| 1 | 0 | 0 | 输出锁存的数据 |

FPGA 上电和检测到 PWR_READY 下降时均应把 OE_N 置高。待 PWR_READY 稳定，18 路 DS 同步移入各自 8 bit，共用 LATCH_CLK 锁存，再把 OE_N 拉低。硬件只判断本地 3.3 V 状态，**不会判断数据是否重新初始化，也不会监测外部电池的 1.5 V**：如果 FPGA 始终把 OE_N 留低，外接电源恢复后延时结束就会开放输出。因此必须在 FPGA 中处理电源恢复后的重新装载；RIS 单元负责外部 1.5 V 的电源监测。

## 布板与验证状态

输入陶瓷去耦靠近 U21 VIN/GND，自举电容靠近 BOOT/SW；缩小开关电流回路，FB 取样远离 SW，输入、输出电容地回路就近闭合。保留 3.3 V 的散热铜皮与测量空间。电池盒负极通过 J3 的四个 2.54 mm 针脚接入板上 GND；外部 1.5 V 正极和 RIS 端连接器针序另行确定。

嘉立创EDA实时 API 已核对当前修订：EXT_12V 保留 12 V 输入、开关、3.3 V 降压和上电 LED；PWR_CTRL 只监测 VCC33_LOCAL；BATTERY_GND 页的 J3 四个针脚均接 GND；18 路 DS、144 路 Q、FMC D18 和 OE 联锁均保留。旧的 `ris_external_12v_verified.enet` 是改动前网表记录，不能作为当前电池版网表使用。

DRC API 返回 **174 条警告，未返回 error 项**。当前 API 仅给出警告汇总，未提供明细；不能据此宣布原理图零警告或可直接投产。尚未进行电气仿真、PCB 散热/稳定性验证和样板测试。样板至少检查全低/全高及同步翻转、外部电池与主板的不同上电顺序、外接电源掉电/恢复、12 V 插拔过冲、线缆压降及器件温升。

外接电池改动前备份：`ris_drive_board_v1_backup/ris_drive_board_v1_before_external_battery_2026-09-28.eprj2`；更早的外接 12 V 和 SW1 备份仍保留。`eda_external_12v.mjs` 是已执行的绘制记录，不能重复运行 place/wire/migrate。当前实时检查脚本为 `verify_battery_revision.mjs`；旧 `ris_external_12v_verified.enet` 和 `verify_external_12v.mjs` 仅供改动前追溯。

原厂依据：[PJ-102B 机械图](https://www.sameskydevices.com/product/resource/pj-102b.pdf)、[TPS54302](https://www.ti.com/lit/ds/symlink/tps54302.pdf)、[TPS3808](https://www.ti.com/lit/ds/symlink/tps3808.pdf)、[SN74LVC2G00](https://www.ti.com/lit/ds/symlink/sn74lvc2g00.pdf)、[Bourns SRP7050TA](https://www.bourns.com/docs/Product-Datasheets/SRP7050TA.pdf)。PJ-102B 与 TPS54302 手册另存于 `references/`。
