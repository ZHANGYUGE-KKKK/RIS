const projectUuid = 'd768405f3cf385653a0efebe129dc81b63e17bd4dd003b720884b540bb02d0cf';
const regPageUuid = '25d7e7f64d556423';
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

  const pad = value => String(value).padStart(2, '0');
  const oldCascade = /^(?:CAS_\\d{2}|SER_DATA|SER_OUT)$/;

  await eda.dmt_EditorControl.openDocument(${JSON.stringify(regPageUuid)});
  let components = await eda.sch_PrimitiveComponent.getAll();
  let wires = await eda.sch_PrimitiveWire.getAll();
  const oldWires = wires.filter(w => oldCascade.test(w.net));
  if (oldWires.length && !await eda.sch_PrimitiveWire.delete(oldWires.map(w => w.primitiveId))) {
    throw Error('Failed to remove cascade wires');
  }

  let dataWires = 0;
  let ncPins = 0;
  for (let number = 1; number <= 18; number++) {
    components = await eda.sch_PrimitiveComponent.getAll();
    const device = components.find(item => item.designator === 'U' + number);
    if (!device || device.manufacturerId !== '74LVC8T595PWJ') throw Error('Missing U' + number);
    const pins = await eda.sch_PrimitiveComponent.getAllPinsByPrimitiveId(device.primitiveId);
    const pin = n => {
      const found = pins.find(item => item.pinNumber === String(n));
      if (!found) throw Error('Missing U' + number + ' pin ' + n);
      return found;
    };
    const ds = pin(19);
    const dataNet = 'DATA_U' + pad(number);
    const newWire = await eda.sch_PrimitiveWire.create([ds.x, ds.y, ds.x - 35, ds.y], dataNet);
    if (!newWire) throw Error('Failed to create ' + dataNet);
    dataWires++;
    const q7s = pin(14);
    const asyncPin = q7s.toAsync();
    asyncPin.setState_NoConnected(true);
    await asyncPin.done();
    ncPins++;
  }
  await eda.sch_Document.save();

  await eda.dmt_EditorControl.openDocument(${JSON.stringify(fmcPageUuid)});
  components = await eda.sch_PrimitiveComponent.getAll();
  const connector = components.find(item => item.primitiveId === ${JSON.stringify(connectorId)});
  if (!connector || connector.designator !== 'J1') throw Error('Missing FMC connector J1');
  let pins = await eda.sch_PrimitiveComponent.getAllPinsByPrimitiveId(connector.primitiveId);
  if (pins?.length !== 160) throw Error('Unexpected FMC pin count');
  const pin = name => {
    const found = pins.find(item => item.pinNumber === name);
    if (!found) throw Error('Missing FMC pin ' + name);
    return found;
  };
  wires = await eda.sch_PrimitiveWire.getAll();
  const linePoints = wire => wire.line.flat(Infinity);
  const touches = (wire, point) => {
    const line = linePoints(wire);
    for (let i = 0; i < line.length; i += 2) {
      if (line[i] === point.x && line[i + 1] === point.y) return true;
    }
    return false;
  };
  const used = new Set();
  for (const wire of wires) {
    for (const p of pins) if (touches(wire, p)) used.add(p.pinNumber);
  }
  const mapping = [
    ['G06', 'SHIFT_CLK'],
    ['D08', 'LATCH_CLK'],
    ['H07', 'DATA_U01'], ['H08', 'DATA_U02'],
    ['G09', 'DATA_U03'],  ['G10', 'DATA_U04'],
    ['H10', 'DATA_U05'], ['H11', 'DATA_U06'],
    ['D11', 'DATA_U07'], ['D12', 'DATA_U08'],
    ['C10', 'DATA_U09'], ['C11', 'DATA_U10'],
    ['H13', 'DATA_U11'], ['H14', 'DATA_U12'],
    ['G12', 'DATA_U13'], ['G13', 'DATA_U14'],
    ['C14', 'DATA_U15'], ['C15', 'DATA_U16'],
    ['D14', 'DATA_U17'], ['D15', 'DATA_U18'],
    ['H16', 'OE_N'], ['H17', 'MR_N'],
    ['G18', 'LED1_N'], ['G19', 'LED2_N'], ['G21', 'LED3_N'],
  ];
  const mapped = new Set(mapping.map(item => item[0]));
  let fmcWires = 0;
  for (const [name, net] of mapping) {
    const p = pin(name);
    const touching = wires.filter(w => touches(w, p));
    if (touching.some(w => w.net !== net)) throw Error(name + ' already has another net');
    if (!touching.length) {
      const x = p.x < 250 ? p.x - 70 : p.x + 70;
      const created = await eda.sch_PrimitiveWire.create([p.x, p.y, x, p.y], net);
      if (!created) throw Error('Failed to create FMC wire ' + name + ' ' + net);
      wires.push(created);
      fmcWires++;
    }
    used.add(name);
  }
  pins = await eda.sch_PrimitiveComponent.getAllPinsByPrimitiveId(connector.primitiveId);
  const keepConnected = new Set([
    'C01','C04','C05','C08','C09','C12','C13','C16','C17','C20','C21','C24','C25','C28','C29','C32','C33','C36','C38','C40',
    'D02','D03','D06','D07','D10','D13','D16','D19','D22','D25','D28','D32','D36','D37','D38','D39','D40',
    'G01','G04','G05','G08','G11','G14','G17','G20','G23','G26','G29','G32','G35','G38','G39','G40',
    'H02','H03','H06','H09','H12','H15','H18','H21','H24','H27','H30','H33','H36','H39','H40',
    ...mapped,
  ]);
  let fmcNc = 0;
  for (const p of pins) {
    if (keepConnected.has(p.pinNumber)) continue;
    if (p.getState_NoConnected()) continue;
    const asyncPin = p.toAsync();
    asyncPin.setState_NoConnected(true);
    await asyncPin.done();
    fmcNc++;
  }
  const texts = await eda.sch_PrimitiveText.getAll();
  const stale = texts.filter(t => String(t.content).includes('LA pin assignment') || String(t.content).includes('LA pins TBD'));
  if (stale.length) await eda.sch_PrimitiveText.delete(stale.map(t => t.primitiveId));
  await eda.sch_PrimitiveText.create(600, 480, 'FMC-LPC Bank10: LA00_CC_P=SHIFT_CLK; LA01_CC_P=LATCH_CLK', 0, null, null, 12, false, false, false);
  await eda.sch_PrimitiveText.create(600, 450, 'LA02_P/N..LA10_P/N=DATA_U01..DATA_U18; LA11_P=OE_N; LA11_N=MR_N', 0, null, null, 12, false, false, false);
  await eda.sch_PrimitiveText.create(600, 420, 'LA12_P/N=LED1_N/LED2_N; LA13_P=LED3_N; other FMC user I/O NC', 0, null, null, 12, false, false, false);
  const saved = await eda.sch_Document.save();
  if (!saved) throw Error('FMC save failed');
  return { oldCascadeWires: oldWires.length, dataWires, ncPins, fmcWires, fmcNc, saved };
`);
console.log(JSON.stringify(result));
