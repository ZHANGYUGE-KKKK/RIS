ZC706 FMC LPC 新 RIS 驱动子板：原理图熟悉记录
日期：2026-10-20（Asia/Shanghai）

依据与范围
  已逐页阅读并放大查看 SCH_Schematic1_2026-10-20.pdf，共4页。
  文件实际位置：zynq/zc706/SCH_Schematic1_2026-10-20.pdf。
  用户确认该PDF是明天实物对应的最终版；已确认PCB上的RIS_Q223链路接通，该项关闭。
  载板依据：zynq/zc706/ZC706_Rev2_0.pdf，第4/5页FPGA Bank、第28页FMC LPC。
  本次仅做PDF接口审阅与映射记录，没有改动现有RTL、XDC、固件或下载板卡。
  fmc_drive_board/内的旧资料是较早版本，不用其中18片芯片的旧连接替代本PDF。

四页内容
  第1页：DC1外部电源输入、Q1/U1电源前级、U2/U3降压、1.5V电池接口及去耦。
  第2页：U4..U53共50片74LVC8T595PWJ，产生RIS_Q001..RIS_Q400。
  第3页：U55，ASP-134604-01，FMC LPC的C/D/G/H四列连接定义。
  第4页：FPC1..FPC10，每个接口40路RIS输出，并插入接地脚。

数据和时钟组织
  DATA_U01..DATA_U50分别连接U4..U53的DS；DATA_U01并非电源芯片U1。
  每片芯片独立接收8位串行数据；Q7S标为不连接，没有50片串接的移位链。
  每5片一组，共享SHIFT_CLKg和LATCH_CLKg，g=1..10。
  第g组对应DATA_U[5g-4]..DATA_U[5g]、RIS_Q[40g-39]..RIS_Q[40g]及FPCg。
  例如第1组为U4..U8、DATA_U01..U05、Q001..Q040，接FPC1。
  第10组为U49..U53、DATA_U46..U50、Q361..Q400，接FPC10。
  公共MR_N和OE_SAFE_N连接全部50片；未见Qn物理回读或PWR_READY反馈。
  全板接口共72个FPGA输出：50数据+10移位时钟+10锁存时钟+2公共控制。

与ZC706的连接
  新板插J5 LPC；FMCOMMS3继续位于J37 HPC。
  信号占用全部68个LA触点，另使用2对CLK_M2C触点承载4路普通数据。
  DATA_U13=G02=CLK1_M2C_P=AC28；DATA_U14=G03=CLK1_M2C_N=AD28。
  DATA_U15=H04=CLK0_M2C_P=AG17；DATA_U16=H05=CLK0_M2C_N=AG16。
  上述CLK_M2C名称不表示新板在输出采样时钟；此图将这些脚接到DS输入。
  载板原理图显示这些触点直达FPGA普通MRCC I/O；后续需按单端LVCMOS25输出约束。
  MR_N=H31=FMC_LPC_LA28_P=AD25。
  OE_SAFE_N=H32=FMC_LPC_LA28_N=AE26。
  共72个接点和72个FPGA封装脚一一对应，无重复；跨HR Bank10/12。
  完整表见signal_pin_mapping.csv；10组时钟/芯片/FPC关系见group_mapping.csv。
  CSV中的proposed_iostandard是后续适配建议，并非已经改写工程约束。

与当前25路RIS接口的关系
  现工程zc706_ris_lpc.xdc将out_1_1_0..out_5_5_0绑定到LA00..LA12部分引脚。
  新板同一批接点已经分配为不同DATA/时钟等信号，因此原25路驱动不能直接控制新板。
  例：旧out_1_1_0所在G06现在是DATA_U17，旧out_1_3_0所在D08现在是SHIFT_CLK10。
  后续需要新增/适配PL移位锁存逻辑、72脚XDC和软件帧接口，不能仅放宽25位GPIO掩码。
  现有AD9361 config915、采样与DDR/网络导出功能可作为后续适配的既有边界。

电源和电平
  DC1网络标为5V_IN，经Q1/U1前级到5V_SYS，再由U2/U3生成VDD_2V5/VDD_3V3。
  U2/U3型号TMI3253SH；TP1=5V_SYS，TP2=VDD_2V5，TP3=VDD_3V3。
  U1没有显示型号，不能仅据5V_IN网络名推断全部输入容限或保护行为；以BOM为准。
  50片595的VCC(A)接本地VDD_2V5，控制输入为2.5V侧；VCC(B)接VDD_3V3，Qn为3.3V侧。
  FMC的VADJ/3P3V/12P0V与本地VDD_2V5/VDD_3V3/5V_SYS是不同网络名，图中未见互连。
  不能因FMC已上电就认定本地595电源已就绪；初次接板应在TP1/2/3核对实际电压。
  B1..B6画为并联的单节电池座，形成独立1V5_BAT并接FPC11，不是六节串联的9V源。
  串联输出电阻在图中有位号但未显示阻值，装配值需看BOM/实物。

74LVC8T595操作要点（已核对Nexperia官方数据手册）
  控制输入与Q7S参考VCC(A)，Qn参考VCC(B)。OE低有效，高电平使Qn高阻。
  SHCP上升沿移入DS，STCP上升沿把移位内容转到输出锁存器。
  MR低电平只清移位寄存器，不会直接清已锁存的Qn；清零后还需一次STCP锁存。
  如果字节bit0期望接Q0，移位顺序应为bit7先发、bit0最后发，共8个SHCP上升沿。
  50路DS可并行移位；全板每次刷新是各芯片8位，不是沿一条链移400位。
  更新时可让锁存输出保持，完成8位移位后再发STCP；各组可单独更新或一起锁存。
  推荐启动顺序：OE=1禁能、SHIFT/LATCH=0、MR清零、释放MR、写入已知初值、STCP锁存、OE=0使能。
  时钟频率和边沿约束需要结合PCB/线缆实测，不能直接用器件手册的极限频率作为板级承诺。
  参考：https://assets.nexperia.com/documents/data-sheet/74LVC8T595.pdf

实物确认与待核对
  1. RIS_Q223：用户于2026-10-20确认PCB上已连接，关闭此项，不再列为待核对问题。
     PDF的U31 Q6/R277处未显示网标属于审阅时记录的标注疑点，不再作为驱动设计障碍。
  2. OE_SAFE_N只是此PDF中的网名，直接由FMC H32送到全部OE输入；未见额外上拉、
     电源监测或门控联锁。FPGA未配置/任一侧未上电时的实际默认电平需核对。
     后续逻辑必须显式安排禁能与初始化过程，不能因SAFE命名就认定有独立硬件保护。
  3. 该图未给RIS编号与实际单元行列/高低电平功能的对应关系，不能先假设空间排列。
  4. 仅凭PDF不能验证PCB连接、器件焊接、实际供电、输出负载能力和时钟余量。

下一步适配所需信息已整理
  先核电源/OE/MR，再逐组做全0/全1/走1输出观察。
  如开始改工程，以本目录72路映射表为依据，准备400位控制帧和10组更新时序。
  由于Q7S未回连，软件发帧成功只能证明命令执行，不能单独证明400路实物输出正确。
  verification.json记录源PDF哈希及现有固件/硬件未改动的核对结果。
