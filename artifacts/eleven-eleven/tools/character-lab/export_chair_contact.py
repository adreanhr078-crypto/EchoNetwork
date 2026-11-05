"""Export the exact inspected School65 chair-contact blend into the review case."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import bpy


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--review", required=True, type=Path)
parser.add_argument("--output", required=True, type=Path)
args = parser.parse_args(sys.argv[sys.argv.index("--")+1:])
case = args.review.resolve().parent
report = json.loads((case/"blender-contact.json").read_text(encoding="utf-8"))
visual = json.loads(args.review.read_text(encoding="utf-8"))
blend = case/"authored-contact.blend"
assert visual["status"] == "PASS_SCOPED_SEATED_CONTACT"
assert sha(blend) == visual["blend_sha256"] == report["blend_sha256"]
assert all(sha(case/name) == expected for name, expected in visual["captures"].items())
assert all(report[k] for k in ("anchor_numeric_pass", "ankle_angle_numeric_pass",
                               "horizontal_support_numeric_pass", "back_support_numeric_pass"))
assert len(report["frames"]) == 61 and report["fps"] == 30
assert args.output.suffix.lower() == ".glb" and not args.output.exists()
assert "/golden/" not in args.output.resolve().as_posix().lower()
bpy.ops.wm.open_mainfile(filepath=str(blend))
rig = next(o for o in bpy.context.selected_objects if o.type == "ARMATURE")
body = next(o for o in bpy.context.selected_objects if o.type == "MESH")
assert len(rig.data.bones) == 65 and rig.animation_data.action.name == "RestrainedBreath"
assert len(bpy.context.selected_objects) == 2 and any(m.object == rig for m in body.modifiers if m.type == "ARMATURE")
bpy.ops.export_scene.gltf(filepath=str(args.output), export_format="GLB", use_selection=True,
                           export_materials="NONE", export_animations=True,
                           export_animation_mode="ACTIVE_ACTIONS", export_force_sampling=True,
                           export_optimize_animation_size=False, export_frame_range=True)
assert sha(blend) == report["blend_sha256"]
evidence = {"status":"EXPORTED_SCOPED_CONTACT_REVIEW", "output_sha256":sha(args.output),
            "blend_sha256":sha(blend), "exact_visual_record_sha256":sha(args.review),
            "blender_numeric_record_sha256":sha(case/"blender-contact.json"),
            "export_scope":"Body mesh, original 65-joint bind and one authored clip. Review uses source materials and chair."}
args.output.with_suffix(".export.json").write_text(json.dumps(evidence,indent=2)+"\n",encoding="utf-8")
print(json.dumps(evidence))
