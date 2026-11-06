# 20 kHz、25%占空比的595输出保持核查

本次只增加本目录内的诊断仿真和记录；未修改控制台、固件、RTL、约束、BIT或Flash，未操作板卡。

## 当前判断

用户观察：统一MT和QAM均异常；直接测595 Q输出，断开后级负载仍异常；高电平出现后缓慢下降。

未发现能够在数字仿真中复现该现象的移位/锁存控制错误。尚不能判定实物根因，也不能用数字仿真排除引脚毛刺、供电、输出高阻、探头或示波器设置问题。

## 源码对比

- 活跃工程的18项RTL/约束源码SHA256全部匹配20261105_qam64 Flash配套build_manifest.json。
- 与原工程 `FPGA/zynq/zc706/ris_ctrl_unit` 相比：`ris_mt_engine.v`、`ris_fast_engine.v`、`ris_595_array.v`、`ris_controller_core.sv`、`constraints/ris_fast.xdc`完全一致。
- 共用IO封装增加了QAM仲裁及输出选择；所有模式依旧使用寄存后的数据、SHCP、STCP和IOB ODDR输出。OE逻辑仍为 `normal_oe_n || !locked_sync[1]`，未用于PWM电平合成。
- MT的短相位计数器在30饱和，长保持由remaining计数；不会在12.5us/37.5us保持期间重复运行8位移位序列。QAM也使用饱和短相位计数器。
- 固件MT/QAM启动时使能输出，之后由硬件播放；STATUS协议分支只读取状态，不周期性改写OE。

## 针对性仿真

运行 `bash run.sh` 可重新生成VCD、边沿CSV和日志。使用现有Icarus及Vivado厂商ODDR/glbl模型；MMCM是功能模型，595是50片移位寄存器和存储寄存器行为模型。未加入板级延迟、模拟电压、供电及负载模型。

直接通过寄存器配置目标波形，经过真实的引擎、仲裁、流水线及ODDR。没有加载真实QAM码本，也没有执行ARM固件；本项用于检查输出时序与保持行为。

| 路径编号 | 路径 | 测试配置 | 结果 |
|---|---|---|---|
| 1 | 400路统一MT | 上位机实际编译结果：4段，循环入口2；高3750 tick、低11250 tick | PASS |
| 2 | QAM原时序 | 75 tick/片、200片/周期，高50片、低150片 | PASS |
| 3 | QAM边沿计时 | 周期15000 tick，高3750 tick、低11250 tick | PASS |

三条路径各检查9次锁存、50片/400个Q输出；高12.5us、低37.5us，周期50us。每组每次STCP前恰好8次SHCP，SHCP高/低均至少5ns；DS建立时间至少一个引擎时钟；无SHCP/STCP重叠、额外锁存或OE关闭。停止在全1之后继续检查50us，400路均保持高，且没有残余时钟。

数字仿真已通过，进程退出码0并输出 `SHIFT_HOLD_DIAGNOSTIC_PASS`。边沿记录见 `edges.csv`，数字波形见 `shift_hold.vcd`。时间步进有限精度使3750/11250 tick分别显示为12500.0025/37500.0075ns，属于仿真时钟模型舍入。

## 实物定位顺序

1. 同一示波器通道使用DC耦合、1MΩ输入，探头10×并匹配通道倍率；先接示波器校准方波，检查探头补偿。AC耦合或探头补偿不当都可能改变平台形状；20kHz时明显下垂不能未经测量就归因于普通低截止频率的AC耦合。
2. GUI总下发“全1保持”，观察是否仍下降；同时确认测的是Q0..Q7，并非Q7S串行输出。全1保持的结果可区分持续高电平异常与切换相关异常。
3. 若校准方波正常、Q输出确实下降，同步测同片595的Q、OE和供电，以芯片附近GND为参考。按项目74LVC8T595：OE脚18应持续低；VCC(B)脚1为Q端供电，VCC(A)脚20为控制侧供电，二者都应稳定。OE为高时Q会高阻，节点可能通过泄漏/探头输入逐渐放电。
4. STCP脚17应只在更新时出现锁存脉冲；20kHz/25%统一切换时每周期2次，间隔12.5us/37.5us。SHCP脚16每次更新有8个100MHz脉冲。低PWM频率不改变100MHz突发移位时钟。
5. 若OE、两路供电及测量链路均稳定，再查STCP实物毛刺、地参考、器件与焊接。此时再依据测量结果决定是否需要调整接口时序/驱动。

595的存储寄存器在STCP上升沿更新；在供电与OE正常、STCP无额外上升沿的条件下，DS或SHCP变化不会直接改变已锁存Q。数据错误通常表现为错误逻辑位或跳变，不能单独解释持续缓慢的电压下降。

参考：[Nexperia 74LVC8T595](https://assets.nexperia.com/documents/data-sheet/74LVC8T595.pdf)、[Keysight AC耦合说明](https://www.keysight.com/blogs/en/tech/bench/2018/10/18/when-to-use-ac-coupling-on-your-oscilloscope)、[Rohde & Schwarz探头补偿说明](https://www.rohde-schwarz.com/us/products/test-and-measurement/essentials-test-equipment/rs-essentials-digital-oscilloscopes/understanding-probe-compensation_254520.html)。
