// Scoped implementation for the existing RIS_1V5 sheet. No PCB operations.
import { pathToFileURL } from 'node:url';
export const projectUuid = 'd768405f3cf385653a0efebe129dc81b63e17bd4dd003b720884b540bb02d0cf';
export const pageUuid = 'd186b8eb974e4009';
export async function execute(code, guarded = true) {
  const guard = `const project=await eda.dmt_Project.getCurrentProjectInfo();
    if(project?.uuid!==${JSON.stringify(projectUuid)})throw Error('Wrong active project');
    await eda.dmt_EditorControl.openDocument(${JSON.stringify(pageUuid)});
    const documentInfo=await eda.dmt_SelectControl.getCurrentDocumentInfo();
    if(documentInfo?.uuid!==${JSON.stringify(pageUuid)})throw Error('Wrong active sheet');`;
  const response = await fetch('http://127.0.0.1:49620/execute', {
    method: 'POST', headers: {'content-type':'application/json'},
    body: JSON.stringify({code: (guarded ? guard : '') + code}),
    signal: AbortSignal.timeout(45000),
  });
  const body = await response.json();
  if (!response.ok || !body.success) throw Error(body.error || `HTTP ${response.status}`);
  return body.result;
}

const devices = {
  c100n: '96b39256cc3f4d80bd3b503deb4f3328',
  c1u: 'f4744ff7405a46a48e360c2c6fadeca3',
  c10u: '8c1f4a9e9d204b148b36ce719c891bd1',
  c1n: 'f7218f4330f6417aa864e05da749dbcb',
  r2k: '5b71408e41924f6e98fba69097eca8d9',
  r3k: '9eae676519e74d368dda23560ed61e72',
  r10k: 'b948db94476e4027ac8953235755ec96',
  r0: 'fc38f436091b49a696be03a7955956ed',
  r100: '5303080f43d74b41ae76fc5142aa97e5',
};
export const parts = [
  ['C39','c100n',130,730,90,'VCC33','GND'],
  ['C40','c1u',330,730,90,'RIS_REF2V5','GND'],
  ['C41','c100n',530,730,90,'RIS_REF1V5','GND'],
  ['C42','c1u',990,1020,90,'VCC33','GND'],
  ['C43','c10u',630,1020,90,'VCC33','GND'],
  ['C44','c10u',750,1020,90,'VCC33','GND'],
  ['C45','c10u',870,1020,90,'VCC33','GND'],
  ['C46','c100n',1110,1020,90,'VCC33','GND'],
  ['C47','c100n',970,730,90,'RIS_REFOUT','GND'],
  ['C48','c10u',1080,620,90,'RIS_1V5_MAIN','GND'],
  ['C49','c10u',1190,620,90,'RIS_1V5_MAIN','GND'],
  ['C50','c10u',1300,620,90,'RIS_1V5_MAIN','GND'],
  ['C51','c10u',1410,620,90,'RIS_1V5_MAIN','GND'],
  ['C52','c1u',150,360,90,'RIS_1V5_A','GND'],
  ['C53','c100n',250,360,90,'RIS_1V5_A','GND'],
  ['C54','c1u',510,360,90,'RIS_1V5_B','GND'],
  ['C55','c100n',610,360,90,'RIS_1V5_B','GND'],
  ['C56','c1u',870,360,90,'RIS_1V5_C','GND'],
  ['C57','c100n',970,360,90,'RIS_1V5_C','GND'],
  ['C58','c1u',1230,360,90,'RIS_1V5_D','GND'],
  ['C59','c100n',1330,360,90,'RIS_1V5_D','GND'],
  ['C60','c1n',750,620,90,'RIS_1V5_SNS','GND'],
  ['R6','r2k',430,820,90,'RIS_REF2V5','RIS_REF1V5'],
  ['R7','r3k',430,730,90,'RIS_REF1V5','GND'],
  ['R8','r10k',1230,850,90,'VCC33','RIS_1V5_EN'],
  ['R9','r10k',1430,850,90,'VADJ','RIS_1V5_PGOOD'],
  ['R10','r0',200,470,0,'RIS_1V5_MAIN','RIS_1V5_A'],
  ['R11','r0',560,470,0,'RIS_1V5_MAIN','RIS_1V5_B'],
  ['R12','r0',920,470,0,'RIS_1V5_MAIN','RIS_1V5_C'],
  ['R13','r0',1280,470,0,'RIS_1V5_MAIN','RIS_1V5_D'],
  ['R14','r100',700,710,0,'RIS_1V5_MAIN','RIS_1V5_SNS'],
];

