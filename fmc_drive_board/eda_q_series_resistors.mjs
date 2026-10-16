import { pathToFileURL } from 'node:url';

const bridge = 'http://127.0.0.1:49620/execute';
const projectUuid = 'd768405f3cf385653a0efebe129dc81b63e17bd4dd003b720884b540bb02d0cf';
const pageUuid = '25d7e7f64d556423';
const resistorUuid = '6ea4d2aa5ea54263bd2c12e31ac86333';
const libraryUuid = '0819f05c4eef4c71ace90d822a990e87';

async function runBatch(first, last) {
  const items = [];
  for (let index = first; index <= last; index++) {
    const u = Math.floor((index - 1) / 8) + 1;
    const bit = (index - 1) % 8;
    items.push({ index, u: `U${u}`, pin: String(bit + 2), net: `RIS_Q${String(index).padStart(3, '0')}`, resistor: `R${index + 21}` });
  }
  const code = `
    const p=await eda.dmt_Project.getCurrentProjectInfo();
    if(p?.uuid!==${JSON.stringify(projectUuid)})throw Error('Wrong project');
    await eda.dmt_EditorControl.openDocument(${JSON.stringify(pageUuid)});
    const touch=(w,p)=>{const a=w.line.flat(Infinity);for(let i=0;i<a.length;i+=2)if(Math.abs(a[i]-p.x)<0.01&&Math.abs(a[i+1]-p.y)<0.01)return true;return false;};
    let cs=await eda.sch_PrimitiveComponent.getAll();
    let ws=await eda.sch_PrimitiveWire.getAll();
    const done=[];
    for(const item of ${JSON.stringify(items)}){
      const part=cs.find(c=>c.designator===item.u);
      if(!part)throw Error('Missing '+item.u);
      const pins=await eda.sch_PrimitiveComponent.getAllPinsByPrimitiveId(part.primitiveId);
      const q=pins.find(x=>x.pinNumber===item.pin);
      if(!q)throw Error('Missing '+item.u+'.'+item.pin);
      const direct=ws.filter(w=>w.net===item.net&&touch(w,q));
      let r=cs.find(c=>c.designator===item.resistor);
      const expectedX=q.x-30;
      if(r&&(Math.abs(r.x-expectedX)>0.01||Math.abs(r.y-q.y)>0.01||r.rotation!==0)){
        await eda.sch_PrimitiveComponent.delete(r.primitiveId);
        cs=cs.filter(c=>c.primitiveId!==r.primitiveId);
        r=undefined;
      }
      if(!r){
        r=await eda.sch_PrimitiveComponent.create({libraryUuid:${JSON.stringify(libraryUuid)},uuid:${JSON.stringify(resistorUuid)}},expectedX,q.y,undefined,0,false,true,true);
        if(!r)throw Error('Create '+item.resistor);
        const ra=r.toAsync();ra.setState_Designator(item.resistor);await ra.done();
        cs.push(r);
      }
      const rp=await eda.sch_PrimitiveComponent.getAllPinsByPrimitiveId(r.primitiveId);
      const p1=rp.find(x=>x.pinNumber==='1');
      const p2=rp.find(x=>x.pinNumber==='2');
      if(!p1||!p2)throw Error('Bad resistor pins '+item.resistor);
      if(direct.length>1)throw Error('Multiple direct wires '+item.net);
      if(direct.length===1){
        await eda.sch_PrimitiveWire.delete(direct[0].primitiveId);
        ws=ws.filter(w=>w.primitiveId!==direct[0].primitiveId);
      }
      const internalNet='QDRV_'+String(item.index).padStart(3,'0');
      if(!ws.some(w=>w.net===internalNet&&touch(w,p2))){
        const iw=await eda.sch_PrimitiveWire.create([p2.x,p2.y,q.x,q.y],internalNet);
        if(!iw)throw Error('Internal wire failed '+item.resistor);
        const attrs=await eda.sch_PrimitiveAttribute.getAll(iw.primitiveId);
        const label=attrs.find(a=>a.key==='Name');
        if(label){const a=label.toAsync();a.setState_ValueVisible(false);await a.done();}
        ws.push(iw);
      }
      if(!ws.some(w=>w.net===item.net&&touch(w,p1))){
        const ow=await eda.sch_PrimitiveWire.create([p1.x,p1.y,p1.x-20,p1.y],item.net);
        if(!ow)throw Error('Output wire failed '+item.net);
        ws.push(ow);
      }
      done.push(item.resistor);
    }
    if(!await eda.sch_Document.save())throw Error('Save failed');
    return {first:${first},last:${last},done};
  `;
  const response = await fetch(bridge, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ code }), signal: AbortSignal.timeout(45000) });
  const body = await response.json();
  if (!response.ok || !body.success) throw Error(body.error || `HTTP ${response.status}`);
  return body.result;
}

const phase = process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href ? process.argv[2] : undefined;
if (phase === 'place') {
  for (let first = 1; first <= 144; first += 12) console.log(await runBatch(first, Math.min(first + 11, 144)));
}
