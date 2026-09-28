"""Read the current GLB and measure animated surface contact without editing it."""
import bpy
import json
from pathlib import Path

repo = Path(__file__).resolve().parents[2]
app = repo / "artifacts/eleven-eleven"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(app / "godot/assets/characters/echo_opening_uniform_v13.glb"))
rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
action = next(a for a in bpy.data.actions if "wakeup" in a.name.lower())
rig.animation_data_create()
print("WAKE_RIG", rig.name, "rotation", tuple(rig.rotation_euler))
print("WAKE_ACTION_SLOTS", [(s.identifier, s.target_id_type) for s in action.slots])
print("WAKE_OBJECTS", [(o.name, o.type, tuple(o.dimensions), tuple(o.rotation_euler)) for o in bpy.data.objects])
for track in rig.animation_data.nla_tracks:
    track.mute = True
rig.animation_data.action = action
if hasattr(action, "slots") and action.slots:
    rig.animation_data.action_slot = action.slots[0]
scene = bpy.context.scene
scene.render.fps = 24
body_meshes = [o for o in bpy.data.objects if o.type == "MESH" and any(m.type == "ARMATURE" and m.object == rig for m in o.modifiers)]
if not body_meshes:
    raise RuntimeError("Imported character has no skinned body")
start, end = (float(x) for x in action.frame_range)
samples = []
for sample in range(241):
    frame = start + (end - start) * sample / 240.0
    scene.frame_set(int(frame), subframe=frame - int(frame))
    depsgraph = bpy.context.evaluated_depsgraph_get()
    minimum = float("inf")
    for source in body_meshes:
        evaluated = source.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        minimum = min(minimum, min((evaluated.matrix_world @ v.co).z for v in mesh.vertices))
        evaluated.to_mesh_clear()
    samples.append(round(-minimum * 1.81, 5))
report = {"source": "echo_opening_uniform_v13.glb", "clip": action.name,
          "fps": 24, "start_frame": start, "end_frame": end, "runtime_scale": 1.81,
          "contact_offsets_y": samples, "measurement": "Blender evaluated mesh; reference only. Godot interpolation differs; use Godot bake for runtime."}
output = app / ".tmp/native-opening/wake-contact-measurement.json"
output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print("WAKE_CONTACT_MEASURED", len(samples), "samples", "range", min(samples), max(samples))
print("WAKE_CONTACT_QUARTERS", [samples[min(len(samples)-1, int(i*(len(samples)-1)/4))] for i in range(5)])
