const projectUuid = 'd768405f3cf385653a0efebe129dc81b63e17bd4dd003b720884b540bb02d0cf';
const regPageUuid = '25d7e7f64d556423';
const bridgeUrl = 'http://127.0.0.1:49620/execute';

const first = Number(process.argv[2] ?? 1);
const last = Number(process.argv[3] ?? 18);
if (!Number.isInteger(first) || !Number.isInteger(last) || first < 1 || last > 18 || first > last) {
  throw new Error('Usage: node eda_wire_regs.mjs [first-ic] [last-ic]');
}

async function execute(code) {
  const response = await fetch(bridgeUrl, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ code }),
    signal: AbortSignal.timeout(120000),
  });
  const body = await response.json();
  if (!response.ok || !body.success) {
    throw new Error(body.error || `Bridge HTTP ${response.status}`);
  }
  return body.result;
}

for (let number = first; number <= last; number++) {
  const result = await execute(`
    const project = await eda.dmt_Project.getCurrentProjectInfo();
    if (project?.uuid !== ${JSON.stringify(projectUuid)}) throw Error('Wrong active project');
    await eda.dmt_EditorControl.openDocument(${JSON.stringify(regPageUuid)});
    const components = await eda.sch_PrimitiveComponent.getAll();
    const device = components.find(item => item.designator === 'U' + ${number});
    if (!device || device.manufacturerId !== '74LVC8T595PWJ') {
      throw Error('Missing or unexpected U' + ${number});
    }
    const pins = await eda.sch_PrimitiveComponent.getAllPinsByPrimitiveId(device.primitiveId);
    if (pins?.length !== 20) throw Error('Unexpected pin count on U' + ${number});
    const pin = number => {
      const found = pins.find(item => item.pinNumber === String(number));
      if (!found) throw Error('Missing pin ' + number);
      return found;
    };
    const wires = await eda.sch_PrimitiveWire.getAll();
    const changes = { flags: 0, wires: 0 };
    const touches = (wire, point) => {
      const line = wire.line.flat(Infinity);
      for (let i = 0; i < line.length; i += 2) {
        if (line[i] === point.x && line[i + 1] === point.y) return true;
      }
      return false;
    };
    async function ensureFlag(kind, net, x, y) {
      const existing = components.find(item => item.componentType === 'netflag'
        && item.net === net && item.x === x && item.y === y);
      if (existing) return;
      const created = await eda.sch_PrimitiveComponent.createNetFlag(kind, net, x, y);
      if (!created) throw Error('Flag creation failed: ' + net);
      components.push(created);
      changes.flags++;
    }
    async function ensureWire(point, net, line) {
      const touching = wires.filter(item => touches(item, point));
      if (touching.some(item => item.net !== net)) {
        throw Error('Pin already on another net: U' + ${number} + '.' + point.pinNumber);
      }
      if (touching.length) return;
      const created = await eda.sch_PrimitiveWire.create(line, net);
      if (!created) throw Error('Wire creation failed: U' + ${number} + '.' + point.pinNumber);
      wires.push(created);
      changes.wires++;
    }
    const pad = value => String(value).padStart(3, '0');
    for (let bit = 0; bit < 8; bit++) {
      const p = pin(bit + 2);
      const net = 'RIS_Q' + pad((${number} - 1) * 8 + bit + 1);
      const x = p.x - 40;
      await ensureWire(p, net, [p.x, p.y, x, p.y]);
    }
    const controls = [
      [19, ${number} === 1 ? 'SER_DATA' : 'CAS_' + String(${number} - 1).padStart(2, '0')],
      [18, 'OE_N'],
      [17, 'LATCH_CLK'],
      [16, 'SHIFT_CLK'],
      [15, 'MR_N'],
      [14, ${number} === 18 ? 'SER_OUT' : 'CAS_' + String(${number}).padStart(2, '0')],
    ];
    for (const [pinNumber, net] of controls) {
      const p = pin(pinNumber);
      const x = p.x + 35;
      await ensureWire(p, net, [p.x, p.y, x, p.y]);
    }
    const b = pin(1);
    await ensureFlag('Power', 'VCC33', b.x - 45, b.y + 25);
    await ensureWire(b, 'VCC33', [b.x, b.y, b.x - 45, b.y, b.x - 45, b.y + 25]);
    const a = pin(20);
    await ensureFlag('Power', 'VADJ', a.x + 45, a.y + 25);
    await ensureWire(a, 'VADJ', [a.x, a.y, a.x + 45, a.y, a.x + 45, a.y + 25]);
    const g10 = pin(10);
    await ensureFlag('Ground', 'GND', g10.x - 45, g10.y - 20);
    await ensureWire(g10, 'GND', [g10.x, g10.y, g10.x - 45, g10.y, g10.x - 45, g10.y - 20]);
    const g11 = pin(11), g12 = pin(12), g13 = pin(13);
    const gx = g11.x + 45, gy = g11.y - 20;
    await ensureFlag('Ground', 'GND', gx, gy);
    await ensureWire(g13, 'GND', [g13.x, g13.y, gx, g13.y, gx, g12.y, gx, g11.y, gx, gy]);
    await ensureWire(g11, 'GND', [g11.x, g11.y, gx, g11.y]);
    await ensureWire(g12, 'GND', [g12.x, g12.y, gx, g12.y]);
    const saved = await eda.sch_Document.save();
    if (!saved) throw Error('Save failed after U' + ${number});
    return { device: device.designator, ...changes, saved };
  `);
  console.log(JSON.stringify(result));
}
