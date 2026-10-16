// One-time drawing record for the external 12 V revision. Audit separately before manufacture.
import { execute, projectUuid } from './eda_ris_power.mjs';
import { pathToFileURL } from 'node:url';
export const pages={ext:'0a2ac9b2e8ba6167',ctrl:'314b7fbdb4fdf11e',reg:'25d7e7f64d556423',fmc:'cf67416c66763eed',pwr:'ed4c09b31710665c',bias:'d186b8eb974e4009'};
export async function run(page,code){
  return execute(`const pr=await eda.dmt_Project.getCurrentProjectInfo();if(pr?.uuid!==${JSON.stringify(projectUuid)})throw Error('Wrong project');await eda.dmt_EditorControl.openDocument(${JSON.stringify(pages[page])});const doc=await eda.dmt_SelectControl.getCurrentDocumentInfo();if(doc?.uuid!==${JSON.stringify(pages[page])})throw Error('Wrong page');`+code,false);
}
export const addedParts=[
  ['ext','J2','c38b2a4d98dd447a9aa92da3b35a6485',140,940,0],
  ['ext','F1','8e8858c99ce04863ad97c092ef8cdf65',310,955,0],
  ['ext','D1','7e4971a287384663bb1defa327c587af',450,950,180],
  ['ext','D2','9a1593d1216344c29a56d306ce854ef8',570,800,270],
  ['ext','C61','781dffc34ba547ff8814d566f8c9c44f',700,800,0],
  ['ext','C62','7e420c672c864e52b016f9ca4bfdb5ec',830,800,90],
  ['ext','C63','7e420c672c864e52b016f9ca4bfdb5ec',960,800,90],
  ['ext','C64','96b39256cc3f4d80bd3b503deb4f3328',1090,800,90],
  ['ext','U21','09d09adf261f49f397dcf1784d04fb9a',870,510,0],
  ['ext','L1','e7d02fab09664602a4f37ed3bb803a00',1110,570,0],
  ['ext','C65','96b39256cc3f4d80bd3b503deb4f3328',1030,680,0],
  ['ext','C66','0de9d28bbcd34ca3bf2a4d78faaa50bb',1290,460,90],
  ['ext','C67','0de9d28bbcd34ca3bf2a4d78faaa50bb',1440,460,90],
  ['ext','R15','3b5957712d6943698e6319ba927b09a8',1110,420,90],
  ['ext','R16','3a9d6e3dc5c645eb96a80194db2a01a3',1110,300,90],
  ['ext','C68','c8583cd280864c26a2f7d37b4ea62539',970,420,90],
  ['ext','R17','67004138469944f8be5a481226f907a4',540,590,90],
  ['ext','R18','b4f6c5eff71248b1b261f10cbfc0d78a',540,470,90],
  ['ext','SW1','97d2f1ad197a4083a16e81b9c303d49c',520,950,0],
  ['ext','R21','18db11499a04403ba8c98e2f7a687fbc',1320,700,90],
  ['ext','D3','0663a397f0ce47a1afd569dcce2685bb',1320,850,270],
  ['ctrl','U22','bb230446dfcd4c149520babac09b3ba9',320,530,0],
  ['ctrl','U23','37b6d05a96b34c018ca56ac54c231527',780,530,0],
  ['ctrl','C69','96b39256cc3f4d80bd3b503deb4f3328',180,320,90],
  ['ctrl','C70','96b39256cc3f4d80bd3b503deb4f3328',780,320,90],
  ['ctrl','R19','b948db94476e4027ac8953235755ec96',540,580,90],
  ['ctrl','R20','b948db94476e4027ac8953235755ec96',1010,580,90],
];
const phase=process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href ? process.argv[2] : undefined;
if(phase==='place'){
  console.log(await run('ext',`const sheet=(await eda.sch_PrimitiveComponent.getAll()).find(c=>c.componentType==='sheet');const attrs=await eda.sch_PrimitiveAttribute.getAll(sheet.primitiveId);for(const [key,value]of [['Width','1655'],['Height','1170'],['Size','A3'],['Page Size','A3']]){const p=attrs.find(a=>a.key===key);if(!p)throw Error('Missing '+key);const a=p.toAsync();a.setState_Value(value);await a.done();}return true;`));
  for(const page of ['ext','ctrl']){
    const batchParts=addedParts.filter(p=>p[0]===page);
    for(let i=0;i<batchParts.length;i+=4){
      console.log(await run(page,`const cs=await eda.sch_PrimitiveComponent.getAll();const out=[];for(const [page,d,uuid,x,y,r]of ${JSON.stringify(batchParts.slice(i,i+4))}){if(cs.some(c=>c.designator===d))throw Error('Already exists '+d);const c=await eda.sch_PrimitiveComponent.create({libraryUuid:'0819f05c4eef4c71ace90d822a990e87',uuid},x,y,undefined,r,false,true,true);if(!c)throw Error('Create failed '+d);const a=c.toAsync();a.setState_Designator(d);await a.done();out.push(d);}if(!await eda.sch_Document.save())throw Error('Save failed');return out;`));
    }
  }
}
if(phase==='pins'){
  for(const page of ['ext','ctrl'])console.log(JSON.stringify({page,parts:await run(page,`const out=[];for(const c of await eda.sch_PrimitiveComponent.getAll()){if(!c.designator)continue;out.push({d:c.designator,id:c.primitiveId,name:c.manufacturerId,supplier:c.supplierId,pins:(await eda.sch_PrimitiveComponent.getAllPinsByPrimitiveId(c.primitiveId)).map(p=>({n:p.pinNumber,name:p.pinName,x:p.x,y:p.y,r:p.rotation}))});}return out;`)}));
}

