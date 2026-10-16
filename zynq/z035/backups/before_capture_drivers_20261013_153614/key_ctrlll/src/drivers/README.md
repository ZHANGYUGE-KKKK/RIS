# RIS GPIO 控制与 RFMC6000 AD9361 初始通信检查

## RIS GPIO

当前 XSA 中 `axi_gpio_ris_ctl` 通过 PS M_AXI_GP1 连接，地址范围
`0x80010000–0x8001007F`，单通道 32 位输出，连接 `key_ctrl_55/gpio_cfg`。
`gpio_ris.c/.h` 使用 BSP 的 XGpio 驱动及符号地址，不直接操作 PS GPIO。

| 模式 | [31:29] | 指令示例 | 行为 |
| --- | --- | --- | --- |
| MONITOR | 100 | `0x80000000` | 保留原按键去抖控制 |
| PS | 101 | `0xA0000000` / `0xA1FFFFFF` | 25 路全部为 0 / 全部为 1 |
| AUTO | 111 | `0xE0000000` | RTL 产生 1 MHz 方波，全部输出同步翻转 |

[28:25] 保留位始终写零；[24:0] 按行排列，bit0 对应 `out_1_1`，
bit24 对应 `out_5_5`。初始化默认选择 MONITOR，不自动启动 AUTO。
25 路只通过一条完整的 32 位写入更新，不使用 GPIO 寄存器读改写。

```c
#include "drivers/gpio_ris.h"

gpio_ris_device ris;
int status = gpio_ris_init(&ris); /* 检查 status == GPIO_RIS_OK 再操作 */
if (status == GPIO_RIS_OK) {
    gpio_ris_set_outputs(&ris, 0x01FFFFFFU); /* 切换 PS，全部为 1 */
    gpio_ris_set_pin(&ris, 5U, 5U, 0U);     /* 仅清除 out_5_5 */
    gpio_ris_set_mode(&ris, GPIO_RIS_MODE_MONITOR);
}
```

`gpio_ris_set_outputs()` / `gpio_ris_set_pin()` 都切换为 PS 模式；
`set_mode(PS)` 恢复此前 PS 模式的输出数据。`gpio_ris_get_command()` 只返回
软件缓存的最后一条指令，不表示引脚实际电平。非法模式、超过 25 位的数据、
越界行列和未初始化调用会返回错误。AUTO 的频率由 RTL 产生，软件只切换模式。

## AD9361

本驱动完成 SPI 通信初始化、GPIO 硬件复位和芯片在线检查。它不是完整的
AD9361 RF 初始化驱动，不配置 LO 频点、采样率、带宽、参考时钟、CDCM6208、
AGC 或收发校准。硬件复位会清除芯片此前的寄存器设置。

## 硬件对应关系

使用当前 `pz7035_top` 的 PS SPI0 EMIO，寄存器基地址 `0xE0006000`，片选 SS0。
SPI 使用 Mode 1（CPOL=0、CPHA=1）、MSB first、4-wire、PCLK/256；当前 BSP 的 PCLK 是
166666672 Hz，因此 SCLK 约为 651041 Hz。

驱动按模块示例使用单主机模式，关闭 SPI 控制器的多主机 ModeFail 生成。
当前 wrapper 的 SS IOBUF 会将片选电平回读到 SSIN，关闭该功能避免将自己的
低电平片选识别为其他主机的占用。若以后更改为多主机总线，需要重新设计此设置。

| 信号 | 顶层端口 | FPGA 引脚 | IOSTANDARD |
| --- | --- | --- | --- |
| MOSI | SPI_9361_io0_io | U25 | LVCMOS18 |
| MISO | SPI_9361_io1_io | N26 | LVCMOS18 |
| SCLK | SPI_9361_sck_io | V26 | LVCMOS18 |
| CS0 | SPI_9361_ss_io | T22 | LVCMOS18 |

当前 XSA 的 PS GPIO EMIO 宽度为 1，顶层只引出 `GPIO_PS_tri_io[0]`，
经 FPGA T29 连接 AD9361 RESETB；EMIO[63:1] 未引出。软件定义集中在 `ad9361.h`：
`AD9361_RESET_EMIO_INDEX = 0`，`AD9361_RESET_GPIO_PIN = 54 + 0 = 54`。
这里的引脚号 54 是 XGpioPs 的全局编号，不是 FPGA 封装引脚。

RESETB 对应 FMC D23；生效的 `key_ctrl_55_jm1.xdc` 将其映射到 FPGA T29、LVCMOS18。
软件只依赖 EMIO 索引。模块上的 RA2
（10 kΩ）将 RESETB 上拉到 VADJ。示例驱动指出 SPI 软件复位不可靠，本驱动
不使用该回退流程，也不控制 ENABLE/TXNRX 或其他 EMIO 输出。

必须使用已接好 RESETB 的新 bitstream，再尝试此 ELF。GPIO寄存器写入本身
不能证明信号已到达芯片，最终以有效 ID 及实际复位波形为准。

## 执行顺序与成功标准

`helloworld.c` 的 `main()` 先初始化 RIS 为 MONITOR，再调用 `ad9361_init()`：

