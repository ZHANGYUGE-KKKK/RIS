RIS 控制单元：AXI4 / 50片74LVC8T595
更新日期：2026-10-23（Asia/Shanghai）

当前入口
  高速全0/全1版（2026-10-26）：控制面板支持数值输入及Hz/k/M/G单位，范围1 Hz～5 MHz。
    5 MHz对应每100 ns翻转。300 MHz硬件时基、100 MHz八脉冲移位、50片并行。
    专用工程vivado_fast / vitis_fast；配套包export_network_fast；旧包保留。
    FASTHZ/FASTTICKS启动（旧FAST 1/3/5兼容），STOP保持；详见host/README.txt“高速全0 / 全1方波”。
  单窗口GUI：host/ris_gui.py，通过“界面”菜单或页签选择控制面板/FPC—RIS映射。
    第三个页面“图案与切换”支持20×20编辑、整行/整列0或1、持久图案库和可配置播放列表。
    支持手动逐项切换、顺序一次/循环/往返/随机，以及每项独立停留时间；使用已有FRAME协议。
    控制面板已集成RIS拓扑图：点击或输入行列选择单元，支持单位置高/置低与单路核线。
    host/ris_gui.py --mapping启动时直接选中映射页，两页共享连接与状态。
    20×20阵列、上下各5个4列×10行接口；绑定后按已确认的背插小板接线自动生成40路。
    行向已按实测修正：上区01↔10、下区11↔20，列号不变；旧版接线表JSON载入时自动迁移。
    点击单元查看595位号/Q/物理脚号、FPC针号及小板排针；接线表与实测状态分别显示。
    支持JSON v1/v2、完整路径CSV、恢复草稿和撤销，说明见host/README.txt。
  网络GUI入口：host/ris_gui.py，板卡192.168.1.11:7060（lwIP TCP）。
    已下载网络应用，实际按钮和网络控制验证见reports/network/。
    使用说明、万用表测量与网络协议见host/README.txt。
    export_network/是当前网络版；export/保留先前纯串口版。
  首板工程：vivado_board/ris_ctrl_unit.xpr（16帧/1KiB缓存，仍控制全部50片）。
  完整缓存工程：vivado_axi/ris_ctrl_unit.xpr（256帧/16KiB）。
  两个配置引用同一套rtl/源码；容量可读BASE+0x08C确认。
  总控制RTL：rtl/ris_controller_axi.v
  旧单片工程：vivado/ris_ctrl_unit.xpr；原说明保存在 README_SINGLE_595.txt。
  历史讨论：DISCUSSION_20261020.txt；本轮用户已授权按状态/指令规格实现。
  板卡：ZC706，xc7z045ffg900-2；100 MHz FCLK0；RIS子板接FMC LPC。
  PS基础配置继续使用本目录 constraints/zc706_ps_preset.tcl。
  首板已完成2026-10-22 JTAG下载及实际USB串口验证；当前保持全低、OE使能。
  验收记录：reports/board_v1/verification.txt；可直接下载的文件位于export/。
  256帧配置仅综合/RTL仿真通过，尚未完成路由验收，不能与首板包混用。

模块组成
  ris_controller_axi.v：Vivado可引用的AXI4外设顶层。
  ris_axi4_slave.v：独立读写通道、突发传输、ID和响应保持、错误响应。
  ris_controller_core.sv：命令队列、完成队列、缓存所有权、模式与调度状态机。
  ris_frame_ram.v：无复位、按字节写入的BRAM，两份镜像提供独立同步读口。
    默认逻辑容量16KiB，首板配置1KiB；CPU与播放读口各一份存储。
    AXI读自动等待有效数据。
  ris_595_array.v：统一节拍、10组SHCP/STCP、generate例化50个ris_595_byte。
  ris_595_byte.v：每片8位数据快照、MSB先发、锁存命令镜像。
  子板50路DATA、10路SHCP、10路STCP、全局MR/OE，共72路LVCMOS25。
  单片修改时重新发送同组其他4片的旧字节；其他组的时钟保持低。
  旧单片bring-up模块保留作参考，新版不会将其余49片强制清零。

AXI4接口约定
  32位地址、32位数据，默认12位ID。基址由BD分配为0x41200000，空间64 KiB。
  偏移均为BASE+offset。读写各允许一个未完成突发，读写彼此独立。
  支持对齐32位FIXED/INCR传输；最长256拍；数据窗口允许突发。
  不支持窄传输、WRAP、独占访问或跨4KiB边界；返回SLVERR。
  控制寄存器只允许单拍访问。未知地址返回DECERR。
  支持WSTRB；COMMIT和RESULT_POP必须全字写1。
  W可早于AW出现，硬件等待地址后接收。B/R在READY为低时保持有效和稳定。
  WLAST与AWLEN不符时返回SLVERR；不执行该拍控制副作用。
  软复位仅复位功能引擎，AXI接口及已产生的完成记录不被复位。

