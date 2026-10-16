const projectUuid = 'd768405f3cf385653a0efebe129dc81b63e17bd4dd003b720884b540bb02d0cf';
const fmcPageUuid = 'cf67416c66763eed';

const code = `
  const project = await eda.dmt_Project.getCurrentProjectInfo();
  if (project?.uuid !== ${JSON.stringify(projectUuid)}) throw Error('Wrong active project');
  await eda.dmt_EditorControl.openDocument(${JSON.stringify(fmcPageUuid)});
  const components = await eda.sch_PrimitiveComponent.getAll();
  const wires = await eda.sch_PrimitiveWire.getAll();
  const capacitors = await eda.lib_Device.search('C15850', undefined, undefined, undefined, 10, 1);
  const resistors = await eda.lib_Device.search('C25804', undefined, undefined, undefined, 10, 1);
  const capItem = capacitors.find(item => item.supplierId === 'C15850'
    && item.description.includes('10uF') && item.footprintName === 'C0805');
  const resistorItem = resistors.find(item => item.supplierId === 'C25804'
    && item.description.includes('10k') && item.footprintName === 'R0603');
  if (!capItem || !resistorItem) throw Error('Bulk capacitor or pull-up resistor unavailable');
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
    const pins = await eda.sch_PrimitiveComponent.getAllPinsByPrimitiveId(component.primitiveId);
    if (pins?.length !== 2) throw Error('Unexpected pin count: ' + designator);
    return { top: pins.reduce((a, b) => a.y > b.y ? a : b),
      bottom: pins.reduce((a, b) => a.y < b.y ? a : b) };
  }
  async function ensureFlag(kind, net, x, y) {
    if (components.some(item => item.componentType === 'netflag'
      && item.net === net && item.x === x && item.y === y)) return;
    const flag = await eda.sch_PrimitiveComponent.createNetFlag(kind, net, x, y);
    if (!flag) throw Error('Flag creation failed: ' + net);
    components.push(flag);
    changes.flags++;
  }
  async function ensureWire(pin, net, targetY) {
    const touches = wire => {
      const line = wire.line.flat(Infinity);
      for (let i = 0; i < line.length; i += 2) {
        if (line[i] === pin.x && line[i + 1] === pin.y) return true;
      }
      return false;
    };
    const existing = wires.filter(touches);
    if (existing.some(wire => wire.net !== net)) throw Error('Pin on wrong net: ' + net);
    if (existing.length) return;
    const wire = await eda.sch_PrimitiveWire.create([pin.x, pin.y, pin.x, targetY], net);
    if (!wire) throw Error('Wire creation failed: ' + net);
    wires.push(wire);
    changes.wires++;
  }
  const bulkProperties = {
    'LCSC Part Name': '10uF 10% 25V',
    'Supplier Footprint': '0805',
    'JLCPCB Part Class': 'Basic Part',
    Datasheet: 'https://item.szlcsc.com/datasheet/CL21A106KAYNNNE/16532.html',
    Value: '10uF', Tolerance: '10%', 'Voltage Rating': '25V',
    'Temperature Coefficient': 'X5R',
  };
  for (const [designator, x, net] of [['C37', 650, 'VADJ'], ['C38', 850, 'VCC33']]) {
    const p = await ensurePart(designator, capItem, x, 950, 'C15850', bulkProperties);
    await ensureFlag('Power', net, x, 1000);
    await ensureFlag('Ground', 'GND', x, 900);
    await ensureWire(p.top, net, 1000);
    await ensureWire(p.bottom, 'GND', 900);
  }
  const resistorProperties = {
    'LCSC Part Name': '10k 1% 100mW',
    'Supplier Footprint': '0603',
    'JLCPCB Part Class': 'Basic Part',
    Datasheet: 'https://item.szlcsc.com/datasheet/0603WAF1002T5E/26547.html',
    Value: '10k', Tolerance: '1%', 'Power(Watts)': '100mW',
  };
  for (const [designator, x, net] of [['R1', 650, 'OE_N'], ['R2', 850, 'MR_N']]) {
    const p = await ensurePart(designator, resistorItem, x, 700, 'C25804', resistorProperties);
    await ensureFlag('Power', 'VADJ', x, 750);
    await ensureWire(p.top, 'VADJ', 750);
    await ensureWire(p.bottom, net, 640);
  }
  if (!(await eda.sch_Document.save())) throw Error('FMC support save failed');
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