1. 初始化 PS SPI0，配置 Mode 1 和 SS0，禁用 SPI 中断。
2. 初始化 XGpioPs。仅设置引脚 54：先预置高电平并配置为输出，检查方向和
   输出使能；保持高 1 ms，再拉低 1 ms、拉高并等待 1 ms。低、高阶段分别读取
   FPGA 引脚反馈，预期为 0、1；反馈不符则报复位错误，不继续访问 AD9361 SPI。
   所有复位路径最后均写高电平，关闭驱动也保持高电平。
3. 写 `0x000 = 0x00`，等待 1 ms，设置四线、MSB-first，D4:D3 留零。
4. 连续读取 8 次 `0x037`，要求所有原始值相同，且 `(id & 0xF8) == 0x08`。
   低 3 位是芯片版本号，常见原始值为 `0x0A`，不固定要求该值。
5. 读取 `0x000`，核对有效位仍为四线、MSB first、复位释放。

单字节读 `0x037` 的 MOSI 帧是 `00 37 00`，第三个接收字节才是 ID。
写 `0x000 = 0x00` 的 MOSI 帧是 `80 00 00`。
每帧的三个字节在同一个连续的 CS 低电平内发送，不将地址和数据拆成两次传输。

成功仅表示 AD9361 的 SPI 可访问，不能说明 RF PLL 已锁定、收发时钟正常或
采样链路已经可用。本实现没有写入 RFPLL/BBPLL、参考时钟或校准寄存器。
引脚反馈正确只能验证 FPGA 管脚电平，不能单独证明 FMC 模块已经收到复位。
公开的 `ad9361_reset()` 会清除缓存的在线标志；成功后需要重新调用
`ad9361_check_online()` 检查芯片。复位本身不会配置频点或恢复 RF 参数。
配置寄存器回读为 `0x00` 时无法独立证明配置写入已生效；成功判断主要来自
稳定且有效的芯片 ID，应结合示波器或逻辑分析仪检查写入波形来进一步确认。

## 编译与下载

在 Vitis 刷新 `key_ctrlll` 项目，再 Build；托管构建会自动发现
`src/drivers/ad9361.c` 和 `gpio_ris.c`。项目根目录的 `makefile.defs` 为尚未
重新生成托管 makefile 的命令行构建补上这两个文件，避免重复链接。

命令行构建：

```bash
source /home/yyz/vivado2020.2/main/Vitis/2020.2/settings64.sh
make -C /home/yyz/work/RIS/zynq/z035/vitis_code/key_ctrlll/Debug main-build
```

生成新 bitstream 后导出 XSA，在 Vitis 更新平台/BSP，并同步调试配置的
bitstream 与 `ps7_init.tcl`，重新 Build 后下载 `Debug/key_ctrlll.elf`。
本次已按最新 `pz7035_top.xsa` 更新 `key_ctrl` 平台/BSP，并同步应用
`_ide/bitstream/pz7035_top.bit` 和 `_ide/psinit/ps7_init.tcl`。
保留 `ps7_init` 和 `ps7_post_config`。程序位于 PS DDR（起始地址 `0x00100000`）。
UART 波特率 115200、8N1。以下是成功时的输出示例，不是已经实测的结果：

```text
RIS AXI GPIO @0x80010000: MONITOR, command=0x80000000
RESETB feedback: asserted=0, released=1
SPI clock: 651041 Hz; PRODUCT_ID[0x037]=0x0a
AD9361 ONLINE: revision=2, SPI_CONF[0x000]=0x00
PASS: 8 stable ID reads and SPI mode readback
```

失败会打印具体错误、原始 ID、最后访问的寄存器及 SPI 状态。`0x00` 或 `0xFF`
不是有效 ID，需要检查模块供电、VADJ、RESETB 和 MOSI/MISO/CS 接线。
控制器超时或模式错误后会释放 CS、关闭控制器，并禁止继续传输；应排查后重新
初始化再运行。寄存器读写 API 是阻塞式，不支持 SPI0 并发访问。
每次传输有 20 ms 计时限制及轮询次数上限；它不能捕获 CPU 本身无法完成的
APB 总线访问或外部复位。

## 验证

板上是否在线，必须以下载后的 UART 输出或真实 SPI 波形为准。
工程内没有新增 Python 测试脚本；主机模拟检查放在临时目录，不参与 Vitis 构建。

## 参考

- 本地 `AD9361设计资料/AD9361_Design_File_Package.zip` 中的
  `AD9361_Reference_Manual_UG-570.pdf`（SPI、软件复位）与
  `AD9361_Register_Map_Reference_Manual_UG-671.pdf`（0x000、0x037）。
- 本地 `1 原理图/FMC9361_SCH.pdf`（RESETB 上拉）与
  `3 FPGA测试例程/adaloop_deepreads.zip` 中的 7035 SPI 示例。
- [ADI 官方 SPI 命令和 ID 定义](https://github.com/analogdevicesinc/no-OS/blob/main/drivers/rf-transceiver/ad9361/ad9361.h)。
