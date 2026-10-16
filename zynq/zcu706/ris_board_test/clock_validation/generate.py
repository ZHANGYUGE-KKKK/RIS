from pathlib import Path
import re,csv,subprocess
p=Path(__file__).resolve().parent
s=subprocess.check_output(['pdftotext','-layout',str(p.parent.parent/'ZC706_Rev2_0.pdf'),'-'],text=True)
ball={m[3]:(m[2],m[1]) for m in re.finditer(r'(IO_\S+|MGT\S+)\s+([A-Z]+\d+)\s+(FMC_HPC_\w+)',s)}
conn={m[2]:m[3] for m in re.finditer(r'\b((?:LA\d\d_[PN](?:_CC)?|DP0_[CM]2[CM]_[PN]))([CDGH]\d+)\s+(FMC_HPC_\w+)',s)}
rows=[]
contacts=[('C3','C2'),('H35','H34'),('C7','C6'),('D9','D8'),('C11','C10'),('D12','D11'),('C15','C14'),('D15','D14'),('C19','C18'),('D18','D17')]
for i,(latch,shift) in enumerate(contacts,1):
 for kind,c in [('LATCH',latch),('SHIFT',shift)]:
  net=conn[c]; pin,func=ball[net]; rows.append((f'{kind}_CLK{i}',c,net,pin,func,'unsupported' if i in [1,3] else 'supported'))
with (p/'pin_mapping.csv').open('w') as f:
 w=csv.writer(f);w.writerow(['port','FMC_contact','carrier_net','package_pin','pin_function','result']);w.writerows(rows)
for mode in ['original20','valid16']:
 chosen=[r for r in rows if mode=='original20' or r[-1]=='supported']
 ports=[r[0] for r in chosen]
 v='module clock_probe(input sysclk_p, input sysclk_n,\n'+',\n'.join('output '+q for q in ports)+');\nwire clk_ibuf,clk;\nIBUFDS ib (.I(sysclk_p),.IB(sysclk_n),.O(clk_ibuf));\nBUFG bg (.I(clk_ibuf),.O(clk));\n'
 for q in ports: v+=f'(* DONT_TOUCH = "TRUE" *) ODDR #(.DDR_CLK_EDGE("SAME_EDGE"), .INIT(1\'b0), .SRTYPE("SYNC")) od_{q} (.Q({q}), .C(clk), .CE(1\'b1), .D1(1\'b1), .D2(1\'b0), .R(1\'b0), .S(1\'b0));\n'
 (p/(mode+'.v')).write_text(v+'endmodule\n')
 x='set_property PACKAGE_PIN H9 [get_ports sysclk_p]\nset_property PACKAGE_PIN G9 [get_ports sysclk_n]\nset_property IOSTANDARD LVDS [get_ports {sysclk_p sysclk_n}]\ncreate_clock -name sysclk -period 5.000 [get_ports sysclk_p]\n'
 for q,c,n,b,func,r in chosen:
  x+=f'# {c}: {n}; {func}\nset_property PACKAGE_PIN {b} [get_ports {q}]\nset_property IOSTANDARD LVCMOS25 [get_ports {q}]\nset_property DRIVE 8 [get_ports {q}]\nset_property SLEW SLOW [get_ports {q}]\n'
 (p/(mode+'.xdc')).write_text(x)
