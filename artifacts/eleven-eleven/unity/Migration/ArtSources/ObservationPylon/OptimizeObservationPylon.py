import bpy, json, os
from pathlib import Path

source=Path(os.environ["ECHO_PYLON_SOURCE"])
out=Path(os.environ["ECHO_PYLON_OUTPUT"])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
mesh=next(obj for obj in bpy.context.scene.objects if obj.type=="MESH")
bpy.context.view_layer.objects.active=mesh
mesh.select_set(True)
mesh.data.calc_loop_triangles()
original=len(mesh.data.loop_triangles)
assert len(mesh.data.uv_layers)>0 and len(mesh.data.materials)==1
original_size=tuple(mesh.dimensions)
decimate=mesh.modifiers.new("Reduce triangles for Unity", "DECIMATE")
decimate.decimate_type="COLLAPSE"
decimate.ratio=28900/original
decimate.use_collapse_triangulate=True
bpy.ops.object.modifier_apply(modifier=decimate.name)
mesh.data.calc_loop_triangles()
reduced=len(mesh.data.loop_triangles)
assert 25000 <= reduced <= 30000
assert len(mesh.data.uv_layers)>0 and len(mesh.data.materials)==1
assert all(abs(a-b)<0.007 for a,b in zip(original_size,mesh.dimensions))
bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB", export_tangents=True, export_materials="EXPORT")
print("ECHO_TRIPO_PYLON_OPTIMIZED", json.dumps({"triangles_original":original,"triangles_runtime":reduced,"glb_bytes":out.stat().st_size}))