工作模式 MODE
  0 HOLD：静态保持，接受手动更新。
  1 SEQUENCE：播放已提交序列；支持有限序列或显式循环。
  2 STREAM：按节拍消费持续提交的数据，空闲时可继续收数。
  动态掩码仅覆盖选中的芯片；其余芯片保留当前锁存镜像。
  OE禁能独立于模式；禁能时内部仍可继续播放，Q对外为高阻。

主运行状态 STATUS[2:0]
  0 RESET：功能复位与取消未完成命令。
  1 INIT：MR低保持/释放恢复，50片移入并锁存零，OE仍禁能。
  2 IDLE：无自动播放；可以执行手动更新，发送器可短暂忙碌。
  3 PREFILL：STREAM启动后等待预收阈值和完整首帧，保持旧图案。
  4 RUN：自动播放；首帧先预取，后续STCP间隔为FRAME_PERIOD个时钟。
  5 PAUSED：保持图案与下一帧位置。
  6 FINISH_FRAME：当前完整帧收尾后执行控制屏障/配置切换。
  7 ERROR：播放停止；欠载保持最后图案；内部时序异常禁能OE。
  非循环序列正常结束后进入IDLE，MODE仍为SEQUENCE。

发送状态 TX_STATE
  0 IDLE；1 SHIFT_LOW；2 SHIFT_HIGH；3 LATCH_WAIT；4 LATCH_HIGH；5 RECOVER。
  SNAPSHOT在COMMIT接收时完成，LOAD与start同拍；恢复结束产生done脉冲。
  每次8个SHCP上升沿，bit7先发、bit0最后发；STCP在8位完整后发生。
  所有内部逻辑都使用FCLK0，不建立50个独立时钟域。

寄存器偏移（32位，小端）
  0x000 R   ID，固定0x52495332（RIS2）
  0x004 R   STATUS：
              [2:0]主状态 [4:3]MODE [5]TX_BUSY [6]INITIALIZED
              [7]OUTPUT_ENABLED [8]命令队列满 [9]完成队列非空
              [10]下一帧预取完成 [11]存在执行中的普通命令
  0x008 R   TX_STATE
  0x00C R   ERROR_FLAGS：[0]欠载 [1]发送超期 [2]功能写入/命令被拒绝
                         [4]内部时序状态异常
  0x010 RW  OP_FLAGS：[7:0]OPCODE [9:8]FLAGS，其余必须0
  0x014 RW  CMD_ID，未完成期间不可复用
  0x018 RW  ARG0
  0x01C RW  ARG1
  0x020 RW  CHIP_MASK_LO，对应芯片索引0..31
  0x024 RW  CHIP_MASK_HI，低18位对应索引32..49，高14位必须0
  0x028 W   COMMIT，全字写1；接收成功才更新LAST_ACCEPTED_ID
  0x02C R   LAST_ACCEPTED_ID
  0x030 R   RESULT_ID，完成队列队首；为空读0
  0x034 R   RESULT_CODE：1 DONE，2 REJECTED，3 CANCELLED，4 FAILED；为空读0
  0x038 W   RESULT_POP，全字写1弹出一条完成记录；空队列返回SLVERR
  0x03C R   QUEUE_LEVEL：[7:0]普通命令数 [15:8]完成记录数 [23:16]流式块数
  0x040 RW  配置暂存：FRAME_PERIOD，FCLK0周期数，默认1000
  0x044 RW  配置暂存：DYNAMIC_MASK_LO，默认0xFFFFFFFF
  0x048 RW  配置暂存：DYNAMIC_MASK_HI，默认0x0003FFFF
  0x04C RW  配置暂存：SEQ_START_SLOT，默认0
  0x050 RW  配置暂存：SEQ_FRAME_COUNT，默认0
  0x054 RW  配置暂存：LOOP_ENABLE，只允许0或1
  0x058 RW  配置暂存：PREFILL_FRAMES，默认1
  0x05C RW  配置暂存：SHCP_HALF_CYCLES，默认5
  0x060 RW  配置暂存：LATCH_GUARD_CYCLES，默认5
  0x064 RW  配置暂存：LATCH_HIGH_CYCLES，默认5
  0x068 RW  配置暂存：RECOVERY_CYCLES，默认5
  0x06C R   完成的图案更新计数低32位（不含初始化，包含手动和动态更新）
  0x070 R   完成的图案更新计数高32位
  0x074 R   最近出错的预计全局输出编号低32位
  0x078 R   最近出错的预计全局输出编号高32位
  0x07C R   当前生效FRAME_PERIOD
  0x080 R   下一序列帧索引（发送调度位置，不代表已锁存完成）
  0x084 R   执行中的普通CMD_ID，空闲0
  0x088 R   尚未发起发送的STREAM帧数，不含发送中的帧
  0x08C R   FRAME_SLOTS，默认256，首板配置16
  0x090 R   已完成的软复位代数
  0x094 R   当前生效DYNAMIC_MASK_LO
  0x098 R   当前生效DYNAMIC_MASK_HI
  0x100..0x13F RW 手动图案暂存区，50字节有效、14字节保留读0
  0x140..0x17F R  已发出锁存操作的50字节镜像，14字节保留读0
  0x1000起 RW 图案RAM，默认256槽×64字节=16KiB，范围到0x4FFF；
              首板16槽×64字节=1KiB，范围到0x13FF

