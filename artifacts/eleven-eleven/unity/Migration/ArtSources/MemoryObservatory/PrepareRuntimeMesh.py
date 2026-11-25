from pathlib import Path
import bpy
import json
import sys

source, destination, target = sys.argv[sys.argv.index("--") + 1:]
source, destination, target = Path(source), Path(destination), int(target)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
meshes = [item for item in bpy.context.scene.objects if item.type == "MESH"]
before = 0
for item in meshes:
    item.data.calc_loop_triangles()
    before += len(item.data.loop_triangles)
assert before > 0 and meshes
if before <= target:
    from shutil import copyfile
    copyfile(source,destination)
    after=before
else:
    keep=target / before
    for item in meshes:
        bpy.ops.object.select_all(action="DESELECT")
        item.select_set(True)
        bpy.context.view_layer.objects.active = item
        sizes = tuple(item.dimensions)
        source_uv = len(item.data.uv_layers)
        source_slots = len(item.data.materials)
        modifier = item.modifiers.new("Preserve silhouette at Observatory game budget","DECIMATE")
        modifier.decimate_type = "COLLAPSE"
        modifier.ratio = keep
        modifier.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        assert len(item.data.uv_layers) == source_uv
        assert len(item.data.materials) == source_slots
        assert all(abs(a-b) <= max(.005,abs(a)*.018) for a,b in zip(sizes,item.dimensions))
        item.data.calc_loop_triangles()
    after=sum(len(item.data.loop_triangles) for item in meshes)
    assert after >= min(target*.88, before), (before, after)
    bpy.ops.export_scene.gltf(filepath=str(destination),export_format="GLB",export_tangents=True,export_materials="EXPORT")
print("ECHO_OBSERVATORY_OPTIMIZED",json.dumps({"source_triangles":before,"runtime_triangles":after,"bytes":destination.stat().st_size}))
