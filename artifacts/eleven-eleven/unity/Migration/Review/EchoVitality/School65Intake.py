import bpy, os
from mathutils import Vector

source = os.environ["ECHO_REVIEW_SOURCE"]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=source)
skin = max((o for o in bpy.context.scene.objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))
arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
head = next(b for b in arm.data.bones if b.name.endswith(":Head"))
print("FACE_INTAKE", len(skin.data.vertices), len(skin.data.polygons), len(arm.data.bones), len(skin.data.materials))
for bone in arm.data.bones:
    if bone.name.endswith((":Head", ":LeftFoot", ":RightHand", ":LeftHand", ":Neck", ":HeadTop_End", ":LeftToeBase")):
        print(bone.name, tuple(round(v, 4) for v in arm.matrix_world @ bone.head_local), tuple(round(v, 4) for v in arm.matrix_world @ bone.tail_local))
print("SOURCE_SLOTS", [m.name for m in skin.data.materials])

scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.render.resolution_x = 1100
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
shading = scene.display.shading
shading.light = "STUDIO"
shading.color_type = "TEXTURE"
shading.show_shadows = False
shading.show_cavity = True
shading.show_specular_highlight = False
shading.background_type = "WORLD"
target = Vector((0.002, -0.035, 0.928))
bpy.ops.object.camera_add(location=(0.002, -0.75, 0.928))
camera = bpy.context.object
scene.camera = camera
camera.data.type = "ORTHO"
camera.data.ortho_scale = 0.258
out = os.environ["ECHO_REVIEW_WORK"]
for label, x in (("front", 0.002), ("three-quarter", 0.43)):
    camera.location.x = x
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(out, "School65-neutral-" + label + ".png")
    bpy.ops.render.render(write_still=True)

shading.color_type = "SINGLE"
shading.single_color = (0.64, 0.67, 0.72)
shading.cavity_type = "BOTH"
scene.render.resolution_x = 1280
scene.render.resolution_y = 960
camera.data.ortho_scale = 0.123
target = Vector((0.002, -0.035, 0.911))
camera.location = Vector((0.002, -0.75, 0.911))
camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
scene.render.filepath = os.path.join(out, "School65-eye-geometry.png")
bpy.ops.render.render(write_still=True)

# Landmarks selected on the orthographic geometry review, in image pixels.
# The indices below identify the image positions, not mesh vertices.
import json
import hashlib
from mathutils.bvhtree import BVHTree

landmarks = {
    "right_eye": {"outer": (306, 509), "upper": (392, 521), "inner": (503, 551),
                  "lower": (397, 568), "iris": (403, 547), "cheek_reference": (393, 629)},
    "left_eye": {"outer": (894, 511), "upper": (804, 523), "inner": (700, 555),
                 "lower": (808, 568), "iris": (797, 547), "cheek_reference": (813, 630)},
}
bpy.context.view_layer.update()
verts = [skin.matrix_world @ v.co for v in skin.data.vertices]
faces = [tuple(f.vertices) for f in skin.data.polygons]
tree = BVHTree.FromPolygons(verts, faces)
parents = list(range(len(verts)))

def component(index):
    while parents[index] != index:
        parents[index] = parents[parents[index]]
        index = parents[index]
    return index

def connect(a, b):
    a, b = component(a), component(b)
    if a != b:
        parents[b] = a

# The GLB splits points on UV seams. Join coincident positions for the connectivity
# report only, without merging or editing the rig or its texture coordinates.
positions = {}
for i, v in enumerate(verts):
    key = tuple(round(c * 1_000_000) for c in v)
    connect(i, positions.setdefault(key, i))
for f in faces:
    for v in f[1:]:
        connect(f[0], v)
components = {}
for i in range(len(verts)):
    root = component(i)
    components[root] = components.get(root, 0) + 1

frame = camera.data.view_frame(scene=scene)
left = min(v.x for v in frame)
right = max(v.x for v in frame)
bottom = min(v.y for v in frame)
top = max(v.y for v in frame)
direction = camera.matrix_world.to_quaternion() @ Vector((0, 0, -1))
results = {}
for eye, points in landmarks.items():
    results[eye] = {}
    for name, (x, y) in points.items():
        u = (x + 0.5) / scene.render.resolution_x
        v = (y + 0.5) / scene.render.resolution_y
        ray = camera.matrix_world @ Vector((left + (right-left)*u, top + (bottom-top)*v, 0))
        hit, normal, face, distance = tree.ray_cast(ray, direction)
        if hit is None:
            raise RuntimeError(f"Landmark {eye}/{name} missed the visible geometry")
        root = component(faces[face][0])
        results[eye][name] = {"pixel": [x, y], "world_m": [round(c, 6) for c in hit],
                              "analysis_component": root, "component_vertex_count": components[root]}
digest = hashlib.file_digest(open(source, "rb"), "sha256").hexdigest()
report = {"status": "TOPOLOGY_REVIEW", "source_sha256": digest,
          "coordinates": "Blender world metres and School65-eye-geometry.png pixels",
          "selection": "Manually placed surface landmarks, mapped by orthographic ray cast",
          "connectivity": "Exact-position seam analysis rounded to one micrometre; source mesh untouched",
          "vertices": len(verts), "triangles": len(faces), "materials": len(skin.data.materials),
          "bones": len(arm.data.bones), "shape_keys": bool(skin.data.shape_keys), "eyes": results}
with open(os.path.join(out, "School65-eye-landmarks.json"), "w", encoding="utf-8") as f:
    json.dump(report, f, indent=2)
for eye, points in results.items():
    print("ECHO_FACE_INTAKE", eye, [(name, p["analysis_component"], p["component_vertex_count"]) for name,p in points.items()])

# Store authored eye selections on a derivative. The existing vertex groups are
# armature weights, so give the review groups names that cannot match a bone.
def membership(group_index):
    return [(v.index, g.weight) for v in skin.data.vertices for g in v.groups if g.group == group_index]

original_group_count = len(skin.vertex_groups)
for eye, points in results.items():
    iris = points["iris"]
    assert iris["analysis_component"] != points["cheek_reference"]["analysis_component"]
    selected = [i for i in range(len(verts)) if component(i) == iris["analysis_component"]]
    assert len(selected) == iris["component_vertex_count"]
    group = skin.vertex_groups.new(name="REVIEW.surface." + eye)
    group.add(selected, 1.0, "REPLACE")
    assert len(membership(group.index)) == len(selected)

assert len(skin.vertex_groups) == original_group_count + 2
bpy.context.view_layer.objects.active = skin
bpy.ops.object.select_all(action="DESELECT")
skin.select_set(True)
scene.render.filepath = "//School65-eye-geometry.png"
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "School65-eye-review.blend"), compress=True)