图案编号与提交
  字节0对应DATA_U01/实物U4，字节49对应DATA_U50/实物U53。
  每字节bit0..7对应该片Q0..7。软件暂不假定RIS单元的空间行列排列。
  每个RAM槽64B对齐；前50B必须逐字节写全，尾14B保留。
  PUBLISH_BLOCK接收时立即检查并锁定整个范围，禁止覆盖已提交槽。
  SEQUENCE槽可重复读取，直到FLUSH/RESET释放。
  STREAM槽在该帧完整锁存和恢复结束后释放；重用前必须重新写满50B。
  大批图案通过AXI突发写入、按块提交，不需要每帧一个命令或中断。
  缓存是PL片上存储（首板1KiB，默认16KiB），不含DDR读DMA或上位机网络程序。

全部命令
  0x01 APPLY：使用CHIP_MASK和手动图案快照。
       FLAGS=0：仅IDLE/PAUSED下更新，保持原模式/暂停状态。
       FLAGS=1：结束当前帧，切HOLD，更新并保持。
       FLAGS=2：仅RUN；占用下一个可调度的正常时隙，随后继续原播放。
                原序列/流式帧不被跳过，后续帧顺延一个时隙。
  0x02 CLEAR_ALL：结束当前帧，切HOLD，全50片锁存0；不改变OE请求。
  0x10 SET_MODE：ARG0=0/1/2；完成当前帧后切换，进入IDLE，不自动启动。
  0x11 CONFIG_APPLY：封存并校验全部配置暂存值。
       RUN/PREFILL时只允许改变周期和动态掩码；其余值必须与当前一致。
       IDLE/PAUSED时可以修改其余配置；改变序列参数会重建预取位置。
       运行中配置改变重新建立节拍起点，不保证跨配置边界的旧周期连续性。
       参数最低要求：各时序值1..65535，掩码非0，范围不超RAM容量，
       FRAME_PERIOD >= max(28, 16*HALF + GUARD + HIGH + RECOVERY + 8)。
       28周期下限覆盖同步BRAM的整帧预取与交接。
  0x20 START：仅IDLE且MODE为SEQUENCE/STREAM；SEQUENCE范围必须已发布。
       SEQUENCE从配置起点开始；STREAM从尚未消费的块队首开始。
  0x21 PAUSE：仅RUN/PREFILL；当前完整帧结束后暂停，保留进度。
       有限序列恰好结束时直接进入IDLE，不留下无法恢复的PAUSED状态。
  0x22 RESUME：仅PAUSED；继续下一帧，重新建立节拍起点。
  0x23 STOP_HOLD：当前完整帧结束后停止，保持输出；保留尚未播放数据。
       SEQUENCE下一次START回起点；STREAM下一次START继续尚未消费的数据。
  0x30 OUTPUT_ENABLE：初始化成功后允许输出；不切换模式/图案。
  0x31 OUTPUT_DISABLE：COMMIT接收时禁能OE，不停止播放。
  0x40 PUBLISH_BLOCK：ARG0=起始槽，ARG1=连续帧数；FLAGS=0发布SEQUENCE，
       FLAGS=1发布STREAM。提交完成即生成DONE，不等待实际播放。
  0x41 FLUSH_DATA：仅IDLE/PAUSED且发送器空闲时清除发布数据和预取。
       提交到执行期间暂时拒绝RAM写入/发布，避免新旧批次混用。
  0x50 CLEAR_ERROR：发送器空闲时清错误；ERROR回IDLE，不自动恢复播放。
       内部时序故障必须SOFT_RESET，不能仅清标志继续。
  0x7F SOFT_RESET：立即禁能OE并中止发送；取消普通命令/控制屏障，
       清发布数据和计数，恢复默认配置，重新锁存全零；结束后返回DONE。
       已经进入完成队列的记录保留。外部AXI复位则清全部队列。
  仅APPLY/PUBLISH_BLOCK允许非零FLAGS；其余命令FLAGS必须0。

