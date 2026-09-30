"""Measured comparison evidence for inspected animation candidates; never auto-approves."""
import collections
import json
from pathlib import Path

import numpy as np
from bone_roles import normalize, role_indices
from contact_metrics import measure_contacts


def main():
    root = Path.cwd()
    base = root / "art/production/master-animation-library/manifests"
    inventory = json.loads((base / "SourceInventory.json").read_text(encoding="utf-8"))
    source_by_hash = collections.defaultdict(list)
    for entry in inventory["files"]:
        source_by_hash[entry["sha256"]].append(entry)
    results = []
    for path in sorted((base / "inspections").glob("*.json")):
        inspection = json.loads(path.read_text(encoding="utf-8"))
        for take in inspection["takes"]:
            cache = Path(take["pose_cache"])
            if not cache.exists():
                continue
            with np.load(cache) as data:
                positions = data["positions"]
                rotations = data["rotations"]
                names = data["bone_names"].tolist()
                fps = float(data["fps"][0])
            roles = role_indices(names)
            issues = []
            foot_metrics = measure_contacts(positions, roles, fps)
            if not foot_metrics:
                issues.append("insufficient_primary_foot_contact_evidence")
            hip = roles.get("hips")
            if hip is not None and len(positions) > 1:
                relative = positions - positions[:, hip:hip+1]
                seam_position = float(np.median(np.linalg.norm(relative[0]-relative[-1], axis=1)))
                hip_displacement = float(np.linalg.norm(positions[-1, hip, :2] - positions[0, hip, :2]))
            else:
                seam_position = None
                hip_displacement = None
                issues.append("missing_hips")
            if len(rotations) > 1:
                qdots = np.abs(np.sum(rotations[0]*rotations[-1], axis=1))
                seam_rotation = float(np.median(2*np.arccos(np.clip(qdots,0,1))))
            else:
                seam_rotation = None
            members = source_by_hash[inspection["file_sha256"]]
            pack = members[0]["source_pack"] if members else "unknown"
            filename = members[0]["original_filename"] if members else path.name
            results.append({"take_id":take["take_id"], "file_sha256":inspection["file_sha256"],
                            "original_filename":filename, "source_pack":pack, "fps":fps,
                            "duration_seconds":take["duration_seconds"], "frames":len(positions),
                            "bone_count":len(names), "finger_bones":sum(any(d in normalize(n) for d in ("thumb","index","pinky","middle","ring")) for n in names),
                            "hip_displacement_xy_m":hip_displacement,
                            "loop_seam_median_relative_position_m":seam_position,
                            "loop_seam_median_rotation_rad":seam_rotation,
                            "foot_contact":foot_metrics, "issues":issues,
                            "pose_fingerprint":take.get("metrics",{}).get("pose_fingerprint"),
                            "status":"measured_not_visually_approved"})
    output = {"schema_version":1,"status":"comparison_evidence_only","notes":
              "Contact requires near-ground and low compensated velocity; low residual supports review, never proof or approval.",
              "takes":results}
    (base / "MotionMetrics.json").write_text(json.dumps(output,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
    print(json.dumps({"takes_measured":len(results),"approved":0}))


if __name__ == "__main__":
    main()
