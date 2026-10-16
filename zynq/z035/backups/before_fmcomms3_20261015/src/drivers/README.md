# RIS GPIO、CDCM6208、AD9361 与 I/Q 采集驱动

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
`src/drivers` 中的五组驱动。项目根目录的 `makefile.defs` 为尚未重新生成
托管 makefile 的命令行构建补上缺失文件，避免重复链接。

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

## 新增采集接口

三组文件沿用现有的小写下划线文件名、同名前缀 API、`*_device` 上下文、
`*_OK`/负值错误码和 `*_status_string()` 风格：

| 文件 | 职责 | 当前硬件 |
| --- | --- | --- |
| `gpio_9361.c/.h` | ARM、六个采集状态、就绪等待 | `axi_gpio_9361`，`0x80020000` |
| `dma_9361.c/.h` | SG 描述符、S2MM 启动、轮询、超时、数据交付 | `axi_dma_0`，`0x81000000` |
| `mig_ddr.c/.h` | DDR 地址/对齐检查、MMU 属性、DMA 缓存所有权 | MIG，`0x40000000–0x7FFFFFFF` |

`ad9361.c/.h` 和 `gpio_ris.c/.h` 已对照最新 BSP 检查，现有寄存器访问和 RIS 模式
仍匹配当前硬件。AXIS Data FIFO 没有 AXI Lite 控制接口，软件通过上游状态、DMA
及系统复位管理；没有额外的 FIFO MMIO 驱动。MIG 的硬件校准由其 RTL 执行，
`mig_ddr_init()` 只初始化并核对地址范围，不代表 DDR 校准完成。

### 采集 GPIO

通道 1 是 **1 位全输出**，仅 bit0 为 ARM；没有 GPIO 复位位。通道 2 是
32 位输入，驱动只读取低六位；高 26 位当前硬件填零：

| bit | 宏 | 含义 |
| --- | --- | --- |
| 0 | `GPIO_9361_READY_MASK` | IDELAY/FIFO 就绪 |
| 1 | `GPIO_9361_FRAME_LOCKED_MASK` | 已获取完整双 RX 帧 |
| 2 | `GPIO_9361_ACTIVE_MASK` | 已 ARM 且没有采集故障 |
| 3 | `GPIO_9361_OVERFLOW_MASK` | 缓冲区满导致漏样 |
| 4 | `GPIO_9361_FRAME_ERROR_MASK` | FRAME 格式异常 |
| 5 | `GPIO_9361_DELAY_ERROR_MASK` | IDELAYCTRL 失锁 |

这些位分别跨域同步，是独立电平，不能视作 RX 域的原子状态快照。
`gpio_9361_check_ready()` 要求 READY、FRAME_LOCKED 为 1，没有错误且没有既有
ARM。`gpio_9361_arm()` 只在检查通过后写 bit0；必须先让 DMA 准备好接收。

ARM 在 RTL 中锁存。`gpio_9361_release_arm()` 只拉低命令位，**不会停止或复位
接收模块**，也不清除错误或 FIFO。结束、中止或故障后，再次采集必须用真实
PL/系统复位或重新下载 bitstream，并重新初始化软件上下文。AD9361 RESETB
和 AXI DMA reset 都不能代替接收器及两级 FIFO 的系统复位。

### SG DMA 与存储布局

当前配置为 SG、仅 S2MM、64 位 AXIS/内存写口、32 位地址、23 位长度，无 DRE。
使用轮询，驱动关闭 DMA 中断；当前连入 PS 的中断号为 61，未安装中断处理器。
SG 描述符和采集数据都放在 MIG；DMA 两个主口均已映射完整 MIG 地址范围。

每个 BD 接收一个完整 AXIS 包：4096 组双通道 IQ × 8 字节 = **32768 字节**。
BD 至少按 64 字节对齐，数据地址/长度按 32 字节对齐，两区域必须分离，均不能
越过 MIG 范围。大样本窗口使用多个预排队的 BD，不能把整个窗口当一个 AXIS 包。
CPU 的虚拟/物理地址使用恒等映射，不把 PS DDR 中的普通数组直接交给当前 DMA。

默认建议布局（只有显式调用 `prepare()` 才占用/写入内存）：

| 区域 | 地址 | 默认 256 包的占用 |
| --- | --- | --- |
| BD 环 | `0x40000000` | 256 × 64 = 16 KiB |
| 采集数据 | `0x40100000` | 8 MiB，1,048,576 组双通道复数样本 |

`mig_ddr_map_uncached()` 按 Cortex-A9 的 1 MiB MMU section 将这些区域设为
Normal Non-cacheable。调用者必须独占涉及的完整 section，并在交给 DMA 前
完成映射。接收前清理缓存，接收后只 invalidate，不 flush DMA 写好的数据。
软件不可在 DMA 接收时读写目标缓冲区；程序、栈、堆继续位于 PS DDR，链接脚本
未移动到 MIG。两个 CPU 核不能并发访问这些驱动和 DMA 缓冲区。

