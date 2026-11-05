RIS 控制单元：ZC706 单片 74LVC8T595 起步工程
更新日期：2026-10-21（Asia/Shanghai）

当前范围
  用户于 2026-10-21 授权在本目录新建工程并实现单个移位寄存器控制 RTL。
  DISCUSSION_20261020.txt 保留为历史讨论，其“只构思”记录对应当时状态。
  当前完成的是单片 8 位驱动、最小 PS 控制通路和仿真环境。
  400 位整帧、多组独立控制、DMA、网口上传、XDMA、两板同步留待后续。
  RX 与 RIS 继续使用两块独立 ZC706；RIS 子板接本板 FMC LPC。

打开工程
  vivado/ris_ctrl_unit.xpr
  器件：xc7z045ffg900-2；板卡：xilinx.com:zc706:part0:1.4。
  顶层：rtl/ris_ctrl_unit_top.v；Block Design：ris_system。
  vivado/ 为生成目录；源码、约束和 Tcl 位于其外，可重新创建。

Zynq 基础配置
  constraints/zc706_ps_preset.tcl 是相邻 fmcomms3_rx 同名文件的本地快照。
  PS DDR：32 位、1 GiB、533.333 MHz，保留 ZC706 板级布线延迟和训练配置。
  UART1：MIO48/49，100 MHz 外设时钟；ENET0/MDIO/PHY reset 保留参考配置。
  ENET0 时钟目标暂沿用参考 preset 的 100 Mbps；本阶段没有网络程序。
  后续实现千兆传输时，需要随软件一起设置、验证 GEM 时钟与协商速率。
  FCLK0：100 MHz，单一 PL 时钟域；proc_sys_reset 同步释放复位。
  M_AXI_GP0 → AXI Interconnect → 双通道 AXI GPIO，基址 0x41200000。
  GPIO 通道 1 为 32 位命令输出，通道 2 为 32 位状态输入。
  SPI0/SPI1、EMIO、QSPI、SD、I2C、USB、TTC 关闭；HP/DMA/MIG 尚未接入。

RTL 分层
  rtl/ris_595_byte.v
    单片 8 位数据单元：接受 load、advance、latch 事件，输出 DS。
    暂存本次字节，bit7 先发；latched_data 仅为命令镜像，无物理回读。
    后续同一组的 5 个实例复用同一组事件，不能分别驱动共享时钟。
  rtl/ris_595_timing.v
    统一时序器：产生 8 次 SHCP 上升沿和 1 次 STCP 锁存。
    advance 与 SHCP 下降沿同时发生；所有内部逻辑只使用 clk 上升沿。
    上电/复位：MR 低保持 → MR 释放与恢复 → ready。
    更新：装载字节 → 8 次移位 → 锁存前保护 → STCP 高 → 恢复 → done。
    HALF_PERIOD_CYCLES 默认 5，100 MHz 下半周期 50 ns、SHCP 为 10 MHz。
    移位低/高、锁存前等待、STCP 高、锁存后恢复均使用此周期数。
    请求接受到 done 为 19×HALF_PERIOD_CYCLES 个 clk 周期。
    参数须 >=1；提高频率前需重新核对器件和板级时序。
  rtl/ris_595_single.v
    组合一个数据单元和时序器；start && ready 接受请求。
    start 应为单周期脉冲；忙时请求丢弃，无队列。
    首次 done 后置 valid，OE 仅在 valid 且 output_enable 时拉低。
    复位清 valid 并立即禁能 OE；普通更新不翻转 MR/OE。
  rtl/ris_595_bringup.v
    PS GPIO 命令/状态前端，将 START 上升沿转换为单周期请求。
    暂时仅允许 DATA_U01（实物 U4）接收任意字节。
    DATA_U02..50 固定为 0，10 组 SHCP/STCP 同时更新。
    因为 OE/MR 为全板共享，先给其余芯片移入并锁存零，再允许全板输出。
    这只是首片验证接法，尚不支持保留其余 49 片已有图案。

