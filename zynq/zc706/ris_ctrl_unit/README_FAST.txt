RIS可编程全0/全1方波版（2026-10-26）

使用
  Python入口仍是host/ris_gui.py。控制面板“全0 / 全1 · FPGA高速方波”区域
  输入数值（支持小数），点Hz / k / M / G选择单位，再点“启动 / 应用频率”或回车。
  Hz=赫兹，k=千赫兹，M=兆赫兹，G=吉赫兹；按钮只编辑单位，不发送命令。
  支持1 Hz～5 MHz，例如125 k、2.4 M、0.005 G。超出范围会提示，保留当前输出。
  预览显示请求值、可生成值和偏差，状态栏显示板端实际分频读数。
  可生成频率=150000000/N Hz，N为30～150000000的整数；不能保证任意实数精确实现。
  半周期按最接近的整数时钟数取整（恰好半格向上）；2.4 MHz对应N=63，实际约2.38095238 MHz。
  占空比始终50%，半周期步进3.333333 ns，不交替分频来凑平均值。
  点“停止方波 / 保持”完成当前锁存脉冲后保持最后电平（低频也立即停止）；
  需要全低则点“400路全低 · 0”。旧的ms输入框属于慢速BLINK，不用于MHz模式。
  所有频率均指全0→全1→全0完整周期，50%占空比。
  5 MHz在595 Q输出端应测到周期200 ns、高/低各100 ns；实物以示波器为准。

配套工程和下载
  Vivado：vivado_fast/ris_ctrl_unit.xpr。
  Vitis工作区：vitis_fast；应用ris_fast_network。
  GUI启动配置：vitis_fast/ris_fast_network/_ide/launch/Debugger_ris_fast_network-Default.launch。
  可下载包：export_network_fast/ris_ctrl_unit.bit + ris_all_io.elf + ps7_init.tcl。
  旧版export_network/和vivado_board/vitis_network保留；它们不支持高速模式。
  必须使用高速版BIT与ELF配对，不能仅替换ELF。JTAG下载掉电后失效。

设计
  100 MHz AXI/普通控制逻辑保持原接口。
  MMCM从100 MHz产生300 MHz；完整周期整数分频，避免3 MHz的分数周期抖动。
  每半周期50片并行各发送8位；SHCP采用ODDR输出100 MHz八脉冲突发，
  脉冲高/低均为5 ns，然后锁存。高速运行期间OE保持使能，主动驱动0和1。
  所有高速数据、SHCP、STCP经一致的流水级和最终IOB ODDR输出。
  适用范围是400路全0/全1；普通任意图案的Python软件播放仍使用原停留时间规则。

TCP接口（同一个192.168.1.11:7060连接）
  <id> FAST 1\n / <id> FAST 3\n / <id> FAST 5\n：启动对应完整周期MHz模式。
  <id> STOP\n：停止并保持。
  <id> FASTHZ 2400000\n：以整数Hz请求频率，硬件按整数分频量化。
  <id> FASTTICKS 63\n：精确指定半周期的300 MHz时钟数，GUI使用此指令。
  STATUS新增fast_variable、fast_ticks；运行时实际Hz=150000000/fast_ticks，停止时ticks=0。
  fast_mhz保留兼容字段，仅精确1/3/5 MHz返回对应数值，其余返回0；判断运行须用fast_ticks。
  fast_supported和fast_edges仍保留；fast_edges是32位翻转计数，会回绕。
  高速期间image是普通引擎的镜像，不是瞬时电平回读；GUI已单独显示动态状态。
  无效频率不改变当前模式；ALL/BIT/CHIP/GROUP/FRAME/BLINK、OE 0和断线会停止高速。
  停止时先保留高速输出，再对齐普通引擎镜像，最后交还引脚，避免额外锁存。

C接口（software/ris_controller.h）
  ris_fast_start(dev, mhz)：mhz只允许1/3/5；
  ris_fast_stop(dev)：停止并保持，恢复普通控制；
  ris_fast_start_hz(dev, hz)：1～5000000整数Hz请求，自动分频取整；
  ris_fast_start_ticks(dev, n)：30～150000000半周期时钟，适合上位机小数输入；
  ris_fast_ticks(dev)：运行时返回实际半周期时钟数，静态返回0；
  ris_fast_mhz(dev)：兼容1/3/5 MHz字段，其他频率或静态返回0。

MMIO扩展（相对0x41200000）
  A0 R  FST2设备标识0x46535432。
  A4 W  控制：1/3/5为旧MHz预设；9以C0分频启动；0停止并保留引脚；8交还普通引擎。
        原始写寄存器需遵循“停止→按最终电平对齐普通引擎→释放”握手，优先使用C接口。
  A8 R  bit0时钟锁定、bit1高速持有引脚、bit2运行、bit3最后锁存值、bit4命令待确认。
  AC R  旧预设运行MHz；自定义模式或静态0。
  B0 R  32位翻转计数（Gray跨域同步后解码）。
  B4 R  预设位图0x2A；B8 R 引擎300 MHz；BC R SHCP突发100 MHz。
  C0 RW 半周期时钟暂存值；仅停止且无挂起命令时可写，范围30～150000000。
  C4 R  当前运行半周期时钟数；静态0。C8 R 最小值30；CC R 最大值150000000。
  设置C0不会启动输出；写A4=9时快照并跨域握手，运行期间分频不可被改写。

验证记录
  原1/3/5 MHz版本记录保留在reports/arbitrary_frequency/before/reports/fast_toggle/。
  本版记录位于reports/arbitrary_frequency/，包括仿真、协议、Python、时序及板端检查。
  仿真和内部计数不能代替595 Q、FPC末端电压和RIS射频响应的示波器验收；用户随后测量。
