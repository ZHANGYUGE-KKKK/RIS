#!/usr/bin/env python3
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / "reports/migration/original_sources.sha256.json").read_text())
application_manifest = root / "reports/rx_external_test/application_sources.sha256.json"
expected_application = json.loads(application_manifest.read_text()) if application_manifest.exists() else {}
changed = []
application_updates = []
for name, digest in manifest.items():
    if name.startswith("vitis_code/key_ctrlll/src/"):
        path = root / "software/src" / name.removeprefix("vitis_code/key_ctrlll/src/")
    else:
        path = root / name
    if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
        changed.append(name)
    app = root / name
    if name.startswith("vitis_code/") and app.exists():
        if hashlib.sha256(app.read_bytes()).hexdigest() != digest:
            if hashlib.sha256(app.read_bytes()).hexdigest() == expected_application.get(name):
                application_updates.append(name)
            else:
                changed.append(str(app))
if expected_application:
    current_application = {
        str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in (root / "vitis_code/key_ctrlll/src").rglob("*") if path.is_file()
    }
    if current_application != expected_application:
        changed.append("application differs from the validated external-RX source manifest")
old = json.loads((root / "reports/migration/original_bd.json").read_text())["design"]
new = json.loads((root / "PZ_UART.srcs/sources_1/bd/design_1/design_1.bd").read_text())["design"]
def nets(design):
    return {name: sorted(net["ports"]) for name, net in design["nets"].items()}
checks = dict(
    unchanged_source_files=len(manifest), changed_sources=changed,
    documented_application_updates=application_updates,
    additional_application_sources=sorted(set(expected_application) - set(manifest)),
    same_cells=set(old["components"]) == set(new["components"]),
    same_connections=nets(old) == nets(new),
    same_axi_connections=old["interface_nets"] == new["interface_nets"],
    same_address_map=old["addressing"] == new["addressing"],
)
for name in ("ad9361_rx_axis_0", "axi_dma_0", "axis_data_fifo_0", "axi_gpio_9361", "axi_gpio_ris_ctl", "key_ctrl_55_0"):
    checks[f"same_parameters_{name}"] = old["components"][name].get("parameters") == new["components"][name].get("parameters")
(root / "reports/migration/integrity.json").write_text(json.dumps(checks, indent=2) + "\n")
assert not changed and all(value for key, value in checks.items() if key.startswith("same_")), checks
print(json.dumps(checks, indent=2))
