RIS 64QAM 码本生成器（新增模式）

在 GUI“QAM 阶数”选择 64，再点击“生成 / 刷新”，最后导出 ZIP。
旧参数 JSON 未指定 qam_order 时仍使用 256QAM；64QAM 参数保存 qam_order=64。
只改变星座阶数，不自动改变 PWM 频率、L、K、阵列或硬件约束。

映射与归一化
符号 id=0..63；6 bit 标签 IIIQQQ，高 3 bit 是 I、低 3 bit 是 Q 的 Gray 标签。
各轴 Gray 解码得到 n=0..7，电平=2*n-7，即 ±1,±3,±5,±7。
x=(I+jQ)/(7*sqrt(2))*幅度系数，以最大角点归一化，非平均功率归一化。
独立生成全部 64 点，不截取旧 256QAM 码本。

物理模型与坐标（沿用原算法）
时间约定 exp(+j*w*t)，h=+1 或 -1；f_out=f_carrier+h*f_PWM。
RIS 位于 z=0，中心为原点，TX z<0、RX z>0；列沿 x，行沿 y。
unit=row*cols+col，索引从 0 开始；单元坐标和阵列中心距见 elements.csv。
扫描角相对 +z 法线，方位角 0 为 x-z 面、90 为 y-z 面。
近场按中心到接收端斜距定位，远场按目标平面波方向设计。
Delta=Gamma1-Gamma0，Gamma 是单元复透射系数，不是驱动电压。
每 PWM 周期一个可循环跨界的矩形状态 1 脉冲，其余为状态 0。
a_h=Delta*sin(pi*p/L)/pi*exp[-j*h*2*pi*(r+p/2)/L]。
目标 a_i=abs(Delta)/pi*abs(x)*exp[j*(arg(x)+psi_i)]。
近场 psi_i=k_in*(Rtx_i-Rtx_center)+k_out*(Rrx_i-Rrx_center)；
远场 psi_i=k_in*(Rtx_i-Rtx_center)-k_out*(v dot r_i)。
连续占空比 M=asin(abs(x))/pi；脉冲中心由目标相位反演。
沿用原复系数最小平方误差整数脉宽/起点优化及高低电平约束。
默认只用 0<M<=0.5 的幅度单调分支。

时序与硬件
时间片 Delta_t=1/(f_PWM*L)；每符号重复 K 个 PWM 周期。
Rs=f_PWM/K；64QAM 裸比特率=6*Rs，不包含前导、导频或纠错开销。
默认参数仍为 1 MHz、L=256、K=3，非硬件实测保证。
最小星座幅度=幅度系数/7；所需最短连续脉宽=asin(幅度系数/7)/pi/f_PWM。
最短高/低电平输入 0 表示未施加约束。
PWM 周期能力不等于时间片和边沿精度，需核对实际驱动与播放器。
本工具不约束相邻符号拼接后的边沿间隔，实际数据流需另行检查。

导出 ZIP（格式 ris-qam64-pwm-v1）
metadata.json：参数、shape=[方向数,64,L,单元数]、速率、EVM 和二进制格式。
symbols.csv：0..63 的符号、两位十六进制存储值、6 bit bits_IIIQQQ、I/Q 和归一化复数。
hex_byte 仅表示符号 id 的存储值；有效信息为低 6 bit，高 2 bit 为 0。
elements.csv：物理单元 id、row、col、x、y、z。
pulse_parameters.csv：direction,symbol,unit,width_slots,start_slot。
codebook_frames.bin：方向 → 符号 → 时间片 → 打包单元。
每片 ceil(N/8) 字节；unit i 在 byte i//8 的 bit i%8，未用高位为 0。
帧偏移=((direction*64+symbol)*L+q)*ceil(N/8)。
状态 C=1 if ((q-r) mod L)<p else 0；仅存一个 PWM 周期，播放器重复 K 次。
README.txt 为本说明；SHA256SUMS.txt 为各数据文件的校验和。
64QAM 播放器/接收端需遵守本映射与 64 点尺寸，不能继续硬编码 256 点或 8 bit。

EVM 与适用范围
蓝点为目标，红点为模型接收；近场按 1/(Rtx*Rrx)、远场按 1/Rtx 加权。
原始 EVM 比较绝对归一化目标；均衡 EVM 消除一项公共复增益。
单元 EVM 是各单元一阶复系数的量化误差。
独立、相同两状态的透射单元，每单元可独立设置脉宽和时间偏移。
不包含噪声、耦合、天线方向图、极化、切换过渡、接收滤波或符号间干扰。
各方向为可切换独立码本，发送同一数据流，不生成同时多波束。
整板全 0/全 1 测量不能直接作为逐单元校准；理论 EVM 不代表实测性能。

命令行
python3 ris_codebook_gui.py --headless --qam-order 64 --output ris_64qam_codebook.zip
python3 ris_codebook_gui.py --headless --config my_config.json --qam-order 64 --output codebook64.zip
python3 ris_codebook_gui.py --self-test
