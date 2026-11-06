RIS 256QAM 码本生成器

快速使用
1. 参数已预填：5.8 GHz、20×20、行距 2.54 mm、列距 19.14 mm。
2. 发射端默认 (0,0,-0.4) m；接收端默认 (0,0,+0.6) m。
3. 当前用扫描角 0；未来用 -45,0,45。每个角度生成一套独立码本。
4. 点击“生成/刷新”，查看模型星座、某个单元的 PWM 和某时刻的整板状态。
5. 点击“导出码本 ZIP”。只需把这一个 .py 脚本复制到其他电脑即可运行。

坐标和方向
RIS 位于 z=0 平面，中心为原点；发射端在 z<0，接收端在 z>0。
列沿 x，行沿 y，id=row*cols+col，所有索引从 0 开始。
x=(col-(cols-1)/2)*列距；y=(row-(rows-1)/2)*行距。
row=0 在负 y 一侧；col=0 在负 x 一侧。
扫描角 theta 相对 +z 法线，正负角在同一截面两侧。
截面方位角 az=0 为 x-z 面；az=90 为 y-z 面。
近场：接收位置 R*(sin(theta)cos(az), sin(theta)sin(az), cos(theta))。
距离 R 是中心到接收天线的斜距；±45° 时仍保持相同斜距。
远场：按目标方向平面波设计；所填距离不参与远场相位。

物理模型
时间约定 exp(+j*w*t)，保留 h=+1 或 -1 阶谐波。
f_out=f_carrier+h*f_PWM。每 PWM 周期使用一个可跨周期边界的矩形状态 1 脉冲。
Delta=Gamma1-Gamma0；Gamma 是单元的复透射系数，不是驱动电压。
a_h=Delta*sin(pi*p/L)/pi*exp[-j*h*2*pi*(r+p/2)/L]。
其余时间为状态 0；p 为高电平片数，r 为起点。
256QAM：每字节 IIIIQQQQ，两组 4 bit 分别作为 16-PAM 的 Gray 标签。
Gray 解码后电平为 2*n-15；x=(I+jQ)/(15*sqrt(2))*幅度系数。
以最大角点归一化，非平均功率归一化；默认 I,Q 各为 ±1,±3,...,±15。
目标 a_i=abs(Delta)/pi*abs(x)*exp[j*(arg(x)+psi_i)]。
近场 psi_i=k_in*(Rtx_i-Rtx_center)+k_out*(Rrx_i-Rrx_center)。
远场 psi_i=k_in*(Rtx_i-Rtx_center)-k_out*(v dot r_i)。
连续占空比 M=asin(abs(x))/pi。
脉冲中心 u=(arg(Delta)-arg(x)-psi_i)/(h*2*pi) mod 1。
在允许的整数脉宽/起点中选择复系数平方误差最小的组合。
默认只用 0<M<=0.5 的幅度单调分支。

时序
L 是每个 PWM 周期的时间片数；Delta_t=1/(f_PWM*L)。
每个 QAM 符号重复 K 个 PWM 周期；Rs=f_PWM/K，裸比特率=8*Rs。
默认 1 MHz、L=256、K=3：Delta_t=3.90625 ns，Rs=333.333 kSymbol/s。
默认最小星座幅度所需连续脉宽约 21.24 ns。时间步进需由实际链路核对。
最短高/低电平输入 0 表示暂不施加该约束。
可循环跨界的脉冲在符号切换处仍可能出现较短片段；本工具不约束相邻符号
拼接后的边沿间隔。若硬件有限制，需在最终数据流层检查或设计过渡规则。

EVM
预览中蓝点为目标星座，红点为模型接收星座。接收模型按 1/(Rtx*Rrx)
加权并消除几何公共相位；远场权重为 1/Rtx。
原始 EVM 对比绝对归一化目标；均衡 EVM 去掉一项公共复增益。
单元 EVM 统计各单元一阶复系数的量化误差，不能等同实际接收 EVM。
这不是连续随机数据流的 RF 仿真，不包含接收滤波、符号间干扰、泄漏和噪声。

导出 ZIP
metadata.json：所有参数、坐标约定、频率、尺寸、EVM 和二进制格式。
symbols.csv：0..255 的字节、Gray 映射、电平、幅度和相位。
elements.csv：物理单元 id、row、col、x、y、z。
pulse_parameters.csv：direction,symbol,unit,p,r；数据足以重建全部状态。
codebook_frames.bin：方向 → 符号 → 时间片 → 打包单元。
每个时间片固定 ceil(N/8) 字节，每字节低位优先，unit i 在 byte i//8 的 bit i%8。
每帧尾部的未用高位填 0；每个符号仅存一个 PWM 周期，播放器重复 K 次。
帧偏移=((direction*256+symbol)*L+q)*ceil(N/8)。
状态 C=1 if ((q-r) mod L)<p else 0。
元数据详细写明以上顺序，CSV 使用 UTF-8，JSON 保留可读参数。
README.txt：本说明；SHA256SUMS.txt：校验前面各文件的 SHA-256。

假设与范围
独立单元、每单元可单独设置脉宽/时间位置、两状态幅相在阵列上相同。
使用点馈源球面波，未加入喇叭方向图、极化、互耦、角度色散或实测逐单元校准。
结果是理论初版码本，不代表已实测达到 256QAM 性能。
两状态不严格等幅反相时，一阶公式仍使用其复数差，但载波和其他谐波也会变化。

参考：
https://www.nature.com/articles/s41377-018-0092-z
https://arxiv.org/abs/2511.05636
本工具实现每单元一阶谐波幅相反演及近场路径补偿，非论文 XOR 架构复刻。

命令行
python3 ris_codebook_gui.py
python3 ris_codebook_gui.py --headless --output codebook.zip
python3 ris_codebook_gui.py --headless --config my_config.json --output codebook.zip
python3 ris_codebook_gui.py --self-test
