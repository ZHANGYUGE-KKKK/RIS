// Checks the netlist exported by EasyEDA, independently of drawing coordinates.
// Historical pre-external-12V snapshot only; use verify_external_12v.mjs for the current schematic.
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { icNets, parts } from './eda_ris_power.mjs';

const path = process.argv[2] || new URL('./ris_power_verified.enet', import.meta.url);
const netlist = JSON.parse(await readFile(path, 'utf8'));
const components = Object.values(netlist.components);
const byName = new Map();
for (const c of components) {
  assert(!byName.has(c.props.Designator), `Duplicate ${c.props.Designator}`);
  byName.set(c.props.Designator, c);
}
let checkedPins = 0;
function pin(des, number, expected) {
  const c = byName.get(des);
  assert(c, `Missing ${des}`);
  assert.equal(c.pinInfoMap[number]?.net, expected, `${des}.${number}`);
  checkedPins++;
}
for (const [des, nets] of Object.entries(icNets)) {
  for (const [n, net] of Object.entries(nets)) pin(des, n, net);
}
for (const [des, , , , rotation, first, second] of parts) {
  pin(des, rotation === 90 ? '2' : '1', first);
  pin(des, rotation === 90 ? '1' : '2', second);
  assert(byName.get(des).props.Footprint, `${des} lacks footprint`);
  assert(byName.get(des).props['Supplier Part'], `${des} lacks supplier part`);
}
const risNets = new Set();
for (let i=1; i<=18; i++) {
  const des = `U${i}`;
  for (const [n, net] of Object.entries({1:'VCC33',10:'GND',11:'GND',12:'GND',13:'GND',
    14:'',15:'MR_N',16:'SHIFT_CLK',17:'LATCH_CLK',18:'OE_N',
    19:`DATA_U${String(i).padStart(2,'0')}`,20:'VADJ'})) pin(des,n,net);
  for (let q=0; q<8; q++) {
    const net=`RIS_Q${String((i-1)*8+q+1).padStart(3,'0')}`;
    pin(des,String(q+2),net);risNets.add(net);
  }
}
assert.equal(risNets.size,144);
const dataPins=['H07','H08','G09','G10','H10','H11','D11','D12','C10','C11',
  'H13','H14','G12','G13','D14','D15','C14','C15'];
dataPins.forEach((n,i)=>pin('J1',n,`DATA_U${String(i+1).padStart(2,'0')}`));
for(const [n,net]of Object.entries({G06:'SHIFT_CLK',D08:'LATCH_CLK',H16:'OE_N',H17:'MR_N',
  G15:'LED1_N',G16:'LED2_N',D17:'LED3_N',C39:'VCC33',D32:'',D36:'VCC33',
  D38:'VCC33',D40:'VCC33',G39:'VADJ',H40:'VADJ',C35:'',C37:'',D18:''}))pin('J1',n,net);
for(let i=1;i<=36;i++){pin(`C${i}`,'1','GND');pin(`C${i}`,'2',i%2?'VADJ':'VCC33');}
assert.equal(byName.get('U19').props['Manufacturer Part'],'TPS51200DRCR');
assert.equal(byName.get('U20').props['Manufacturer Part'],'REF3025AIDBZR');
for(const d of ['R6','R7'])assert.equal(byName.get(d).props.Tolerance,'±0.1%');
assert.equal(byName.get('R6').props.Value,'2kΩ');
assert.equal(byName.get('R7').props.Value,'3kΩ');
for(const d of ['C48','C49','C50','C51'])assert.equal(byName.get(d).props.Value,'10uF');
assert.equal(byName.get('R14').props.Value,'100Ω');
assert.equal(byName.get('C60').props.Value,'1nF');
for(const d of ['R10','R11','R12','R13'])assert.equal(byName.get(d).props.Value,'0Ω');
console.log(JSON.stringify({passed:true,components:components.length,checkedPins,
  outputNets:risNets.size,newPowerParts:parts.length+2,
  branchNets:['RIS_1V5_A','RIS_1V5_B','RIS_1V5_C','RIS_1V5_D']},null,2));
