"""Mapping invariants and data integrity; no physical wiring order is assumed."""
import csv
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "host"))
from ris_mapping import (GEOMETRY, LEGACY_WIRING_PROFILE, PORTS, WIRING_PROFILE,
                         RisMapping, adapter_terminal, cell_port, fpc_probe_command,
                         pin_trace, probe_command, source, wired_cell)


class MappingTests(unittest.TestCase):
    def test_source_and_single_bit_probe_at_every_output(self):
        seen = set()
        for fpc in range(1, 11):
            for channel in range(1, 41):
                info = source(fpc, channel)
                seen.add((info["chip"], info["bit"]))
                frame = bytes.fromhex(probe_command(fpc, channel).split()[1])
                self.assertEqual(len(frame), 50)
                self.assertEqual(sum(v.bit_count() for v in frame), 1)
                self.assertEqual(frame[info["chip"]], 1 << info["bit"])
        self.assertEqual(len(seen), 400)
        self.assertEqual(source(10, 40), {"output": 400, "chip": 49, "reference": "U53", "bit": 7})
        for fpc in range(1, 11):
            frame = bytes.fromhex(fpc_probe_command(fpc).split()[1])
            self.assertEqual(frame[(fpc-1)*5:fpc*5], b"\xff" * 5)
            self.assertEqual(sum(value.bit_count() for value in frame), 40)

    def test_no_guessed_connections(self):
        model = RisMapping()
        self.assertEqual(model.ports, {})
        self.assertEqual(model.channels, {})
        with self.assertRaises(ValueError):
            model.assign(1, 1, 1, 1)

    def test_arbitrary_fpc_order_and_conflicts(self):
        model = RisMapping()
        model.bind(8, "T1")
        model.assign(8, 40, 10, 4, True)
        model.assign(8, 1, 1, 1)
        self.assertEqual(model.at(10, 4), (8, 40))
        self.assertEqual(model.count(verified=True), 1)
        for action in (lambda: model.bind(1, "T1"), lambda: model.bind(8, "B1"),
                       lambda: model.assign(8, 2, 1, 1), lambda: model.assign(8, 2, 11, 1)):
            before = model.document()
            with self.assertRaises(ValueError):
                action()
            self.assertEqual(model.document(), before)
        model.unbind(8)
        self.assertEqual(model.count(), 0)
        model.bind(1, "T1")

    def test_all_400_cells_roundtrip_and_csv(self):
        # Artificial test fixture, deliberately reversing FPC order.
        model = RisMapping()
        for fpc, port in zip(range(10, 0, -1), PORTS):
            model.bind(fpc, port)
            top = 1 if port[0] == "T" else 11
            left = (int(port[1]) - 1) * 4 + 1
            for channel in range(1, 41):
                row, col = divmod(channel - 1, 4)
                model.assign(fpc, channel, top + row, left + col, True)
        self.assertEqual(model.count(), 400)
        self.assertEqual(model.count(verified=True), 400)
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "map.json"
            model.save(path)
            loaded = RisMapping.load(path)
            self.assertEqual(loaded.document(), model.document())
            csv_path = Path(folder) / "map.csv"
            loaded.export_csv(csv_path)
            with csv_path.open(encoding="utf-8-sig", newline="") as stream:
                rows = list(csv.DictReader(stream))
            self.assertEqual(len(rows), 400)
            self.assertEqual(rows[0]["FPC"], "1")
            self.assertEqual(rows[-1]["logical_channel"], "40")
            self.assertFalse(list(Path(folder).glob("*.tmp")))

    def test_partial_mapping_roundtrip_and_invalid_files(self):
        model = RisMapping()
        model.bind(1, "T2")
        model.assign(1, 3, 2, 6)
        doc = model.document()
        self.assertEqual(RisMapping.from_document(doc).document(), doc)
        for field, value in (("row", 0), ("column", 21), ("fpc", True), ("channel", 41), ("verified", "true")):
            broken = json.loads(json.dumps(doc))
            broken["channels"][0][field] = value
            with self.assertRaises(ValueError):
                RisMapping.from_document(broken)
        broken = json.loads(json.dumps(doc))
        broken["channels"].append(dict(broken["channels"][0]))
        with self.assertRaises(ValueError):
            RisMapping.from_document(broken)
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "bad.json"
            path.write_text('{"format":"RIS-FPC-MAPPING","format":"other"}')
            with self.assertRaises(ValueError):
                RisMapping.load(path)
        self.assertEqual(cell_port(10, 20), "T5")
        self.assertEqual(cell_port(11, 1), "B1")
        self.assertEqual(GEOMETRY["rows"] * GEOMETRY["columns"], 400)

    def test_confirmed_adapter_pins_and_front_view_corners(self):
        # Independent anchors from the supplied adapter diagram and mounting view.
        terminals = {1: ("U4", 10, 60), 10: ("U4", 1, 47), 11: ("U3", 10, 45),
                     20: ("U3", 1, 32), 21: ("U2", 10, 30), 30: ("U2", 1, 17),
                     31: ("U1", 10, 15), 40: ("U1", 1, 2)}
        for channel, expected in terminals.items():
            info = adapter_terminal(channel)
            self.assertEqual((info["header"], info["header_pin"], info["fpc_pin"]), expected)
        for channel, top, bottom in ((1, (1, 1), (20, 4)), (10, (10, 1), (11, 4)),
                                     (31, (1, 4), (20, 1)), (40, (10, 4), (11, 1))):
            self.assertEqual(wired_cell("T1", channel), top)
            self.assertEqual(wired_cell("B1", channel), bottom)
        all_cells = {wired_cell(port, channel) for port in PORTS for channel in range(1, 41)}
        self.assertEqual(all_cells, {(row, col) for row in range(1, 21) for col in range(1, 21)})
        trace = pin_trace(1, 10)
        self.assertEqual((trace["reference"], trace["bit"], trace["chip_pin"], trace["fpc_pin"]), ("U5", 1, 3, 47))
        last = pin_trace(10, 40)
        self.assertEqual((last["reference"], last["chip_pin"], last["control_net"], last["adapter_net"]),
                         ("U53", 9, "RIS_Q400", "RIS_Q040"))
        self.assertEqual({adapter_terminal(ch)["fpc_pin"] for ch in range(1, 41)},
                         set(range(1, 61)) - set(range(1, 61, 3)))

    def test_wiring_generation_preserves_measurements_and_is_atomic(self):
        model = RisMapping()
        model.bind_wiring(6, "B1")
        self.assertEqual(model.count(), 40)
        self.assertEqual(model.count(verified=True), 0)
        self.assertEqual(model.at(20, 4), (6, 1))
        self.assertEqual(model.pending(6), list(range(1, 41)))
        model.assign(6, 1, 20, 4, True)
        record = dict(model.channels[6, 1])
        model.generate_wiring()
        self.assertEqual(model.channels[6, 1], record)
        self.assertNotIn(1, model.pending(6))
        model.bind(1, "T1")
        model.assign(1, 1, 10, 1, True)  # A pre-existing manual map disagrees.
        before = model.document()
        with self.assertRaises(ValueError):
            model.generate_wiring()
        self.assertEqual(model.document(), before)
        self.assertEqual(model.channels[1, 1]["verified"], True)

    def test_wiring_files_roundtrip_legacy_import_and_pin_csv(self):
        model = RisMapping()
        for fpc, port in zip(range(10, 0, -1), PORTS):
            model.bind_wiring(fpc, port)
        self.assertEqual(model.count(), 400)
        self.assertEqual(model.count(verified=True), 0)
        self.assertEqual(RisMapping.from_document(model.document()).document(), model.document())
        with tempfile.TemporaryDirectory() as folder:
            csv_path = Path(folder) / "pins.csv"
            model.export_csv(csv_path)
            with csv_path.open(encoding="utf-8-sig", newline="") as stream:
                rows = list(csv.DictReader(stream))
            row = next(row for row in rows if row["FPC"] == "10" and row["logical_channel"] == "10")
            self.assertEqual((row["row"], row["column"], row["reference"], row["Q"], row["chip_pin"], row["FPC_pin"]),
                             ("10", "1", "U50", "1", "3", "47"))
            self.assertEqual((row["adapter_header"], row["header_pin"], row["basis"], row["verified"]),
                             ("U4", "1", "wiring", "0"))
        manual = RisMapping()
        manual.bind(1, "T1")
        manual.assign(1, 1, 1, 1, True)
        legacy = manual.document()
        legacy["version"] = 1
        del legacy["wiring_profile"]
        del legacy["channels"][0]["basis"]
        imported = RisMapping.from_document(legacy)
        self.assertEqual(imported.count(), 1)
        self.assertTrue(imported.channels[1, 1]["verified"])
        self.assertEqual(imported.channels[1, 1]["basis"], "manual")
        broken = model.document()
        broken["channels"][0]["row"] = 9
        with self.assertRaises(ValueError):
            RisMapping.from_document(broken)

    def test_old_generated_json_flips_rows_in_each_half_once_and_retains_columns(self):
        # Independent fixture for the old implementation, including arbitrary FPC order.
        old = RisMapping().document()
        old["wiring_profile"] = LEGACY_WIRING_PROFILE
        old["notes"] = "operator wiring"
        for fpc, port in zip(range(10, 0, -1), PORTS):
            old["ports"][str(fpc)] = port
            for channel in range(1, 41):
                column_group, offset = divmod(channel - 1, 10)
                row = 10 - offset if port.startswith("T") else 11 + offset
                column = (int(port[1]) - 1) * 4 + (column_group + 1 if port.startswith("T") else 4 - column_group)
                old["channels"].append({"fpc": fpc, "channel": channel, "row": row, "column": column,
                                        "verified": True, "basis": "wiring"})
        before = json.loads(json.dumps(old))
        fixed = RisMapping.from_document(old)
        self.assertEqual(old, before)
        self.assertEqual(fixed.count(), 400)
        self.assertEqual(fixed.count(verified=True), 0)
        self.assertEqual(fixed.notes, "operator wiring")
        self.assertEqual({str(k): v for k, v in fixed.ports.items()}, old["ports"])
        for previous in old["channels"]:
            entry = fixed.channels[previous["fpc"], previous["channel"]]
            expected_row = 11 - previous["row"] if previous["row"] <= 10 else 31 - previous["row"]
            self.assertEqual((entry["row"], entry["column"]), (expected_row, previous["column"]))
        self.assertEqual(fixed.channels[10, 10]["row"], 10)  # Old top row1 is physically row10.
        self.assertEqual(fixed.channels[5, 10]["row"], 11)   # Old bottom row20 is physically row11.
        self.assertEqual(fixed.document()["wiring_profile"], WIRING_PROFILE)
        reloaded = RisMapping.from_document(fixed.document())
        self.assertEqual(reloaded.document(), fixed.document())
        self.assertEqual(reloaded.migration_message, "")

    def test_legacy_migration_keeps_manual_measurements_and_rejects_conflicts(self):
        old = RisMapping().document()
        old["wiring_profile"] = LEGACY_WIRING_PROFILE
        old["ports"] = {"1": "T1"}
        old["channels"] = [
            {"fpc": 1, "channel": 1, "row": 10, "column": 1, "verified": True, "basis": "wiring"},
            {"fpc": 1, "channel": 2, "row": 4, "column": 1, "verified": True, "basis": "manual"}]
        fixed = RisMapping.from_document(old)
        self.assertEqual(fixed.channels[1, 1], {"row": 1, "column": 1, "verified": False, "basis": "wiring"})
        self.assertEqual(fixed.channels[1, 2], {"row": 4, "column": 1, "verified": True, "basis": "manual"})
        for bad_row in (1, 10):  # Migration conflict and duplicate cell in original file.
            broken = json.loads(json.dumps(old))
            broken["channels"][1]["row"] = bad_row
            with self.assertRaises(ValueError):
                RisMapping.from_document(broken)
        broken = json.loads(json.dumps(old))
        broken["channels"][0]["row"] = 9  # Invalid even under the old wiring profile.
        with self.assertRaises(ValueError):
            RisMapping.from_document(broken)
        broken = json.loads(json.dumps(old))
        broken["wiring_profile"] = "wrong_mounting_direction"
        with self.assertRaises(ValueError):
            RisMapping.from_document(broken)


if __name__ == "__main__":
    unittest.main()
