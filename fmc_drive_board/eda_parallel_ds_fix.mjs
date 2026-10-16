const projectUuid = 'd768405f3cf385653a0efebe129dc81b63e17bd4dd003b720884b540bb02d0cf';
const fmcPageUuid = 'cf67416c66763eed';
const connectorId = '39af253251cbe309';
const bridgeUrl = 'http://127.0.0.1:49620/execute';

async function execute(code) {
  const response = await fetch(bridgeUrl, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ code }),
    signal: AbortSignal.timeout(120000),
  });
  const body = await response.json();
  if (!response.ok || !body.success) throw new Error(body.error || `Bridge HTTP ${response.status}`);
  return body.result;
}

const result = await execute(`
  const project = await eda.dmt_Project.getCurrentProjectInfo();
  if (project?.uuid !== ${JSON.stringify(projectUuid)}) throw Error('Wrong active project');
  await eda.dmt_EditorControl.openDocument(${JSON.stringify(fmcPageUuid)});
  const components = await eda.sch_PrimitiveComponent.getAll();
  const connector = components.find(item => item.primitiveId === ${JSON.stringify(connectorId)});
  if (!connector) throw Error('Missing connector');
  let pins = await eda.sch_PrimitiveComponent.getAllPinsByPrimitiveId(connector.primitiveId);
  const pin = name => pins.find(item => item.pinNumber === name);
  const wires = await eda.sch_PrimitiveWire.getAll();
  const touches = (wire, point) => {
    const line = wire.line.flat(Infinity);
    for (let i = 0; i < line.length; i += 2) if (line[i] === point.x && line[i + 1] === point.y) return true;
    return false;
  };
  async function setNc(name, value) {
    const p = pin(name);
    if (!p) throw Error('Missing pin ' + name);
    const a = p.toAsync();
    a.setState_NoConnected(value);
    await a.done();
  }
  async function setNet(name, net) {
    const p = pin(name);
    const w = (await eda.sch_PrimitiveWire.getAll()).filter(item => touches(item, p));
    if (w.length !== 1) throw Error('Expected one wire at ' + name + ', got ' + w.length);
    const modified = await eda.sch_PrimitiveWire.modify(w[0].primitiveId, { net });
    if (!modified) throw Error('Failed to modify wire at ' + name);
  }
  await setNet('D14', 'DATA_U15');
  await setNet('D15', 'DATA_U16');
  await setNet('C14', 'DATA_U17');
  await setNet('C15', 'DATA_U18');
  for (const name of ['G18','G19','G21']) {
    const p = pin(name);
    const w = (await eda.sch_PrimitiveWire.getAll()).filter(item => touches(item, p));
    if (w.length) await eda.sch_PrimitiveWire.delete(w.map(item => item.primitiveId));
    await setNc(name, true);
  }
  const ledMapping = [['G15','LED1_N'],['G16','LED2_N'],['D17','LED3_N']];
  for (const [name, net] of ledMapping) {
    const p = pin(name);
    if (!p) throw Error('Missing pin ' + name);
    await setNc(name, false);
    const touching = (await eda.sch_PrimitiveWire.getAll()).filter(item => touches(item, p));
    if (!touching.length) {
      const x = p.x < 250 ? p.x - 70 : p.x + 70;
      const created = await eda.sch_PrimitiveWire.create([p.x, p.y, x, p.y], net);
      if (!created) throw Error('Failed to create ' + name + ' ' + net);
    } else if (touching.some(item => item.net !== net)) {
      throw Error(name + ' has wrong net');
    }
  }
  const texts = await eda.sch_PrimitiveText.getAll();
  const old = texts.filter(t => String(t.content).includes('LA12_P/N=LED1_N/LED2_N'));
  if (old.length) await eda.sch_PrimitiveText.delete(old.map(t => t.primitiveId));
  await eda.sch_PrimitiveText.create(600, 420, 'LA12_P/N=LED1_N/LED2_N; LA13_P=LED3_N; other FMC user I/O NC', 0, null, null, 12, false, false, false);
  const saved = await eda.sch_Document.save();
  if (!saved) throw Error('Save failed');
  return { saved, correctedData: true, correctedLeds: true };
`);
console.log(JSON.stringify(result));
