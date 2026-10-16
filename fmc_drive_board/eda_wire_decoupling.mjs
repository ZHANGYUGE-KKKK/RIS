const projectUuid = 'd768405f3cf385653a0efebe129dc81b63e17bd4dd003b720884b540bb02d0cf';
const powerPageUuid = 'ed4c09b31710665c';
const deviceUuid = 'a6a004d0f4617006';
const first = Number(process.argv[2] ?? 1);
const last = Number(process.argv[3] ?? 18);
if (!Number.isInteger(first) || !Number.isInteger(last) || first < 1 || last > 18 || first > last) {
  throw new Error('Usage: node eda_wire_decoupling.mjs [first-ic] [last-ic]');
}

async function execute(code) {
  const response = await fetch('http://127.0.0.1:49620/execute', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ code }),
    signal: AbortSignal.timeout(120000),
  });
  const body = await response.json();
  if (!response.ok || !body.success) throw new Error(body.error || `Bridge HTTP ${response.status}`);
  return body.result;
}

for (let number = first; number <= last; number++) {
  const result = await execute(`
    const project = await eda.dmt_Project.getCurrentProjectInfo();
    if (project?.uuid !== ${JSON.stringify(projectUuid)}) throw Error('Wrong active project');
    await eda.dmt_EditorControl.openDocument(${JSON.stringify(powerPageUuid)});
    const components = await eda.sch_PrimitiveComponent.getAll();
    const wires = await eda.sch_PrimitiveWire.getAll();
    const library = await eda.lib_Device.search('C14663', undefined, undefined, undefined, 10, 1);
    const item = library.find(value => value.supplierId === 'C14663'
      && value.description.includes('100nF') && value.footprintName === 'C0603');
    if (!item) throw Error('C14663 library device unavailable');
    const slot = (${number} - 1) % 9;
    const group = Math.floor((${number} - 1) / 9);
    const x = 110 + 115 * slot;
    const rows = [
      { designator: 'C' + (2 * ${number} - 1), y: 640 - 240 * group, net: 'VADJ' },
      { designator: 'C' + (2 * ${number}), y: 520 - 240 * group, net: 'VCC33' },
    ];
    const changes = { created: 0, flags: 0, wires: 0 };
    const touches = (wire, pin) => {
      const line = wire.line.flat(Infinity);
      for (let i = 0; i < line.length; i += 2) {
        if (line[i] === pin.x && line[i + 1] === pin.y) return true;
      }
      return false;
    };
    async function ensureFlag(kind, net, x, y) {
      if (components.some(value => value.componentType === 'netflag'
        && value.net === net && value.x === x && value.y === y)) return;
      const flag = await eda.sch_PrimitiveComponent.createNetFlag(kind, net, x, y);
      if (!flag) throw Error('Flag creation failed: ' + net);
      components.push(flag);
      changes.flags++;
    }
    async function ensureWire(pin, net, targetY) {
      const touching = wires.filter(value => touches(value, pin));
      if (touching.some(value => value.net !== net)) throw Error('Capacitor pin on wrong net');
      if (touching.length) return;
      const wire = await eda.sch_PrimitiveWire.create([pin.x, pin.y, pin.x, targetY], net);
      if (!wire) throw Error('Capacitor wire creation failed');
      wires.push(wire);
      changes.wires++;
    }
    for (const row of rows) {
      let capacitor = components.find(value => value.designator === row.designator);
      if (!capacitor) {
        capacitor = await eda.sch_PrimitiveComponent.create(item, x, row.y);
        if (!capacitor) throw Error('Capacitor creation failed: ' + row.designator);
        capacitor = await eda.sch_PrimitiveComponent.modify(capacitor.primitiveId,
          { designator: row.designator, rotation: 90 });
        if (!capacitor) throw Error('Capacitor naming failed: ' + row.designator);
        components.push(capacitor);
        changes.created++;
      }
      if (capacitor.component?.uuid !== ${JSON.stringify(deviceUuid)}
        || capacitor.x !== x || capacitor.y !== row.y || capacitor.rotation !== 90) {
        throw Error('Capacitor position or model differs: ' + row.designator);
      }
      capacitor = await eda.sch_PrimitiveComponent.modify(capacitor.primitiveId, {
        supplierId: 'C14663',
        otherProperty: {
          'LCSC Part Name': '100nF 10% 50V',
          'Supplier Footprint': '0603',
          'JLCPCB Part Class': 'Basic Part',
          Datasheet: 'https://item.szlcsc.com/datasheet/CC0603KRX7R9BB104/15331.html',
          Value: '100nF',
          Tolerance: '10%',
          'Voltage Rating': '50V',
          'Temperature Coefficient': 'X7R',
        },
      });
      if (!capacitor) throw Error('Capacitor value update failed: ' + row.designator);
      const pins = await eda.sch_PrimitiveComponent.getAllPinsByPrimitiveId(capacitor.primitiveId);
      const top = pins.find(value => value.pinNumber === '2');
      const bottom = pins.find(value => value.pinNumber === '1');
      if (!top || !bottom || top.y <= bottom.y) throw Error('Unexpected capacitor pin orientation');
      await ensureFlag('Power', row.net, x, row.y + 50);
      await ensureFlag('Ground', 'GND', x, row.y - 50);
      await ensureWire(top, row.net, row.y + 50);
      await ensureWire(bottom, 'GND', row.y - 50);
    }
    if (!(await eda.sch_Document.save())) throw Error('Save failed after U' + ${number});
    return { forRegister: 'U' + ${number}, ...changes };
  `);
  console.log(JSON.stringify(result));
}
