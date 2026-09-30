"""Repair role diagnostics from saved inspection data, without rescanning sources.

Rig hashes and take IDs retain their original inspection identity. Role metadata
is a versioned interpretation; it does not change a skeleton or approve a clip.
"""
import json
from pathlib import Path

from bone_roles import CRITICAL_ROLES, role, role_indices
from inventory import write_json


def refresh(base):
    counts = {"inspections": 0, "repaired_takes": 0, "takes": 0, "approved": 0}
    statuses = {}
    for path in sorted((base / "inspections").glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        statuses[data["file_sha256"]] = data["status"]
        for rig in data.get("rigs", []):
            for bone in rig["bones"]:
                bone["role"] = role(bone["name"])
        for take in data["takes"]:
            rig = next(r for r in data["rigs"] if r["hash"] == take["rig_hash"])
            indices = role_indices([b["name"] for b in rig["bones"]])
            missing = sorted(CRITICAL_ROLES - indices.keys())
            if missing != take["metrics"]["missing_roles"]:
                counts["repaired_takes"] += 1
            take["metrics"]["missing_roles"] = missing
            counts["takes"] += 1
        data["role_interpretation_version"] = 2
        write_json(path, data)
        counts["inspections"] += 1
    path = base / "SourceInventory.json"
    inventory = json.loads(path.read_text(encoding="utf-8"))
    for entry in inventory["files"]:
        if entry["sha256"] in statuses:
            entry["inspection_status"] = statuses[entry["sha256"]]
    write_json(path, inventory)
    return counts


if __name__ == "__main__":
    print(json.dumps(refresh(Path.cwd() / "art/production/master-animation-library/manifests")))
