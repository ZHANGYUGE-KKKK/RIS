# RFMC6000 CDCM6208 连线与 SPI 配置核查 — 2026-10-14

核查范围：RFMC6000 子板原理图、PZ7035-FH 主板原理图、核心板管脚表、
7035 参考软件及当前 PZ_UART BD/顶层/生效约束。后续驱动和板测状态见末节。

## 来源

- `/home/yyz/ALLdoc/RFMC6000/1 原理图/FMC9361_SCH.pdf`：第 2 页 FMC、第 3 页参考源选择、第 4 页 CDCM6208、第 5 页 AD9361。
- `/home/yyz/ALLdoc/zynq035/05.开发板原理图/璞致PZ7035-FH PZ7045-FH PZ7100-FH平台开发板原理图.pdf`：第 18 页 FMC J26、第 3 页核心板连接器 J4。
- `/home/yyz/ALLdoc/zynq035/04.核心板相关资料/2.PZ7035-7045-7100核心板管脚和等长/璞致PZ7035-7045-7100核心板管脚和等长.xlsx`：J4 表。
- `reference/rfmc6000_7035/src/main.c:93`：SPI1 mode 0 初始化 CDCM6208。
- `reference/rfmc6000_7035/src/spi_ctrl.c:9`：40 MHz 参考时钟预设及 32-bit SPI 帧。
- TI 数据手册：https://www.ti.com/lit/ds/symlink/cdcm6208.pdf 第 47–48 页。

## 必须按 FMC 触点编号映射

子板部分 LAxx 标签与主板不一致，例如子板 G31 标 LA28_P，主板 G31 标 LA29_N。
使用同名 LA 网对接会得出错误 FPGA 引脚。以下全部按连接器实际 G/H 触点核对。

| 信号 | 子板 US1 引脚 | FMC 触点 | 主板 LA 网 | J4 触点 | FPGA 引脚 | 相对 FPGA 方向 |
| --- | --- | --- | --- | --- | --- | --- |
| CDCM_SPI_CLK | 5 SCL/PIN4 | G31 | LA29_N | 92 | AA30 | 输出 |
| CDCM_SPI_MOSI | 2 SDI/SDA/PIN1 | H35 | LA30_N | 95 | AK26 | 输出 |
| CDCM_SPI_MISO | 3 SDO/AD0/PIN2 | G34 | LA31_N | 91 | AE26 | 输入 |
| CDCM_SPI_CS | 4 SCS/AD1/PIN3 | H34 | LA30_P | 93 | AJ26 | 输出，低有效 |
| CDCM_SYNC | 42 SYNCH | G36 | LA33_P | 106 | AG26 | 输出 |
| REF_SELECT2 | 6 REF_SEL | G33 | LA31_P | 89 | AD25 | 输出 |
| REF_SELECT | GPSDO 页 UG2 的 S | G30 | LA29_P | 90 | Y30 | 输出 |

全部属于 BANK12。按当前已确认的 1.8 V VADJ/VCCO 使用 LVCMOS18。
SPI1 四线及 CDCM_SYNC 已在 key_ctrl_55_jm1.xdc 中绑定；REF_SELECT2/REF_SELECT 尚未引出。
SPI 信号是单端 CMOS，不是差分数据，即使所在 FMC 网名有 P/N 后缀也不使用 IBUFDS。

## 时钟路径

板载 XS1 VCTCXO 10 MHz -> CDCM6208 PRI_REFP -> PLL/分频 -> Y1_P (pin17)
-> REF_CLKA_P -> AD9361 的参考时钟输入。参考 SPI 配置目标为 40 MHz。

- SI_MODE0 (pin1) 和 SI_MODE1 (pin47) 在子板上均接地，固定 SPI 模式。
- CDCM_SYNC 是 pin42 SYNCH；不要与 pin44 RESETN/PWR、AD9361 RESETB 混淆。
- CDCM_RESET 仅在时钟页对应 pin44/电容，FMC 控制列表没有该信号。
- CDCM_LOCKED / CDCM_REF_STS 在子板上连接 LED，未在 FMC-LPC 控制列表中引出；
  可先通过 SPI 寄存器 21 核对状态。
- 参考软件 REF_SELECT2=0，选择主参考（板载 TCXO），REF_SELECT=1。
  REF_SELECT 控制次参考路径上的 GPS/外部输入模拟开关，使用主参考时不参与主时钟路径。

## Vivado PS SPI 设置