export const newPinNets={
  J2:{1:'DC12_RAW',2:'GND',3:''},F1:{1:'DC12_RAW',2:'DC12_FUSED'},
  D1:{1:'DC12_FUSED',2:'DC12_PROTECTED'},D2:{1:'DC12_SWITCHED',2:'GND'},
  C61:{1:'DC12_SWITCHED',2:'GND'},C62:{1:'GND',2:'DC12_SWITCHED'},C63:{1:'GND',2:'DC12_SWITCHED'},C64:{1:'GND',2:'DC12_SWITCHED'},
  U21:{1:'GND',2:'BUCK_SW',3:'DC12_SWITCHED',4:'BUCK_FB',5:'BUCK_EN',6:'BUCK_BOOT'},
  L1:{1:'VCC33_LOCAL',2:'BUCK_SW'},C65:{1:'BUCK_BOOT',2:'BUCK_SW'},
  C66:{1:'GND',2:'VCC33_LOCAL'},C67:{1:'GND',2:'VCC33_LOCAL'},
  R15:{1:'BUCK_FB',2:'VCC33_LOCAL'},R16:{1:'GND',2:'BUCK_FB'},C68:{1:'BUCK_FB',2:'VCC33_LOCAL'},
  R17:{1:'BUCK_EN',2:'DC12_SWITCHED'},R18:{1:'GND',2:'BUCK_EN'},
  SW1:{1:'DC12_SWITCHED',2:'DC12_PROTECTED',3:'',4:'',5:''},
  R21:{1:'LED_PWR_A',2:'VCC33_LOCAL'},D3:{1:'GND',2:'LED_PWR_A'},
  U22:{1:'PWR_READY',2:'GND',3:'RIS_1V5_PGOOD',4:'',5:'VCC33_LOCAL',6:'VADJ'},
  U23:{1:'OE_N',2:'OE_N',3:'OE_SAFE_N',4:'GND',5:'FPGA_OUTPUT_EN',6:'PWR_READY',7:'FPGA_OUTPUT_EN',8:'VADJ'},
  C69:{1:'GND',2:'VADJ'},C70:{1:'GND',2:'VADJ'},R19:{1:'PWR_READY',2:'VADJ'},R20:{1:'OE_SAFE_N',2:'VADJ'},
};

