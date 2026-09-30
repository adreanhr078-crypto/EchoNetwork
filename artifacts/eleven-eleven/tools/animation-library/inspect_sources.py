"""Blender batch inspector: all unique readable files/takes, no source writes.

Invoke with Blender --background --python ... -- --app <path> [--limit N].
Each finished file is checkpointed separately so interrupted runs can resume.
Source mechanics measurements are diagnostics, never artistic approval.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import sys
import traceback

sys.path.insert(0, str(Path(__file__).resolve().parent))
from bone_roles import normalize, role

import bpy
import numpy as np


def write_json(path, data):
    temp = path.with_suffix(path.suffix + ".partial")
    temp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temp.replace(path)


def inspect_file(path, digest, destination, pose_dir):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    extension = path.suffix.lower()
    if extension == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(path), use_anim=True)
    elif extension == ".bvh":
        bpy.ops.import_anim.bvh(filepath=str(path), update_scene_fps=True, update_scene_duration=True)
    elif extension in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=str(path))
    elif extension == ".blend":
        bpy.ops.wm.open_mainfile(filepath=str(path))
    else:
        return {"file_sha256": digest, "status": "format_adapter_required", "takes": []}
    rigs = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    result = {"file_sha256": digest, "status": "inspected", "takes": [], "rigs": []}
    for rig in rigs:
        rest = []
        for b in rig.data.bones:
            world = rig.matrix_world @ b.matrix_local
            rest.append({"name": b.name, "parent": b.parent.name if b.parent else None,
                         "world_matrix": [list(row) for row in world], "length": b.length,
                         "role": role(b.name)})
        rig_hash = hashlib.sha256(json.dumps(rest, sort_keys=True).encode()).hexdigest()
        result["rigs"].append({"name": rig.name, "hash": rig_hash, "bones": rest,
                               "object_matrix": [list(row) for row in rig.matrix_world]})
        actions = []
        for action in bpy.data.actions:
            slots = [slot for slot in action.slots if slot.target_id_type == "OBJECT"]
            if not slots:
                continue
            for slot in slots:
                curves = [curve for layer in action.layers for strip in layer.strips
                          for bag in getattr(strip, "channelbags", []) if bag.slot_handle == slot.handle
                          for curve in bag.fcurves]
                has_bone_tracks = any(curve.data_path.startswith("pose.bones[") for curve in curves)
                if has_bone_tracks and (len(rigs) == 1 or rig.name in slot.name_display):
                    actions.append((action, slot))
        if not actions and rig.animation_data and rig.animation_data.action:
            actions = [(rig.animation_data.action, rig.animation_data.action_slot)]
        for take_index, (action, slot) in enumerate(actions):
            rig.animation_data_create()
            rig.animation_data.action = action
            if slot:
                rig.animation_data.action_slot = slot
            first, last = action.frame_range
            fps = bpy.context.scene.render.fps / bpy.context.scene.render.fps_base
            frames = np.arange(math.floor(first), math.ceil(last) + 1, dtype=np.float32)
            # Retain every source frame. Do not infer source quality from sparse samples.
            positions = np.zeros((len(frames), len(rig.data.bones), 3), dtype=np.float32)
            rotations = np.zeros((len(frames), len(rig.data.bones), 4), dtype=np.float32)
            scales = np.zeros_like(positions)
            bone_names = list(rig.data.bones.keys())
            for fi, frame in enumerate(frames):
                bpy.context.scene.frame_set(int(frame))
                for bi, name in enumerate(bone_names):
                    matrix = rig.matrix_world @ rig.pose.bones[name].matrix
                    p, q, s = matrix.decompose()
                    positions[fi, bi] = tuple(p)
                    rotations[fi, bi] = tuple(q)
                    scales[fi, bi] = tuple(s)
            take_id = digest[:24] + ":" + str(take_index) + ":" + rig_hash[:8]
            output = pose_dir / (take_id.replace(":", "_") + ".npz")
            np.savez_compressed(output, frames=frames, positions=positions, rotations=rotations, scales=scales,
                                bone_names=np.array(bone_names), fps=np.array([fps]),
                                rest=np.array([b["world_matrix"] for b in rest], dtype=np.float32))
            index = {b["role"]: i for i, b in enumerate(rest) if b["role"]}
            metrics = {"finite": bool(np.isfinite(positions).all() and np.isfinite(rotations).all()),
                       "bone_count": len(bone_names), "source_scale_min": float(scales.min()),
                       "source_scale_max": float(scales.max()), "missing_roles": sorted(set(["hips", "head", "left_foot", "right_foot", "left_knee", "right_knee"]) - set(index))}
            if "hips" in index:
                hips = positions[:, index["hips"]]
                metrics["hips_net_horizontal_displacement_source_units"] = float(np.linalg.norm((hips[-1] - hips[0])[:2]))
                # Root-relative positions normalize semantic motion fingerprints, not quality scores.
                relative = positions - hips[:, None, :]
                pick = np.linspace(0, len(frames) - 1, min(60, len(frames))).astype(int)
                metrics["pose_fingerprint"] = hashlib.sha256(np.round(relative[pick], 3).tobytes()).hexdigest()
            result["takes"].append({"take_id": take_id, "source_take": action.name,
                 "slot": slot.name_display if slot else None, "rig": rig.name, "rig_hash": rig_hash,
                 "source_frame_range": [float(first), float(last)], "sample_frames": len(frames),
                 "fps": fps, "fps_evidence": "Blender source importer scene rate; source metadata verification pending",
                 "duration_seconds": float((last - first) / fps), "pose_cache": str(output),
                "metrics": metrics, "approval_status": "unreviewed"})
    if not result["takes"]:
        result["status"] = "scene_without_animation"
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--only", action="append", default=[], help="Exact SHA-256 of a source file to prioritize")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    app = args.app.resolve()
    inventory = json.loads((app / "art/production/master-animation-library/manifests/SourceInventory.json").read_text(encoding="utf-8"))
    output = app / "art/production/master-animation-library/manifests/inspections"
    output.mkdir(parents=True, exist_ok=True)
    poses = app / ".tmp/master-animation-library/poses"
    poses.mkdir(parents=True, exist_ok=True)
    seen = set()
    count = 0
    for file in inventory["files"]:
        digest = file["sha256"]
        if (file["extension"] not in (".fbx", ".bvh", ".glb", ".gltf", ".blend")
                or not file["working_copy"] or digest in seen or (args.only and digest not in args.only)):
            continue
        seen.add(digest)
        target = output / (digest + ".json")
        if target.exists():
            previous = json.loads(target.read_text(encoding="utf-8"))
            if previous.get("inspector_version") == 2 and previous["status"] not in ("inspection_failed",):
                continue
        try:
            data = inspect_file(app / file["working_copy"], digest, target, poses)
        except Exception as exc:
            data = {"file_sha256": digest, "status": "inspection_failed", "takes": [],
                    "error": str(exc), "trace": traceback.format_exc()}
        data["source_ids"] = [r["source_id"] for r in inventory["files"] if r["sha256"] == digest]
        data["inspector_version"] = 2
        write_json(target, data)
        print("ANIMATION_INSPECT " + json.dumps({"hash": digest[:12], "source": file["original_filename"],
                                                "status": data["status"], "takes": len(data["takes"])}), flush=True)
        count += 1
        if args.limit and count >= args.limit:
            break


if __name__ == "__main__":
    main()
