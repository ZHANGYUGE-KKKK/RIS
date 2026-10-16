"""Extract DATA_U01..50 from the schematic and add LPC pin bindings."""
from pathlib import Path
import csv
import re
import subprocess

root = Path(__file__).resolve().parent
project = root.parent
pdf_dir = project.parent
schematic = subprocess.check_output(['pdftotext', '-layout', str(pdf_dir / 'SCH_Schematic1_2026-10-10.pdf'), '-'], text=True)
carrier = subprocess.check_output(['pdftotext', '-layout', str(pdf_dir / 'ZC706_Rev2_0.pdf'), '-'], text=True)
contacts = {}
for line in schematic.splitlines():
    # The connector symbol lists left H/D contacts and right G/C contacts.
    m = re.search(r'([HD]\d+)\s+\1\s+([GC]\d+)\s+\2', line)
    if not m:
        continue
    left = re.findall(r'\bDATA_U\d{2}\b', line[:m.start()])
    right = re.findall(r'\bDATA_U\d{2}\b', line[m.end():])
    for signals, contact in [(left, m[1]), (right, m[2])]:
        for signal in signals:
            assert signal not in contacts, f'Duplicate signal {signal}'
            contacts[signal] = contact[0] + str(int(contact[1:]))
assert set(contacts) == {f'DATA_U{i:02}' for i in range(1, 51)}, contacts
net_by_contact = {m[2]: m[3] for m in re.finditer(r'\b(LA\d\d_[PN](?:_CC)?|CLK\d_M2C_[PN])([CDGH]\d+)\s+(FMC_LPC_\w+)', carrier)}
ball_by_net = {m[3]: (m[2], m[1]) for m in re.finditer(r'(IO_\S+)\s+([A-Z]+\d+)\s+(FMC_LPC_\w+)', carrier)}
rows = []
for signal, contact in sorted(contacts.items()):
    net = net_by_contact[contact]
    ball, function = ball_by_net[net]
    rows.append([signal, contact, net, ball, function])
assert len({r[1] for r in rows}) == 50
assert len({r[3] for r in rows}) == 50
clock_rows = list(csv.DictReader((root / 'lpc_revised20_mapping.csv').open()))
assert not ({r[3] for r in rows} & {r['package_pin'] for r in clock_rows}), 'Clock/DATA collision'
with (root / 'lpc_data_mapping.csv').open('w') as f:
    w = csv.writer(f)
    w.writerow(['port', 'FMC_LPC_contact', 'carrier_net', 'package_pin', 'pin_function'])
    w.writerows(rows)
xdc = project / 'ris_board_test.srcs/constrs_1/new/ris_clock_test_lpc.xdc'
text = xdc.read_text().split('# BEGIN DATA PIN BINDINGS')[0].rstrip() + '\n\n# BEGIN DATA PIN BINDINGS\n'
for signal, contact, net, ball, function in rows:
    text += f'# {contact}: {net}; {function}\nset_property PACKAGE_PIN {ball} [get_ports {signal}]\nset_property IOSTANDARD LVCMOS25 [get_ports {signal}]\nset_property DRIVE 8 [get_ports {signal}]\nset_property SLEW SLOW [get_ports {signal}]\n'
text += '# END DATA PIN BINDINGS\n'
xdc.write_text(text)
rtl = project / 'ris_board_test.srcs/sources_1/new/ris_clock_test.v'
text = rtl.read_text()
if 'output wire DATA_U01' not in text:
    declarations = ',\n'.join('    output wire ' + r[0] for r in rows)
    text = text.replace('    output wire LATCH_CLK10\n);', '    output wire LATCH_CLK10,\n' + declarations + '\n);')
    logic = '''    // Test-only data pattern; all 50 pads remain active output ports.
    // This counter does not implement the external 595 data protocol.
    reg [49:0] data_pattern = 50'd0;
    always @(posedge clk_global) begin
        data_pattern <= data_pattern + 50'd1;
    end
'''
    logic += ''.join(f'    assign {r[0]} = data_pattern[{i}];\n' for i, r in enumerate(rows))
    text = text.replace('endmodule', logic + 'endmodule')
    text = text.replace('clock-pin smoke test', 'clock and DATA pin smoke test')
    rtl.write_text(text)
print(f'Added {len(rows)} DATA ports; all extracted from schematic; no collisions with the 20 revised clocks.')