优先级与结果
  SOFT_RESET > OUTPUT_DISABLE > SET_MODE/PAUSE/STOP_HOLD > 普通命令 > 动态播放。
  SET_MODE/PAUSE/STOP_HOLD作为控制屏障，取消未开始的普通命令并返回CANCELLED；
  正在发送的手动更新完整收尾并返回DONE。软复位则中止它并返回CANCELLED。
  时序内部非法状态禁能OE，排队任务返回FAILED，需软复位重新初始化。
  普通命令默认8条、完成记录32条、STREAM块描述符16条。
  完成队列为已接收命令预留额度，普通命令保留额外紧急额度。
  资源满、重复未完成ID、非法提交格式/缓存发布参数等返回SLVERR，
  COMMIT不入队、不改变图案。配置值在执行CONFIG_APPLY时校验，失败返回REJECTED。
  已排队命令因执行时状态不匹配而拒绝时，返回带CMD_ID的REJECTED。
  完成记录可能按优先级返回，上位机应按CMD_ID匹配，不能只看最后一个ID。
  写成功/接收成功不等于锁存完成。图案类DONE只在锁存及恢复完成后产生。
  已锁存镜像是命令镜像，子板没有物理Q回读。跨多拍读取镜像时，应比较
  读取前后的完成计数并重试，或先暂停播放，再读取稳定镜像。

最小静态控制顺序
  等STATUS.INITIALIZED=1且STATE=IDLE。
  向0x100写50字节图案；设置MASK、OP_FLAGS=0x01、唯一CMD_ID。
  向COMMIT全字写1；轮询完成队列，匹配CMD_ID及DONE，然后RESULT_POP。
  显式提交OUTPUT_ENABLE。以后仅更新选中片时，其余片保持原输出。
  单片索引i：MASK=1<<i；全板MASK_LO=0xFFFFFFFF，MASK_HI=0x0003FFFF。

工程与验证
  16帧首板工程已补齐标准Project Mode运行：synth_1和impl_1，
    Vivado底部Design Runs可见完成记录，Open Implemented Design可查看布局布线。
    最终时序/资源/DRC报告：reports/board16_project/；只运行到route_design。
    在正确工程的Tcl Console运行source scripts/gui_board_results.tcl，
      可启动标准运行并自动打开已完成的设计和报告。
    只读核查已有运行：vivado -mode batch -source scripts/check_project_results.tcl。
  创建新版：vivado -mode batch -source scripts/create_project.tcl
  已有工程拒绝覆盖；新版放vivado_axi，原单片工程留在vivado。
  仿真新版：tests/run_axi_rtl.sh；可设置RIS_VIVADO_BIN指定工具bin目录。
  单片回归：tests/run_rtl.sh。
  综合新版：vivado -mode batch -source scripts/check_synthesis.tcl
  综合脚本会加入新增源码、刷新模块引用并重新生成BD输出。
  默认使用RuntimeOptimized做RTL综合检查并输出完整时序报告；
  可设置RIS_SYNTH_DIRECTIVE=Default使用默认时序优化。综合成功不代表时序收敛。
  测试包含AXI独立握手/响应背压/突发/WSTRB/非法访问，50片和10组模型，
  命令快照、所有工作模式、暂停恢复、插帧、发布保护、欠载、队列饱和、
  取消与复位抢占、时序内部故障，以及100MHz下1MHz整帧节拍仿真。
  默认时序HALF=5；1MHz仿真使用HALF/GUARD/HIGH/RECOVERY=4、PERIOD=100。
  10月21日初版验证归档见reports/axi_verification.txt；首板路由报告见reports/board16。
  当前综合报告为axi_synthesis_*.rpt。
  实物边沿/锁存时序与RIS实际响应、网络持续供数仍需后续验证。
  首个上板版本的构建/下载入口见下节；硬件和串口日志位于reports/board_v1。