const phase = process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href ? process.argv[2] : undefined;
if (phase === 'place') {
  console.log(await execute(`const cs=await eda.sch_PrimitiveComponent.getAll();const sheet=cs.find(c=>c.componentType==='sheet');const attrs=await eda.sch_PrimitiveAttribute.getAll(sheet.primitiveId);for(const [key,value] of [['Width','1655'],['Height','1170'],['Size','A3'],['Page Size','A3']]){const attr=attrs.find(a=>a.key===key);if(!attr)throw Error('Missing sheet attribute '+key);const a=attr.toAsync();a.setState_Value(value);await a.done();}for(const [des,x,y] of [['U19',850,850],['U20',230,870]]){const c=cs.find(c=>c.designator===des);if(!c)throw Error('Missing '+des);const a=c.toAsync();a.setState_X(x);a.setState_Y(y);await a.done();}return true;`));
  for (let start=0; start<parts.length; start+=5) {
    const batch=parts.slice(start,start+5).map(([d,k,x,y,r])=>({d,uuid:devices[k],x,y,r}));
    console.log(await execute(`const out=[];const cs=await eda.sch_PrimitiveComponent.getAll();for(const p of ${JSON.stringify(batch)}){let c=cs.find(c=>c.designator===p.d);if(!c){c=await eda.sch_PrimitiveComponent.create({libraryUuid:'0819f05c4eef4c71ace90d822a990e87',uuid:p.uuid},p.x,p.y,undefined,p.r,false,true,true);if(!c)throw Error('Create '+p.d);const a=c.toAsync();a.setState_Designator(p.d);await a.done();}else if(c.x!==p.x||c.y!==p.y||c.rotation!==p.r)throw Error('Existing part differs: '+p.d);out.push(p.d);}if(!await eda.sch_Document.save())throw Error('Save failed');return out;`));
  }
}
if (phase === 'pins') {
  console.log(JSON.stringify(await execute(`const out=[];for(const c of await eda.sch_PrimitiveComponent.getAll()){if(!c.designator)continue;out.push({d:c.designator,id:c.primitiveId,x:c.x,y:c.y,rotation:c.rotation,supplierId:c.supplierId,pins:(await eda.sch_PrimitiveComponent.getAllPinsByPrimitiveId(c.primitiveId)).map(p=>({n:p.pinNumber,name:p.pinName,x:p.x,y:p.y,r:p.rotation}))});}return out;`),null,2));
}

export const icNets = {
  U19: {'1':'RIS_REF1V5','2':'VCC33','3':'RIS_1V5_MAIN','4':'GND','5':'RIS_1V5_SNS','6':'RIS_REFOUT','7':'RIS_1V5_EN','8':'GND','9':'RIS_1V5_PGOOD','10':'VCC33','11':'GND'},
  U20: {'1':'VCC33','2':'RIS_REF2V5','3':'GND'},
};
if (phase === 'wire') {
  const wires = [], flags = [], ports = [];
  const w=(net,...line)=>wires.push({net,line});
  const f=(net,x,y)=>flags.push({net,x,y,kind:net==='GND'?'Ground':'Power'});
  w('VCC33',180,880,130,880,130,915); f('VCC33',130,915);
  w('VCC33',130,750,130,880);
  w('GND',130,710,130,680); f('GND',130,680);
  w('RIS_REF2V5',280,880,330,880,430,880,430,840);
  w('RIS_REF2V5',330,750,330,880);
  w('GND',330,710,330,680); f('GND',330,680);
  w('GND',280,860,295,860,295,800); f('GND',295,800);
  w('RIS_REF1V5',430,800,430,775,430,750);
  w('RIS_REF1V5',430,775,530,775,530,750);
  w('GND',430,710,430,680); f('GND',430,680);
  w('GND',530,710,530,680); f('GND',530,680);
  for(const x of [630,750,870,990,1110]){
    w('VCC33',x,1040,x,1070); w('GND',x,1000,x,970);
  }
  w('VCC33',630,1070,750,1070,870,1070,990,1070,1110,1070); f('VCC33',630,1070);
  w('GND',630,970,750,970,870,970,990,970,1110,970); f('GND',630,970);
  for(const [n,net] of Object.entries(icNets.U19)) {
    const number=Number(n);
    if(number<=5)w(net,790,885-10*number,650,885-10*number);
    else if(number===6)w(net,910,825,970,825,970,750);
    else w(net,910,765+10*number,1090,765+10*number);
  }
  w('GND',970,710,970,680); f('GND',970,680);
  w('VCC33',1230,870,1230,920);f('VCC33',1230,920);
  w('RIS_1V5_EN',1230,830,1230,790,1180,790);
  w('VADJ',1430,870,1430,920);f('VADJ',1430,920);
  w('RIS_1V5_PGOOD',1430,830,1430,790,1360,790);
  for(const x of [1080,1190,1300,1410]){
    w('RIS_1V5_MAIN',x,640,x,670); w('GND',x,600,x,570);
  }
  w('RIS_1V5_MAIN',1080,670,1190,670,1300,670,1410,670);f('RIS_1V5_MAIN',1080,670);
  w('GND',1080,570,1190,570,1300,570,1410,570);f('GND',1080,570);
  w('RIS_1V5_MAIN',680,710,620,710);f('RIS_1V5_MAIN',620,710);
  w('RIS_1V5_SNS',720,710,750,710,750,635);
  w('GND',750,605,750,570);f('GND',750,570);
  for(let i=0;i<4;i++){
    const x=200+i*360, net='RIS_1V5_'+String.fromCharCode(65+i);
    w('RIS_1V5_MAIN',x-20,470,x-90,470);f('RIS_1V5_MAIN',x-90,470);
    w(net,x+20,470,x+110,470);ports.push({net,x:x+110,y:470});
    w(net,x+50,470,x+50,410,x+50,380);
    w(net,x-50,380,x-50,410,x+50,410);
    w('GND',x-50,340,x-50,310,x+50,310,x+50,340);f('GND',x-50,310);
  }
  for(let i=0;i<wires.length;i+=16){
    console.log(await execute(`const list=await eda.sch_PrimitiveWire.getAll();let count=0;for(const w of ${JSON.stringify(wires.slice(i,i+16))}){const found=list.find(v=>v.net===w.net&&JSON.stringify(v.line.flat(Infinity).map(n=>Math.round(n*1000)/1000))===JSON.stringify(w.line));if(found)continue;if(!await eda.sch_PrimitiveWire.create(w.line,w.net))throw Error('Wire failed '+w.net);count++;}return{wires:count};`));
  }
  for(let i=0;i<flags.length;i+=10){
    console.log(await execute(`const cs=await eda.sch_PrimitiveComponent.getAll();let n=0;for(const f of ${JSON.stringify(flags.slice(i,i+10))}){if(cs.some(c=>c.componentType==='netflag'&&c.net===f.net&&Math.abs(c.x-f.x)<0.01&&Math.abs(c.y-f.y)<0.01))continue;if(!await eda.sch_PrimitiveComponent.createNetFlag(f.kind,f.net,f.x,f.y))throw Error('Flag failed');n++;}return{flags:n};`));
  }
  console.log(await execute(`const cs=await eda.sch_PrimitiveComponent.getAll();for(const p of ${JSON.stringify(ports)}){if(cs.some(c=>c.componentType==='netport'&&c.net===p.net))continue;if(!await eda.sch_PrimitiveComponent.createNetPort('BI',p.net,p.x,p.y))throw Error('Port failed');}if(!await eda.sch_Document.save())throw Error('Save failed');return{saved:true};`));
}

