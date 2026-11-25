import bpy, os
bpy.ops.wm.open_mainfile(filepath=os.environ["ECHO_REVIEW_DERIVATIVE"])
skin = next(o for o in bpy.context.scene.objects if o.type == "MESH")
arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
assert len(arm.data.bones) == 65
assert len(skin.data.vertices) == 108934 and len(skin.data.polygons) == 51552
assert len(skin.data.uv_layers) == 1 and skin.data.shape_keys is None
eyes = []
for eye, expected in (("right_eye", 136), ("left_eye", 130)):
    group = skin.vertex_groups["REVIEW.surface." + eye]
    verts = {v.index for v in skin.data.vertices if any(g.group == group.index and g.weight == 1 for g in v.groups)}
    assert len(verts) == expected
    eyes.append(verts)
assert not eyes[0].intersection(eyes[1])
assert all(i.packed_file for i in bpy.data.images if i.source == "FILE")
print("ECHO_DERIVATIVE_REOPEN_PASS", *(len(v) for v in eyes))
