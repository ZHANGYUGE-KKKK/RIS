// ZC706 XTP215 rev 2.0, FMC LPC connector J5, sheet 28.
const projectUuid = 'd768405f3cf385653a0efebe129dc81b63e17bd4dd003b720884b540bb02d0cf';
const fmcPageUuid = 'cf67416c66763eed';
const connectorId = '39af253251cbe309';

const code = `
  const project = await eda.dmt_Project.getCurrentProjectInfo();
  if (project?.uuid !== ${JSON.stringify(projectUuid)}) throw Error('Wrong active project');
  await eda.dmt_EditorControl.openDocument(${JSON.stringify(fmcPageUuid)});
  const components = await eda.sch_PrimitiveComponent.getAll();
  const connector = components.find(item => item.primitiveId === ${JSON.stringify(connectorId)});
  if (!connector || connector.designator !== 'J1'
    || connector.component?.uuid !== 'fdb3e3d0d37ee4f7') {
    throw Error('FMC connector J1 changed');
  }
  const pins = await eda.sch_PrimitiveComponent.getAllPinsByPrimitiveId(connector.primitiveId);
  if (pins?.length !== 160) throw Error('Unexpected FMC pin count');
  const pin = name => {
    const found = pins.find(item => item.pinNumber === name);
    if (!found) throw Error('Missing FMC pin ' + name);
    return found;
  };
  const wires = await eda.sch_PrimitiveWire.getAll();
  const changes = { flags: 0, wires: 0, groundPins: 0, powerPins: 0 };
  const linePoints = wire => wire.line.flat(Infinity);
  const touches = (wire, point) => {
    const line = linePoints(wire);
    for (let i = 0; i < line.length; i += 2) {
      if (line[i] === point.x && line[i + 1] === point.y) return true;
    }
    return false;
  };
  async function ensureFlag(kind, net, x, y) {
    if (components.some(item => item.componentType === 'netflag'
      && item.net === net && item.x === x && item.y === y)) return;
    const created = await eda.sch_PrimitiveComponent.createNetFlag(kind, net, x, y);
    if (!created) throw Error('Flag creation failed: ' + net + '@' + x + ',' + y);
    components.push(created);
    changes.flags++;
  }
  async function ensurePinWire(name, net, x) {
    const p = pin(name);
    const touching = wires.filter(item => touches(item, p));
    if (touching.some(item => item.net !== net)) throw Error(name + ' already on another net');
    if (touching.length) return;
    const created = await eda.sch_PrimitiveWire.create([p.x, p.y, x, p.y], net);
    if (!created) throw Error('Wire creation failed: ' + name);
    wires.push(created);
    changes.wires++;
  }
  async function ensureBus(x, top, bottom) {
    const existing = wires.some(item => item.net === 'GND'
      && linePoints(item).some((value, index, line) => index % 2 === 0
        && value === x && line[index + 1] === top));
    if (existing) return;
    const created = await eda.sch_PrimitiveWire.create([x, top, x, bottom], 'GND');
    if (!created) throw Error('Ground bus creation failed at x=' + x);
    wires.push(created);
    changes.wires++;
  }
  await ensureFlag('Ground', 'GND', 80, 1080);
  await ensureFlag('Ground', 'GND', 460, 1080);
  await ensureBus(80, 1080, 250);
  await ensureBus(460, 1080, 260);
  const ground = {
    C: [1, 4, 5, 8, 9, 12, 13, 16, 17, 20, 21, 24, 25, 28, 29, 32, 33, 36, 38, 40],
    D: [2, 3, 6, 7, 10, 13, 16, 19, 22, 25, 28, 37, 39],
    G: [1, 4, 5, 8, 11, 14, 17, 20, 23, 26, 29, 32, 35, 38, 40],
    H: [3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36, 39],
  };
  for (const [row, numbers] of Object.entries(ground)) {
    for (const number of numbers) {
      await ensurePinWire(row + String(number).padStart(2, '0'), 'GND', row === 'C' || row === 'G' ? 80 : 460);
      changes.groundPins++;
    }
  }
  await ensurePinWire('H02', 'GND', 460);
  for (const name of ['C39', 'D36', 'D38', 'D40']) {
    const p = pin(name);
    const x = name[0] === 'C' ? 120 : 380;
    await ensureFlag('Power', 'VCC33', x, p.y);
    await ensurePinWire(name, 'VCC33', x);
    changes.powerPins++;
  }
  for (const name of ['G39', 'H40']) {
    const p = pin(name);
    const x = name[0] === 'G' ? 120 : 380;
    await ensureFlag('Power', 'VADJ', x, p.y);
    await ensurePinWire(name, 'VADJ', x);
    changes.powerPins++;
  }
  const saved = await eda.sch_Document.save();
  if (!saved) throw Error('FMC schematic save failed');
  return { ...changes, saved };
`;

const response = await fetch('http://127.0.0.1:49620/execute', {
  method: 'POST',
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ code }),
  signal: AbortSignal.timeout(120000),
});
const body = await response.json();
if (!response.ok || !body.success) throw new Error(body.error || `Bridge HTTP ${response.status}`);
console.log(JSON.stringify(body.result));
