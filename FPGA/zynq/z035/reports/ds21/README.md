# FMCOMMS3 DS21 检查

依据用户提供的ad-fmcomms3_reva.pdf第3页，DS21为电源LED：1P8V -> R205(237 ohm) -> DS21阳极A -> 阴极C -> GND。不是PLL/FRAME/BIST状态灯，也没有连接可编程GPIO；软件不能点亮或关闭该LED。

第4页：板上1P8V来自FMC 3P3V，经U301 ADP2164、L301及E301输出；U301 EN连接PG_FMC。此1P8V与FMC VADJ/VDD_INTERFACE是不同电源网络，不能仅凭VADJ设1.8V判断此电源正常。

15:19:37只读抓取现有硬件ILA成功，rx_clock_active_ref=1、rx_counter_ref在抓取窗口继续变化；当前AD9361仍有时钟活动。此前config915配置中ID/校准/PLL检查通过。这些证据不代替1P8V实测，也不能单凭LED暗判断整个AD9361未供电。

现有顶层未引出FMC SCL/SDA，BSP没有XIICPS配置，无法直接利用板上AD7291读取此电源。因此尚不能远程判定LED不亮的具体硬件原因，未修改软件或硬件设置。

建议万用表黑笔接子板GND，先量R205电源侧（或C316非接地端）应约1.8V，再量DS21阳极/阴极。电源侧偏低/为0时检查3P3V、PG_FMC、U301和L301/E301；电源侧正常而灯不亮时检查R205、LED焊接/极性/器件是否实际装配及LED本体。LED型号/正向压降没有在此页标注，不能仅从原理图确定亮度。

已通过异步问题请求用户提供R205电源侧与DS21阳极实测电压。待测量，结论保持未确认；不将LED现象归因于当前FRAME错误。

## 补充：载板使能和VADJ
已查看PZ7035-FH载板原理图第18页：FMC D1 PG_C2M/F_PG_C2M接FPGA AB17，并有R134 4.7k上拉到VDD_3V3。当前RTL/XDC未使用AB17；不能据此断言PG_C2M没有上拉或必须增加GPIO才能上电。按图PG_C2M应默认有上拉，使能电压仍需实测。载板VDD_FMC_ADJ通过R169/R170等0欧电阻与LDO支路硬件选择，图注明默认LA/HA/HB=1.8V，不是Vivado/AD9361配置软件直接调整的电压。子板DS21使用的1P8V则由U301及固定反馈电阻设置，和VADJ不同。未测得电压前不建议改变VADJ来试图点亮DS21。