- 保留当前 AD9361 SPI0 EMIO、SS0，软件 Mode 1。
- 启用 PS SPI1，选择 EMIO；SPI1 Make External，接口命名建议 SPI_CDCM。
- io0 -> MOSI，io1 <- MISO，sck -> CLK，ss0 -> CS；未用 ss1/ss2 不引出顶层。
- 使用 SPI master、单片选/非译码，SS0；wrapper 标准 SPI 接口会生成 IOBUF。
- PS SPI1 固定寄存器基地址 0xE0007000，无需新加 AXI SPI 或分配 PL AXI 地址。
- CPOL/CPHA 在软件 XSpiPs 配置为 0/0（Mode 0），MSB first，CS 空闲高。
  使用独立 XSpiPs 实例，不能复用当前只面向 AD9361 SPI0 的 ad_config SPI 适配回调。
- 初次用 PCLK/256；按当前 PCLK 166.666 MHz 得到约 651 kHz。
  参考程序 /32，约 5.208 MHz；TI 数据手册 SCL 最大 20 MHz。

## 建议 GPIO 分配（新增部分，尚未实施）

将 PS GPIO EMIO 宽度从 1 改为 4，只引出 [3:0]：

| EMIO | XGpioPs 全局编号 | 功能 | FPGA 引脚 | 参考初始化值 |
| --- | --- | --- | --- | --- |
| 0 | 54 | AD9361 RESETB，保留 | T29 | 在线检查后为 1 |
| 1 | 55 | CDCM_SYNC | AG26 | 0，配置锁定后 1/0/1 同步脉冲 |
| 2 | 56 | REF_SELECT2 | AD25 | 0，板载主参考 |
| 3 | 57 | REF_SELECT | Y30 | 1，与示例一致 |

只使用板载主参考时，两个 SELECT 也可由 PL 常量分别固定为 0/1；推荐 GPIO 便于以后选择参考源。

## SPI 帧与软件执行顺序

CDCM6208：16-bit 命令 + 16-bit 数据，合计 32 个 SCLK，同一帧 CS 全程低。
命令 bit15=1 为读，0 为写；bit[14:11] 固定 0；bit[10:0] 为寄存器地址。
读写方向和数据宽度与 AD9361 的 24-bit 单寄存器帧不同。

- 写寄存器 3 = 0x10B0：发送 00 03 10 B0。
- 读寄存器 21：发送 80 15 00 00，后两字节合并为 16-bit 返回值。
- 先设置 GPIO / 初始化 SPI1；核对 R40 识别信息；写入参考 40 MHz 寄存器表。
- 按示例等待 (R21 & 0x000F)==0，加超时；执行 SYNCH 高/低/高，各间隔 10 ms，
  最后等待 500 ms，再测量实际 REF 输出/验证 AD9361 BBPLL。
- CDCM6208 成功后，再运行现有 AD9361 在线检查及完整配置；最终才规划 ARM/DMA。

## 已实施的方案与板测（2026-10-14）

SPI1 EMIO/SS0 已启用，外部接口名 SPI_6208；GPIO EMIO 仍为 1 位，仅保留 RESETB。
CDCM_SYNC 不新增 PS GPIO：顶层 cdcm_sync 在 AG26 固定输出高，软件通过 R3.5 同步。
原先未引出的 AG26 被 FPGA 默认下拉，虽然 CDCM R21=0、PLL 锁定，物理 SYNCN 低仍禁止所有时钟输出，AD9361 BBPLL 因而超时。
已通过仅改变 unused-pin 下拉的临时 bitstream 验证原因；正式版本只增加 cdcm_sync 引脚，不改变其他 unused-pin 设置。

R4 的参考值 0x306C 是 manual 模式、由 REF_SEL 引脚限定的选择。
正式软件使用 0x206C，直接强制选择板载主参考，避免依赖未引出的 REF_SELECT2。
REF_SELECT 只控制次参考的外部/GPS 模拟开关，此方案不使用次参考。
R21 为只读，正式驱动不向其写入；R0..20 全部回读校验，再等待 R21[2:0]=0，执行 R3.5 软件同步。

驱动为 vitis_code/key_ctrlll/src/drivers/cdcm6208.c/.h；main 先保持采集系统复位，配置时钟及 AD9361，再释放复位并检查 PLL。
正式 XSA/bitstream 已重建，并同步至 Vitis 平台和下载路径。
实测 CDCM R40=0x0102、21 个寄存器回读通过、R21=0；AD9361 全套参考配置通过，BBPLL/RXPLL/TXPLL 锁定。
IQ 采集 FRAME_ERROR 仍为 1；这是待检查的采集接口问题，不可将本次 PLL 检查视为数据采集/PN 验证通过。
若以后把 SYNC 改为 EMIO GPIO，必须先移除顶层 cdcm_sync 固定输出，避免 AG26 重复绑定。
详见 ../cdcm6208/ 的最终日志与结果。