首个上板版本：400路全高/全低
  缓存配置为16帧/1KiB；50片、400输出、命令接口及三种RTL模式均保留。
  缩减缓存用于先完成基础上板；256帧版本的路由验收单独记录。
  software/ris_controller.c：同步命令驱动，匹配CMD_ID和DONE，有超时；
    更新全50字节后检查完成计数及命令镜像，不把镜像当作外部Q回读。
  software/main.c：UART1 115200 8N1交互应用；启动锁存全零，再使能输出。
    0：400路全低并保持；1：400路全高并保持；b：每1秒切换一次高/低；
    s：打印状态；d：禁能输出（高阻）；e：使能输出；h：帮助。
    0/1会停止自动切换并使能输出。全低是主动输出0，不是OE禁能。
    高/低只表示电平，不预设RIS射频单元的开关极性。
  首板使用100MHz FCLK0，SHCP_HALF/GUARD/LATCH/RECOVERY均设50周期；
    SHCP为1MHz，各保护/锁存/恢复阶段500ns，静态更新后无重复时钟。
  本版不加入FPC检测、外部Q回读、网络收数或DDR/DMA播放软件。

  首板创建与构建（已有工程不重复创建）：
    RIS_PROJECT_DIR="$PWD/vivado_board" RIS_FRAME_SLOTS=16 \
      vivado -mode batch -source scripts/create_project.tcl
    vivado -mode batch -source scripts/build_board16.tcl
    RIS_XSA="$PWD/build/board16_package/export/ris_ctrl_unit.xsa" \
      xsct scripts/build_application.tcl
    cp export/ris_all_io.elf build/board16_package/export/
    python3 scripts/finalize_export.py build/board16_package
    RIS_EXPORT_DIR="$PWD/build/board16_package/export" xsct scripts/program_board.tcl
    RIS_EXPORT_DIR="$PWD/build/board16_package/export" xsct scripts/verify_board.tcl
    /usr/bin/python3 tests/verify_uart.py
  verify_uart.py实际打开USB串口，测试前需释放CuteCom等程序的串口连接；
    测试结束保持全低。日常操作可直接在CuteCom中发送0/1/b/s/d/e。
  若仅需重做首板导出，运行scripts/export_board16.tcl，保留原路由DCP。

  完整256帧配置的构建入口：
    vivado -mode batch -source scripts/check_synthesis.tcl
    vivado -mode batch -source scripts/implement_board.tcl
    xsct scripts/build_application.tcl
    xsct scripts/program_board.tcl
    xsct scripts/verify_board.tcl
  综合/实现与软件构建只生成文件，program_board.tcl才复位和下载板卡。
  implement_board.tcl在时序或严重DRC失败时拒绝导出；不添加时序豁免。
  时序实现改进：数据窗口独立写使能、分组并行缓存检查、同步BRAM图案存储。
    修改不改变寄存器地址、命令语义或256帧容量；AXI读等待由硬件处理。
  export/包含ris_ctrl_unit.bit、ris_ctrl_unit.xsa、ris_all_io.elf、
    ps7_init.tcl及manifest.json；BIT与XSA内嵌配置必须一致。
  默认已确认的RIS JTAG序列号为210299995170；更换板卡时设置RIS_JTAG_SERIAL。
    RIS_HW_SERVER可指定hw_server地址，默认tcp:127.0.0.1:3121。
  verify_board.tcl通过运行中的ARM应用执行20次全低/全高更新和OE切换，
    验证AXI命令、50片镜像和完成计数；结束保持全低且OE使能。
    单独执行 xsct scripts/verify_board.tcl 1 或 0，可经JTAG设全高或全低；
    同样支持b/s/d/e，即使串口被CuteCom占用也可使用。
  首板最终路由时序见reports/board16/，实际上板日志见reports/board_v1/；
    日志通过才代表已验收。没有Q7S回线，不把软件检查当作400路电平实测。

控制粒度与时序优化
  当前并非每片一个状态机：50个ris_595_byte只保存和移出各自的8位数据，
    共用一个ris_595_array发送状态机；每5片共用SHCP/STCP，匹配现有接线。
  每个数据单元24个触发器，合计1200；256槽的逐字节写入标记则有12800位。
    只把5个模块封装为一个模块，并不会减少这些存储位或自动切断组合路径。
  若按5片建立控制单元，应保持5路独立DATA，重点增加组内控制寄存、
    降低全局扇出并改善物理布局；不改接为Q7S级联，当前板上Q7S未连接。
  大缓存的后续重点是缓存标记、宽命令快照队列及组合校验/调度路径。
    应按实际关键路径加入流水或分拍校验，再依据完整路由报告判断收益。