`dma_9361_prepare()` 检查地址、大小、对齐和重叠，初始化完整 BD 环；
`dma_9361_start()` 将所有 BD 交给 DMA，启动 S2MM，再拉高 ARM。
`dma_9361_poll()` 返回 1 表示进行中、0 表示完成、负数表示失败。
`dma_9361_wait()` 有微秒超时和轮询上限；超时、DMA 错误、采集错误或包格式
错误会中止 DMA，保留 `last_dma_status`、`last_bd_status`、`last_capture_status`
及已处理字节数，禁止把部分缓冲区作为成功记录读取。

每个完成 BD 都检查 COMPLETE、RX SOF/EOF、32768 字节实际长度、描述符序号
和目的地址。只有整个窗口检查通过且没有观测到采集故障，
`dma_9361_get_samples()` 才交付数据指针和样本组数：

```c
typedef struct {
    s16 i1; /* DDR 字节 0..1 */
    s16 q1; /* DDR 字节 2..3 */
    s16 i2; /* DDR 字节 4..5 */
    s16 q2; /* DDR 字节 6..7 */
} dma_9361_sample;
```

每个分量是有符号 12 位样本的 16 位符号扩展；驱动不抽取、不缩放、不改频率。
本版本保存一个有限窗口，不循环覆盖、也不自动续挂 BD。当前 RTL 没有有限样本
计数停止接口，完成最后一个 BD 后输入仍采样，上游 FIFO 最终可能溢出；软件
返回的是已完成并校验的窗口，之后必须复位才能再次采集。如果故障在完成判定
前被观察到，驱动保守地将本次记录判为失败。完整数据不代表板级采样窗口已校准。

### 调用示例

当前 `helloworld.c` 自动完成 RIS、AD9361 在线检查、采集 GPIO 和 DMA 控制器
初始化并打印状态。它不访问采集 DDR、不置 ARM；在线检查尚未配置 AD9361
参考时钟、双 RX LVDS DDR、周期性 FRAME 和采样率，READY/FRAME_LOCKED 可能为 0。
必须先完成数字接口配置、PN/采样窗口验证和 MIG 校准，再调用下面的采集流程。

```c
#include "drivers/gpio_9361.h"
#include "drivers/dma_9361.h"

static gpio_9361_device capture;
static dma_9361_device receiver;

int capture_window(const dma_9361_sample **samples, u32 *sample_count)
{
    int status;

    status = gpio_9361_init(&capture);
    if (status != GPIO_9361_OK)
        return status;
    status = dma_9361_init(&receiver, &capture);
    if (status != DMA_9361_OK)
        return status;
    status = dma_9361_prepare(&receiver, DMA_9361_DEFAULT_BD_BASE,
                              DMA_9361_DEFAULT_BUFFER,
                              DMA_9361_DEFAULT_PACKETS);
    if (status != DMA_9361_OK)
        return status;
    status = gpio_9361_wait_ready(&capture, 100000U);
    if (status != GPIO_9361_OK)
        return status;
    status = dma_9361_start(&receiver);
    if (status != DMA_9361_OK)
        return status;
    status = dma_9361_wait(&receiver, 1000000U);
    if (status != DMA_9361_OK)
        return status;
    return dma_9361_get_samples(&receiver, samples, sample_count);
}
```

示例为一次采集，调用者应使用对应模块的 `*_status_string()` 解读其返回值；
外层业务代码如需统一错误码，应转换 GPIO/DMA 错误，避免同为负数时混淆。
再次运行前必须复位 PL。消费数据期间不重新初始化、复用或改写该 DDR 窗口。

### 本次软件验证

- `key_ctrl` 平台/BSP 已根据最新含 bitstream 的 `pz7035_top.xsa` 生成，已包含
  `axidma` 驱动和 `axi_gpio_9361` 参数；下载用 bitstream/PS 初始化脚本已同步。
- 五组驱动均用真实 BSP 通过 `-Wall -Wextra -Werror` 检查，应用已 ARM 编译链接。
- 临时 C 主机模型在 AddressSanitizer/UBSan 下验证 DDR 边界/对齐、ARM 锁存、
  DMA 先于 ARM、完成描述符/短包/帧边界/顺序检查、CPU 缓存所有权、三个采集
  错误、DMA/BD 错误、传输/复位超时及中止语义；全部通过。
- Vitis IDE 占用 workspace 时，XSCT 的 `app build` 被拒绝，并在辅助进程退出时
  触发工具崩溃；本次使用上述 Make 构建实际生成 ELF，未绕过 BSP 或替换硬件驱动。
- 未下载到板卡或执行真实 DDR DMA 采集；报告在 `zynq/z035/reports/capture_drivers/`。

