const projectUuid = 'd768405f3cf385653a0efebe129dc81b63e17bd4dd003b720884b540bb02d0cf';
const fmcPageUuid = 'cf67416c66763eed';

const code = `
  const project = await eda.dmt_Project.getCurrentProjectInfo();
  if (project?.uuid !== ${JSON.stringify(projectUuid)}) throw Error('Wrong active project');
  await eda.dmt_EditorControl.openDocument(${JSON.stringify(fmcPageUuid)});
  const components = await eda.sch_PrimitiveComponent.getAll();
  const wires = await eda.sch_PrimitiveWire.getAll();
  const ledItem = (await eda.lib_Device.search('C84256', undefined, undefined, undefined, 10, 1))
    .find(item => item.supplierId === 'C84256' && item.name === 'NCD0805R1');
  const resistorItem = (await eda.lib_Device.search('C21190', undefined, undefined, undefined, 10, 1))
    .find(item => item.supplierId === 'C21190' && item.name === '0603WAF1001T5E');
  if (!ledItem || !resistorItem) throw Error('LED or resistor library device unavailable');
  const changes = { created: 0, flags: 0, wires: 0 };
  async function ensurePart(designator, item, x, y, supplierId, otherProperty) {
    let component = components.find(value => value.designator === designator);
    if (!component) {
      component = await eda.sch_PrimitiveComponent.create(item, x, y);
      if (!component) throw Error('Creation failed: ' + designator);
      component = await eda.sch_PrimitiveComponent.modify(component.primitiveId,
        { designator, rotation: 90 });
      if (!component) throw Error('Naming failed: ' + designator);
      components.push(component);
      changes.created++;
    }
    if (component.component?.name !== item.name
      || component.x !== x || component.y !== y || component.rotation !== 90) {
      throw Error('Unexpected component: ' + designator);
    }
    component = await eda.sch_PrimitiveComponent.modify(component.primitiveId,
      { supplierId, otherProperty });
    if (!component) throw Error('Value update failed: ' + designator);
    return await eda.sch_PrimitiveComponent.getAllPinsByPrimitiveId(component.primitiveId);
  }
  async function ensureFlag(net, x, y) {
    if (components.some(item => item.componentType === 'netflag'
      && item.net === net && item.x === x && item.y === y)) return;
    const flag = await eda.sch_PrimitiveComponent.createNetFlag('Power', net, x, y);
    if (!flag) throw Error('Flag creation failed');
    components.push(flag);
    changes.flags++;
  }
  const touches = (wire, pin) => {
    const line = wire.line.flat(Infinity);
    for (let i = 0; i < line.length; i += 2) {
      if (line[i] === pin.x && line[i + 1] === pin.y) return true;
    }
    return false;
  };
  async function ensureWire(pin, net, targetY) {
    const existing = wires.filter(wire => touches(wire, pin));
    if (existing.some(wire => wire.net !== net)) throw Error('Pin on wrong net: ' + net);
    if (existing.length) return;
    const wire = await eda.sch_PrimitiveWire.create([pin.x, pin.y, pin.x, targetY], net);
    if (!wire) throw Error('Wire creation failed: ' + net);
    wires.push(wire);
    changes.wires++;
  }
  const resistorProperties = {
    'LCSC Part Name': '1k 1% 100mW',
    'Supplier Footprint': '0603',
    'JLCPCB Part Class': 'Basic Part',
    Datasheet: 'https://item.szlcsc.com/datasheet/0603WAF1001T5E/21904.html',
    Value: '1k', Tolerance: '1%', 'Power(Watts)': '100mW',
  };
  for (let n = 1; n <= 3; n++) {
    const x = 1050 + 200 * (n - 1);
    const ledPins = await ensurePart('LED' + n, ledItem, x, 650, 'C84256', {
      'LCSC Part Name': 'Red LED 0805',
      'Supplier Footprint': '0805',
      'JLCPCB Part Class': 'Basic Part',
      Datasheet: 'https://item.szlcsc.com/datasheet/NCD0805R1/85425.html',
      'Illumination Color': 'Red',
    });
    const anode = ledPins.find(pin => pin.pinNumber === '2');
    const cathode = ledPins.find(pin => pin.pinNumber === '1');
    if (!anode || !cathode || anode.y <= cathode.y) throw Error('LED polarity wrong: LED' + n);
    const resistorPins = await ensurePart('R' + (n + 2), resistorItem,
      x, 760, 'C21190', resistorProperties);
    const top = resistorPins.reduce((a, b) => a.y > b.y ? a : b);
    const bottom = resistorPins.reduce((a, b) => a.y < b.y ? a : b);
    await ensureFlag('VADJ', x, 810);
    await ensureWire(top, 'VADJ', 810);
    await ensureWire(bottom, 'LED' + n + '_A', anode.y);
    await ensureWire(cathode, 'LED' + n + '_N', 590);
  }
  if (!(await eda.sch_Document.save())) throw Error('LED reserve save failed');
  return { ...changes, saved: true };
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
