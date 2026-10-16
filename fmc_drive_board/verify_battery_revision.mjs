import assert from 'node:assert/strict';

const bridge = 'http://127.0.0.1:49620/execute';
const projectUuid = 'd768405f3cf385653a0efebe129dc81b63e17bd4dd003b720884b540bb02d0cf';
const pages = {
  EXT_12V: '0a2ac9b2e8ba6167',
  PWR_CTRL: '314b7fbdb4fdf11e',
  FMC: 'cf67416c66763eed',
  REG: '25d7e7f64d556423',
  PWR: 'ed4c09b31710665c',
  BATTERY_GND: 'd186b8eb974e4009',
};

async function execute(code) {
  const response = await fetch(bridge, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ code: `const p=await eda.dmt_Project.getCurrentProjectInfo();if(p?.uuid!==${JSON.stringify(projectUuid)})throw Error('Wrong project');${code}` }),
    signal: AbortSignal.timeout(45000),
  });
  const body = await response.json();
  if (!response.ok || !body.success) throw Error(body.error || `HTTP ${response.status}`);
  return body.result;
}

const result = await execute(`
  const pages=${JSON.stringify(pages)};
  const out={};
  const bad=[];
  const touches=(w,p)=>{const a=w.line.flat(Infinity);for(let i=0;i<a.length;i+=2)if(Math.abs(a[i]-p.x)<0.01&&Math.abs(a[i+1]-p.y)<0.01)return true;return false;};
  for(const [name,id] of Object.entries(pages)){
    await eda.dmt_EditorControl.openDocument(id);
    const cs=await eda.sch_PrimitiveComponent.getAll();
    const ws=await eda.sch_PrimitiveWire.getAll();
    const ts=await eda.sch_PrimitiveText.getAll();
    if(ws.some(w=>String(w.net).includes('RIS_1V5')))bad.push(name+':stale 1.5V net');
    if(ts.some(t=>['TPS51200','REF3025','RIS_1V5'].some(s=>String(t.content).includes(s))))bad.push(name+':stale 1.5V note');
    out[name]={parts:cs.filter(c=>c.componentType==='part').map(c=>c.designator).filter(Boolean),nets:[...new Set(ws.map(w=>w.net))].sort()};
    if(name==='BATTERY_GND'){
      const j=cs.find(c=>c.designator==='J3');
      if(!j)bad.push('BATTERY_GND:J3 missing');
      else{
        const pins=await eda.sch_PrimitiveComponent.getAllPinsByPrimitiveId(j.primitiveId);
        if(pins.length!==4)bad.push('BATTERY_GND:J3 is not 4 pin');
        if(pins.some(p=>!ws.some(w=>w.net==='GND'&&touches(w,p))))bad.push('BATTERY_GND:J3 pin not GND');
      }
    }
    if(name==='PWR_CTRL'){
      const u=cs.find(c=>c.designator==='U22');
      const pins=await eda.sch_PrimitiveComponent.getAllPinsByPrimitiveId(u.primitiveId);
      if(!ws.some(w=>w.net==='VADJ'&&touches(w,pins.find(p=>p.pinNumber==='3'))))bad.push('PWR_CTRL:U22 MR# not VADJ');
    }
    if(name==='PWR'&&ws.some(w=>w.net==='VCC33'))bad.push('PWR:stale VCC33 net');
  }
  return {bad,out};
`);

assert.deepEqual(result.bad, []);
const reg = result.out.REG.nets.filter(n => /^RIS_Q\d{3}$/.test(n));
const data = result.out.REG.nets.filter(n => /^DATA_U\d{2}$/.test(n));
assert.equal(reg.length, 144);
assert.equal(data.length, 18);
assert.equal(result.out.BATTERY_GND.parts.length, 1);
console.log(JSON.stringify({ passed: true, outputNets: reg.length, dataInputs: data.length, pageSummary: result.out }, null, 2));