## 参考

- 本地 `AD9361设计资料/AD9361_Design_File_Package.zip` 中的
  `AD9361_Reference_Manual_UG-570.pdf`（SPI、软件复位）与
  `AD9361_Register_Map_Reference_Manual_UG-671.pdf`（0x000、0x037）。
- 本地 `1 原理图/FMC9361_SCH.pdf`（RESETB 上拉）与
  `3 FPGA测试例程/adaloop_deepreads.zip` 中的 7035 SPI 示例。
- [ADI 官方 SPI 命令和 ID 定义](https://github.com/analogdevicesinc/no-OS/blob/main/drivers/rf-transceiver/ad9361/ad9361.h)。

## 2026-10-14 当前启动流程与 CDCM6208

`cdcm6208.c/.h` 沿用同名前缀 API、设备上下文、负值错误码和 status_string 风格。
SPI1 EMIO @0xE0007000 / SS0 / Mode 0 / MSB first / PCLK/256 ≈651041 Hz，SPI0 不受影响。
MOSI AK26、MISO AE26、SCLK AA30、CS AJ26，LVCMOS18；每次 16 位命令+16 位数据在同一连续 CS 内完成。
读命令 bit15=1，写为0，与 AD9361 相反。传输有20 ms及轮询次数上限，失败释放CS并禁止继续使用异常控制器。

使用 `reference/rfmc6000_7035/src/spi_ctrl.c` 的 V1 / 40 MHz 寄存器表。
R4改为0x206C，寄存器强制选择板载10 MHz主参考，避免依赖未引出的 REF_SELECT2。
R21是只读，不向其写入。R40连续8次检查V1生产版身份，实测0x0102；R0..20全部回读校验。
R21[2:0]必须为0（主参考、参考存在、PLL锁定），等待最多5秒；同步前后各连续8次检查。
R3.5执行软件SYNCN脉冲，最后等待500 ms，读取同步释放状态。

正式硬件新增顶层 `cdcm_sync` / FPGA AG26，固定输出高。此前未使用的该引脚被FPGA默认下拉，
物理SYNCN低会关闭输出，即使CDCM内部PLL已锁定。正式版本保留其他未使用引脚的原设置。
只更新软件并使用旧bitstream仍会重现AD9361 BBPLL超时。
PS GPIO EMIO仍为1位RESETB；本方案无需三个新EMIO GPIO。未来改为GPIO驱动SYNC时必须移除固定输出。

当前 main 调用顺序替代上文早期在线检查流程：
1. `rf_capture_reset(1)`：通过SLCR FPGA_RST_CTRL[0]保持FCLK0采集/FIFO/DMA/GPIO复位。
2. `cdcm6208_init()`：配置主参考、回读和同步，确保时钟PLL锁定。
3. `ad9361_init()` 在线/硬件复位检查，再在时钟配置成功时运行 `ad_config_init()`。
4. 释放FCLK0复位，初始化RIS MONITOR、采集GPIO、DMA，调用原MIG自测。
5. `rf_clock_selftest()`：连续20次、2秒检查CDCM及AD9361 BBPLL/RXPLL/TXPLL，打印RX状态；ARM保持0。

配置目标仍为参考的40 MHz REF、Fs61.44 MSPS、BW30.72 MHz、RX LO200 MHz、TX LO5997 MHz、MGC5 dB、TX衰减0 dB，RX/TX FIR开启。
板上RF配置和PLL测试通过；最终采集状态为0x11（READY=1、FRAME_LOCKED=0、FRAME_ERROR=1）。
因此DMA初始化返回-8、MIG本次测试因前置条件不满足而跳过，整体main返回1。
这不表示RF配置失败或MIG内存发现错误，也不代表IQ数据采集通过；FRAME/采样对齐仍待另行处理。
临时扫描16档RX时钟延时未找到FRAME窗口；该实验未留在正式main，也未更改最终寄存器006=0x04。
PLL状态是数字锁定证据，本次没有用示波器测量参考时钟频率、抖动或幅度。

Vitis GUI已更新key_ctrl硬件规格并完成平台/应用Build，托管makefile已包含cdcm6208。
最新XSA、平台导出的bitstream和应用`_ide`下载文件一致；本次JTAG配置为易失性下载，未写Flash。
串口实际为/dev/ttyUSB1，PuTTY使用CP2102的/dev/serial/by-id固定路径、115200 8N1。
证据目录：`zynq/z035/reports/cdcm6208/`。

参考：[TI CDCM6208手册](https://www.ti.com/lit/ds/symlink/cdcm6208.pdf) 的SPI协议、R3/R4/R21/R40与软件同步说明；
[UG585 FPGA_RST_CTRL](https://docs.amd.com/r/en-US/ug585-zynq-7000-SoC-TRM/Register-slcr-FPGA_RST_CTRL)。