if(phase==='wire'){
  console.log(await run('ext',`const cs=await eda.sch_PrimitiveComponent.getAll();for(const [d,y,r]of [['F1',955,0],['D1',950,180],['D2',800,270],['C61',800,0]]){const c=cs.find(c=>c.designator===d);const a=c.toAsync();a.setState_Y(y);a.setState_Rotation(r);await a.done();}return true;`));
  for(const page of ['ext','ctrl']){
    const wires=[],flags=[];
    const w=(net,...line)=>wires.push({net,line});
    const f=(net,x,y)=>flags.push({net,x,y,kind:net==='GND'?'Ground':'Power'});
    if(page==='ext'){
      w('DC12_RAW',160,950,285,950);w('GND',160,930,200,930,200,860);f('GND',200,860);
      w('DC12_FUSED',335,950,430,950);w('DC12_PROTECTED',470,950,570,950,700,950,830,950,960,950,1090,950);f('DC12_PROTECTED',570,950);
      for(const [x,y]of [[570,820],[700,820],[830,815],[960,815],[1090,820]])w('DC12_PROTECTED',x,y,x,950);
      for(const [x,y]of [[570,780],[700,780],[830,785],[960,785],[1090,780]])w('GND',x,y,x,740);
      w('GND',570,740,700,740,830,740,960,740,1090,740);f('GND',570,740);
      w('GND',820,520,700,520);w('BUCK_SW',820,510,700,510);w('DC12_PROTECTED',820,500,700,500);
      w('BUCK_FB',920,500,940,500,940,360,970,360,1110,360);
      w('BUCK_EN',920,510,1020,510);w('BUCK_BOOT',920,520,1020,520);
      w('BUCK_SW',1090,570,1030,570);w('VCC33_LOCAL',1130,570,1290,570,1440,570);f('VCC33_LOCAL',1440,570);
      w('BUCK_BOOT',1010,680,930,680);w('BUCK_SW',1050,680,1140,680);
      for(const x of [1290,1440]){w('VCC33_LOCAL',x,475,x,530,x,570);w('GND',x,445,x,400);}
      w('GND',1290,400,1440,400);f('GND',1290,400);
      w('VCC33_LOCAL',1110,440,1110,480,1110,530,1290,530);
      w('VCC33_LOCAL',970,435,970,480,1110,480);
      w('BUCK_FB',1110,400,1110,360,1110,320);w('BUCK_FB',970,405,970,360);
      w('GND',1110,280,1110,240);f('GND',1110,240);
      w('DC12_PROTECTED',540,610,540,660);f('DC12_PROTECTED',540,660);
      w('BUCK_EN',540,570,540,530,540,490);w('BUCK_EN',540,530,620,530);
      w('GND',540,450,540,400);f('GND',540,400);
    }else{
      w('PWR_READY',265,540,120,540);w('GND',265,530,120,530);w('RIS_1V5_PGOOD',265,520,120,520);
      w('VCC33_LOCAL',375,530,490,530);w('VADJ',375,540,490,540);
      w('OE_N',740,545,650,545);w('OE_N',740,535,680,535,680,545);
      w('OE_SAFE_N',740,525,620,525);w('GND',740,515,620,515);
      for(const [y,n]of [[515,'FPGA_OUTPUT_EN'],[525,'PWR_READY'],[535,'FPGA_OUTPUT_EN'],[545,'VADJ']])w(n,820,y,940,y);
      for(const x of [180,780]){w('VADJ',x,340,x,380);f('VADJ',x,380);w('GND',x,300,x,260);f('GND',x,260);}
      w('VADJ',540,600,540,640);f('VADJ',540,640);w('PWR_READY',540,560,540,480,440,480);
      w('VADJ',1010,600,1010,640);f('VADJ',1010,640);w('OE_SAFE_N',1010,560,1010,480,910,480);
    }
    const existing=await run(page,`return(await eda.sch_PrimitiveWire.getAll()).length;`);
    if(existing)throw Error('Wires already present; inspect rather than repeat '+page);
    for(let i=0;i<wires.length;i+=12)console.log(await run(page,`for(const w of ${JSON.stringify(wires.slice(i,i+12))})if(!await eda.sch_PrimitiveWire.create(w.line,w.net))throw Error('Wire failed '+w.net);return{wires:${Math.min(12,wires.length-i)}};`));
    for(let i=0;i<flags.length;i+=8)console.log(await run(page,`for(const f of ${JSON.stringify(flags.slice(i,i+8))})if(!await eda.sch_PrimitiveComponent.createNetFlag(f.kind,f.net,f.x,f.y))throw Error('Flag failed');return{flags:${Math.min(8,flags.length-i)}};`));
    console.log(await run(page,`const cs=await eda.sch_PrimitiveComponent.getAll();const c=cs.find(c=>c.designator===${JSON.stringify(page==='ext'?'J2':'U22')});const p=(await eda.sch_PrimitiveComponent.getAllPinsByPrimitiveId(c.primitiveId)).find(p=>p.pinNumber===${JSON.stringify(page==='ext'?'3':'4')});const a=p.toAsync();a.setState_NoConnected(true);await a.done();return{saved:await eda.sch_Document.save()};`));
  }
}