位序与引脚
  字节 bit0..7 对应 U4 Q0..Q7，即 RIS_Q001..Q008。
  ris_data[0] = DATA_U01，ris_data[49] = DATA_U50。
  ris_shcp[0]/ris_stcp[0] 对应第 1 组；索引 9 对应第 10 组。
  全 72 路 XDC：constraints/ris_lpc.xdc；均为 LVCMOS25、8 mA、SLOW。
  引脚依据：constraints/signal_pin_mapping.csv，快照自
    ../fmcomms3_rx/reports/lpc_daughterboard_20261020/signal_pin_mapping.csv。
  数据/时钟寄存器到引脚使用 10 ns datapath 上限；50 ns 协议相位由状态机保证。
  这项约束不等于已经完成布线后或实物板级时序验证。
  OE 高为高阻，MR 低只清移位寄存器、不清输出锁存器。
  器件时序依据：Nexperia 74LVC8T595，Rev.2，2023-08-29：
    https://assets.nexperia.com/documents/data-sheet/74LVC8T595.pdf

最小 PS 寄存器接口（AXI GPIO）
  0x41200000：COMMAND，写入/读回 GPIO 通道 1 输出。
    [7:0]  待发送字节；请求被接受时快照，之后写入不影响本次传输。
    [8]    START，上升沿触发；每次请求先写 0，再写 1，最后回 0。
    [9]    OUTPUT_ENABLE，1 请求使能；首次完整操作结束前仍保持高阻。
    [10]   SOFT_RESET，高电平期间复位单片驱动、计数及错误标记。
    [31:11] 保留，写 0。
  0x41200008：STATUS，GPIO 通道 2 输入。
    [0]    READY，空闲且可接收请求。
    [1]    BUSY，含复位初始化等待。
    [2]    VALID，复位后至少完成过一次锁存与恢复。
    [3]    OUTPUT_ENABLED，当前 OE 已拉低。
    [4]    REJECTED，忙时收到 START 的粘滞标记，复位清除。
    [7:5]  保留，读 0。
    [15:8] 最近发出 STCP 的字节镜像；VALID=0 时不用于确认输出。
    [31:16] 完成计数，模 65536；在锁存与恢复结束后递增。
  GPIO 输出/输入方向已在 IP 固定，无需另写 TRI 方向寄存器。
  完成计数与字节镜像表示 FPGA 执行动作，不表示实物输出回读。

  示例：在 PS/时钟/FPGA 均已初始化后，先等待 READY，记下完成计数，
    向 COMMAND 写 0x000002A5（数据 A5、OE 请求、START=0）；
    再写 0x000003A5（START=1），最后写 0x000002A5（START=0）；
    带超时轮询完成计数增加，并检查 READY、VALID、REJECTED。
  软复位：写 0x00000400，再写 0；等待 READY，再重新发送初值。
  START 穿过软复位一直为高不会生成新请求；重新请求须先拉低再拉高。

重建与验证（Vivado 2020.2）
  在本目录运行；若 vivado 未加入 PATH，使用安装目录下 bin/vivado。
  1. vivado -mode batch -source scripts/create_project.tcl
     创建 ris_ctrl_unit.xpr、校验 BD 并生成 IP；已存在工程时拒绝覆盖。
  2. tests/run_rtl.sh
     可用 RIS_VIVADO_BIN 指定包含 xvlog/xelab/xsim 的目录。
     HALF=1 和 5 分别运行：256 种字节、50 片行为模型、位序与脉冲时序、
     忙时请求、数据快照、START 持续高、OE、移位中/锁存中软复位及外部复位。
  3. vivado -mode batch -source scripts/check_synthesis.tcl
     综合完整 PS+GPIO+RTL 顶层，检查 72 脚电平/约束、黑盒及严重 DRC。
     报告在 reports/，综合 checkpoint 在 build/synthesis/。
  当前不包含 Vitis 应用、布局布线、bitstream 或板卡下载步骤。
  归档中的 PS/PL 图案缓存、帧格式、容量与双板同步仍待后续确定。
