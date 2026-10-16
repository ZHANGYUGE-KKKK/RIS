// Verify the actual exported schematic netlist, including preservation of the prior design.
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { newPinNets, addedParts } from './eda_external_12v.mjs';

const readNetlist = async path => JSON.parse(await readFile(path, 'utf8'));
const netlist = await readNetlist(process.argv[2] || new URL('./ris_external_12v_verified.enet', import.meta.url));
const prior = await readNetlist(new URL('./ris_power_verified.enet', import.meta.url));
const components = Object.values(netlist.components);
const byName = new Map();
for (const c of components) {
  assert(!byName.has(c.props.Designator), `Duplicate ${c.props.Designator}`);
  byName.set(c.props.Designator, c);
}
assert.equal(components.length, Object.keys(prior.components).length + addedParts.length);
let checkedPins = 0;
function pin(des, number, expected) {
  assert(byName.has(des), `Missing ${des}`);
  assert.equal(byName.get(des).pinInfoMap[number]?.net, expected, `${des}.${number}`);
  checkedPins++;
}
const disconnectedFmcPower = ['C35','C37','C39','D32','D36','D38','D40'];
for (const old of Object.values(prior.components)) {
  const des = old.props.Designator;
  assert(byName.has(des), `Original component removed: ${des}`);
  for (const key of ['Manufacturer Part','Value','Footprint','Supplier Part'])
    assert.equal(byName.get(des).props[key], old.props[key], `${des}: changed ${key}`);
  for (const [n, p] of Object.entries(old.pinInfoMap)) {
    let expected = p.net === 'VCC33' ? 'VCC33_LOCAL' : p.net;
    if (/^U([1-9]|1[0-8])$/.test(des) && n === '18') expected = 'OE_SAFE_N';
    if (des === 'J1' && disconnectedFmcPower.includes(n)) expected = '';
    if (des === 'J1' && n === 'D18') expected = 'PWR_READY';
    pin(des, n, expected);
  }
}
for (const [des, nets] of Object.entries(newPinNets)) {
  assert.deepEqual(Object.keys(byName.get(des).pinInfoMap).sort(), Object.keys(nets).sort(), `${des}: unexpected pin set`);
  for (const [n, net] of Object.entries(nets)) pin(des, n, net);
  assert(byName.get(des).props.Footprint, `${des}: missing footprint`);
  assert(byName.get(des).props['Supplier Part'], `${des}: missing supplier part`);
}
const partChecks = {
  J2: { 'Manufacturer Part':'PJ-102B', 'Supplier Part':'C22359713' },
  F1: { 'Manufacturer Part':'046701.5NR' },
  D1: { 'Manufacturer Part':'SS54' }, D2: { 'Manufacturer Part':'SMBJ15A' },
  SW1: { 'Manufacturer Part':'1101M2S3AQE2', 'Supplier Part':'C23405856' },
  U21: { 'Manufacturer Part':'TPS54302DDCR' },
  U22: { 'Manufacturer Part':'TPS3808G33DBVR' },
  U23: { 'Manufacturer Part':'SN74LVC2G00DCUR' },
  L1: { 'Manufacturer Part':'SRP7050TA-6R8M', Value:'6.8uH' },
  R15: { Value:'100kΩ', Tolerance:'±0.1%' },
  R16: { Value:'22.1kΩ', Tolerance:'±0.1%' },
  R17: { Value:'511kΩ' }, R18: { Value:'105kΩ' },
  R19: { Value:'10kΩ' }, R20: { Value:'10kΩ' },
  C61: { 'Manufacturer Part':'EEEFK1V470P' },
  C62: { Value:'10uF', 'Voltage Rating':'50V' },
  C63: { Value:'10uF', 'Voltage Rating':'50V' },
  C64: { Value:'100nF' }, C65: { Value:'100nF' },
  C66: { Value:'22uF', 'Voltage Rating':'25V' },
  C67: { Value:'22uF', 'Voltage Rating':'25V' },
  C68: { Value:'47pF' }, C69: { Value:'100nF' }, C70: { Value:'100nF' },
  R21: { Value:'1kΩ', 'Manufacturer Part':'0603WAF1001T5E' },
  D3: { 'Manufacturer Part':'LTST-C190KRKT', 'Supplier Part':'C94869' },
};
for (const [des, props] of Object.entries(partChecks))
  for (const [key, value] of Object.entries(props))
    assert.equal(byName.get(des).props[key], value, `${des}: ${key}`);

const allNets = new Set(components.flatMap(c => Object.values(c.pinInfoMap).map(p => p.net)));
assert(!allNets.has('VCC33'), 'Obsolete power net still present');
assert.equal([...allNets].filter(n => /^RIS_Q\d{3}$/.test(n)).length, 144);
assert.equal([...allNets].filter(n => /^DATA_U\d{2}$/.test(n)).length, 18);
for (const p of Object.values(byName.get('J1').pinInfoMap))
  assert(p.net !== 'VCC33_LOCAL' && !p.net.startsWith('DC12'), `Local power reaches FMC ${p.number}`);
const endpoints = net => components.flatMap(c => Object.entries(c.pinInfoMap)
  .filter(([, p]) => p.net === net).map(([n]) => `${c.props.Designator}.${n}`)).sort();
assert.deepEqual(endpoints('OE_N'), ['J1.H16','R1.1','U23.1','U23.2'].sort());
assert.deepEqual(endpoints('OE_SAFE_N'), ['R20.1','U23.3',...Array.from({length:18},(_,i)=>`U${i+1}.18`)].sort());
assert.deepEqual(endpoints('PWR_READY'), ['J1.D18','R19.1','U22.1','U23.6'].sort());
assert.deepEqual(endpoints('RIS_1V5_PGOOD'), ['R9.1','U19.9','U22.3'].sort());
assert.deepEqual(endpoints('DC12_FUSED'), ['D1.1','F1.2'].sort());
assert.deepEqual(endpoints('DC12_PROTECTED'), ['D1.2','SW1.2'].sort());
assert.deepEqual(endpoints('DC12_SWITCHED'), ['C61.1','C62.2','C63.2','C64.2','D2.1','R17.2','SW1.1','U21.3'].sort());
assert.deepEqual(endpoints('LED_PWR_A'), ['D3.2','R21.1'].sort());
assert.deepEqual(endpoints('VCC33_LOCAL').filter(x=>x==='R21.2'), ['R21.2']);

const voutNominal = 0.596 * (1 + 100 / 22.1);
const voutDcMax = 0.611 * (1 + 100 * 1.001 / (22.1 * 0.999));
assert(voutDcMax < 3.5, 'Nominal DC tolerance exceeds TPS51200 limit');
console.log(JSON.stringify({passed:true, components:components.length, checkedPins,
  independentDataInputs:18, outputNets:144, disconnectedFmcPower,
  readinessFmcPin:'D18', voutNominal, voutDcMax,
  limitation:'Netlist checks only; rail transients, loop stability and PCB thermals require hardware validation.'},null,2));