if(phase==='migrate'||phase==='rename'){
  if(phase==='migrate'){
  console.log(await run('fmc',`const cs=await eda.sch_PrimitiveComponent.getAll();const pins=await eda.sch_PrimitiveComponent.getAllPinsByPrimitiveId('39af253251cbe309');const wires=await eda.sch_PrimitiveWire.getAll();let removed=0;for(const name of ['C39','D36','D38','D40']){const p=pins.find(p=>p.pinNumber===name);const touching=wires.filter(w=>{const a=w.line.flat(Infinity);return a.some((v,i)=>i%2===0&&Math.abs(v-p.x)<0.01&&Math.abs(a[i+1]-p.y)<0.01);});if(touching.length!==1||touching[0].net!=='VCC33')throw Error('Unexpected supply wiring at '+name);await eda.sch_PrimitiveWire.delete(touching[0].primitiveId);const flags=cs.filter(c=>c.componentType==='netflag'&&c.net==='VCC33'&&Math.abs(c.y-p.y)<0.01&&Math.abs(c.x-(name[0]==='C'?120:380))<0.01);if(flags.length!==1)throw Error('Unexpected flag '+name);await eda.sch_PrimitiveComponent.delete(flags[0].primitiveId);const a=p.toAsync();a.setState_NoConnected(true);await a.done();removed++;}const ready=pins.find(p=>p.pinNumber==='D18');const a=ready.toAsync();a.setState_NoConnected(false);await a.done();if(!await eda.sch_PrimitiveWire.create([ready.x,ready.y,ready.x+90,ready.y],'PWR_READY'))throw Error('Ready wire failed');if(!await eda.sch_Document.save())throw Error('Save failed');return{removedFmcPowerConnections:removed,readyPin:'D18'};`));
  }
  for(const page of ['reg','fmc','pwr','bias']){
    console.log(await run(page,`const rename=n=>n==='VCC33'?'VCC33_LOCAL':(${JSON.stringify(page)}==='reg'&&n==='OE_N'?'OE_SAFE_N':n);let wires=0,flags=0;for(const w of await eda.sch_PrimitiveWire.getAll()){const n=rename(w.net);if(n===w.net)continue;const attr=(await eda.sch_PrimitiveAttribute.getAll(w.primitiveId)).find(a=>a.key==='Name');if(!attr)throw Error('Missing wire label '+w.primitiveId);const a=attr.toAsync();a.setState_Value(n);await a.done();wires++;}for(const c of await eda.sch_PrimitiveComponent.getAll()){if(!['netflag','netport'].includes(c.componentType))continue;const n=rename(c.net);if(n===c.net)continue;const attrs=await eda.sch_PrimitiveAttribute.getAll(c.primitiveId);for(const key of ['Global Net Name','Name']){const attr=attrs.find(a=>a.key===key);if(!attr)throw Error('Missing flag label');const a=attr.toAsync();a.setState_Value(n);await a.done();}flags++;}if(!await eda.sch_Document.save())throw Error('Save failed');return{page:${JSON.stringify(page)},wires,flags};`));
  }
  const textChanges={
    fmc:[
      ['VCC33 supplies 595 outputs and RIS_1V5 regulator. VADJ is 2.5V logic supply.','External 12V -> VCC33_LOCAL supplies 595 VCCB and RIS bias. VADJ remains 2.5V logic.'],
      ['VCC33: C39/D36/D38/D40. D32 is 3P3VAUX and is NC on this board.','FMC C35/C37/C39/D32/D36/D38/D40 are NC. No connection to local 12V / 3.3V.'],
      ['LA12_P/N=LED1_N/LED2_N; LA13_P=LED3_N; other FMC user I/O NC','LA12_P/N=LED1_N/LED2_N; LA13_P=LED3_N; LA13_N (D18)=PWR_READY; other user I/O NC'],
    ],
    bias:[
      ['Input: FMC VCC33 (3.3V). Do not use VADJ as the power source.','Input: VCC33_LOCAL from external 12V buck. VADJ is logic only.'],
      ['EN: always on with VCC33.','EN: always on with VCC33_LOCAL.'],
      ['PGOOD: monitor net only; pulled up to VADJ.','PGOOD -> U22 MR# on PWR_CTRL; pull-up to VADJ.'],
      ['Start-up: keep OE_N high until bias is stable and a valid frame is latched. PGOOD is not wired to FPGA.','OE_SAFE_N is hardware gated. Monitor PWR_READY (FMC D18); reload a valid frame after power cycling.'],
    ],
  };
  for(const [page,changes]of Object.entries(textChanges))console.log(await run(page,`const ts=await eda.sch_PrimitiveText.getAll();for(const [before,after]of ${JSON.stringify(changes)}){const t=ts.find(t=>t.content===before);if(!t)throw Error('Missing expected annotation');const a=t.toAsync();a.setState_Content(after);await a.done();}return{page:${JSON.stringify(page)},saved:await eda.sch_Document.save()};`));
}