if (phase === 'notes') {
  const notes = [
    [80,1140,'RIS 1.5V SOURCE / SINK BIAS SUPPLY - FOUR BRANCHES',18],
    [80,1050,'Input: FMC VCC33 (3.3V). Do not use VADJ as the power source.',12],
    [80,1015,'Nominal load: source 0.202A / sink 0.288A total (144 cells, 500 ohm/cell).',12],
    [80,975,'U20: 2.5V reference; R6/R7 = 2k/3k, both 0.1%. REFIN = 1.500V.',12],
    [620,1110,'U19 input bypass: C43-C45 = 30uF; C42 for VIN; C46 HF bypass.',11],
    [80,630,'Reference only: RIS_REF2V5 / RIS_REF1V5 / RIS_REFOUT are NOT power outputs.',11],
    [1030,745,'C48-C51: 4 x 10uF ceramic, close to VO/PGND.',11],
    [1030,718,'Effective local COUT must remain >20uF after derating.',11],
    [600,535,'R14/C60 sense filter: 100 ohm / 1nF. Tune after loop/transient check.',11],
    [600,510,'Kelvin sense from C48-C51 (+); keep sense separate from load current.',11],
    [1160,975,'EN: always on with VCC33.',11],
    [1160,950,'PGOOD: monitor net only; pulled up to VADJ.',11],
    [80,270,'A: cells 001-036     B: 037-072     C: 073-108     D: 109-144 (proposed grouping).',12],
    [80,240,'Four branches share one 1.5V regulator. R10-R13 are 0 ohm links, not current limiters.',12],
    [80,210,'Common GND with RIS. Each cell still requires its own ~500 ohm resistor on the RIS side.',12],
    [80,180,'Start-up: keep OE_N high until bias is stable and a valid frame is latched. PGOOD is not wired to FPGA.',12],
    [80,150,'U19 EPAD / PGND / GND: solid ground, thermal vias, large copper. Sink power is dissipated as heat.',12],
    [80,120,'Design for >=0.5A source/sink total, subject to PCB thermal validation. IC current limit is NOT a continuous rating.',11],
    [80,90,'Before release: check all-low/all-high load steps, rail overshoot, cable drop and temperature. No RIS connector fitted.',11],
  ];
  console.log(await execute(`const old=await eda.sch_PrimitiveText.getAll();let count=0;for(const [x,y,s,size]of ${JSON.stringify(notes)}){if(old.some(t=>t.content===s))continue;await eda.sch_PrimitiveText.create(x,y,s,0,null,null,size,false,false,false);count++;}return{notes:count,saved:await eda.sch_Document.save()};`));
}