if(phase==='notes'){
  const notes={ext:[
    [80,1110,'EXTERNAL 12V INPUT -> LOCAL 3.3V POWER',20],
    [80,1070,'J2: 5.5 x 2.5mm plug, CENTER POSITIVE, regulated 12V DC (recommended adapter: 2A).',13],
    [80,1040,'PJ-102B: pin 1 = center (+); pin 2 = sleeve / GND; pin 3 = switched sleeve, NC.',12],
    [80,1005,'F1: 1.5A fuse. D1: reverse-polarity blocking. SW1: master DC power switch.',12],
    [80,975,'D2: 15V unidirectional TVS. SW1 is C&K 1101M2S3AQE2, 6A / 28VDC SPDT.',12],
    [1200,840,'D3 + R21: red ON LED after VCC33_LOCAL (about 1.3mA).',12],
    [1200,930,'Input bulk: 47uF / 35V',12],
    [1200,900,'C62/C63: 2 x 10uF / 50V',12],
    [1200,870,'C64: 100nF at U21 VIN',12],
    [80,690,'U21 TPS54302: synchronous buck, nominal 400kHz.',13],
    [80,650,'L1: 6.8uH, Irms 5.5A, Isat 8.5A.',12],
    [80,610,'Local 3.3V design target: 2A total; verify PCB thermals.',12],
    [80,570,'FMC 3.3V / 3.3VAUX / 12V pins remain NC.',12],
    [80,530,'Common GND with ZC706 and RIS; no galvanic isolation.',12],
    [80,330,'R15/R16: 100k / 22.1k, 0.1%; VOUT nominal = 3.293V.',12],
    [80,295,'C68: 47pF feed-forward. C66/C67: 2 x 22uF / 25V ceramic.',12],
    [80,260,'R17/R18 set input UVLO: approx. 6.86V rising / 5.66V falling (typical, protected input).',12],
    [80,210,'Layout: keep VIN bypass loop and BOOT/SW loop short; minimize SW copper and keep FB away from SW.',12],
    [80,180,'VCC33_LOCAL powers all 595 VCCB pins and U19/U20. Keep load/ground current out of VADJ routing.',12],
    [80,150,'Verify 3.3V overshoot stays below 3.5V at TPS51200; check cable hot-plug, load steps and input protection.',12],
    [80,120,'Do not parallel local 3.3V or DC input with FMC supply pins. 1.5V source/sink thermal limit still applies.',12],
  ],ctrl:[
    [70,760,'POWER MONITOR AND 595 OUTPUT INTERLOCK',17],
    [70,710,'Powered by FMC VADJ = 2.5V, so external 12V loss is detectable while FPGA remains on.',11],
    [70,680,'U22 monitors local 3.3V (>3.07V nominal) and U19 1.5V PGOOD via MR#.',11],
    [70,650,'CT intentionally NC: approximately 20ms release delay after both conditions are good.',11],
    [70,430,'PWR_READY -> FMC D18 / LA13_N, Bank 10, FPGA INPUT / LVCMOS25.',11],
    [70,405,'U23: gate 1 inverts FPGA OE_N; gate 2 combines it with PWR_READY.',11],
    [70,210,'OE_SAFE_N = OE_N OR NOT(PWR_READY); connect only OE_SAFE_N to U1-U18 pin 18.',11],
    [70,180,'Power fault -> Q outputs high-Z. PGOOD is a coarse voltage window, not a precision 1.5V check.',11],
    [70,150,'Firmware: on PWR_READY falling, set OE_N high; wait for READY, reload 8 bits/channel, latch, then enable.',11],
    [70,120,'Hardware gates power readiness only; it cannot certify that the output data has been initialized.',11],
    [70,90,'Keep MR_N high for shifting. Hardware OE gating does not change the shared latch/clock timing.',11],
  ]};
  for(const [page,list]of Object.entries(notes))console.log(await run(page,`const old=await eda.sch_PrimitiveText.getAll();for(const [x,y,s,size]of ${JSON.stringify(list)}){if(old.some(t=>t.content===s))continue;await eda.sch_PrimitiveText.create(x,y,s,0,null,null,size,false,false,false);}return{page:${JSON.stringify(page)},saved:await eda.sch_Document.save()};`));
}
