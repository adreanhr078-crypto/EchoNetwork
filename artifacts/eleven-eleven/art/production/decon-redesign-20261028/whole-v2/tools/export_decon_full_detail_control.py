import bpy,pathlib,json,hashlib
from mathutils import Vector
P=pathlib.Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\decon-redesign-20261028\whole-v2');O=pathlib.Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\godot\assets\environments\decon_clinical');r=json.loads((P/'optimized/atlas-layout.json').read_text());bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=r['source']);objects=[o for o in bpy.data.objects if o.type=='MESH'];dummy=bpy.data.materials.new('SharedExternalAtlasGeometry');stats=[]
for o in objects:
 uv=o.data.uv_layers.active.data
 for p in o.data.polygons:
  name=o.data.materials[p.material_index].name;t=r['tiles'][name]
  for idx in p.loop_indices:
   q=uv[idx].uv.copy();uv[idx].uv=((q.x-t['uv_min'][0])/t['uv_span'][0]*t['atlas_scale'][0]+t['atlas_offset'][0],(q.y-t['uv_min'][1])/t['uv_span'][1]*t['atlas_scale'][1]+t['atlas_offset'][1])
  p.material_index=0
 o.data.materials.clear();o.data.materials.append(dummy)
 before=sum(len(p.vertices)-2 for p in o.data.polygons);target=before
 if o.name.startswith('PressureVessel_'):target=18000
 elif o.name.startswith('SterilizationArch_'):target=10000
 elif o.name.startswith('Perimeter_'):target=max(600,int(before*.36))
 if False and target<before:
  bpy.context.view_layer.objects.active=o;m=o.modifiers.new('Bounded high runtime derivative','DECIMATE');m.ratio=target/before;m.use_collapse_triangulate=True;bpy.ops.object.modifier_apply(modifier=m.name)
 stats.append({'name':o.name,'triangles_before':before,'triangles_after':sum(len(p.vertices)-2 for p in o.data.polygons)})
 # Bake the source node frame once. No UV or image color edits occur here.
 world=o.matrix_world.copy();o.parent=None;o.matrix_world=world
bpy.ops.object.select_all(action='DESELECT')
for o in objects:o.select_set(True)
bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
gate=[o for o in objects if o.name.startswith('NativeMovingGateVisual')];terminal=[o for o in objects if o.name.startswith('NativeTerminalVisual')];assert gate and terminal,('Native visual roles missing',[o.name for o in objects]);static=[o for o in objects if o not in gate+terminal]
def export_group(items,name,anchor):
 bpy.ops.object.select_all(action='DESELECT')
 for o in items:
  for v in o.data.vertices:v.co-=Vector(anchor)
  o.select_set(True)
 bpy.context.view_layer.objects.active=items[0];bpy.ops.object.join();o=bpy.context.object;o.name=name
 # One UV-only mesh/material;three external shared PNGs are installed by Godot.
 bpy.ops.export_scene.gltf(filepath=str(O/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True)
 return {'asset':name+'.glb','sha256':hashlib.sha256((O/(name+'.glb')).read_bytes()).hexdigest(),'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),'anchor_blender_xyz':anchor}
assets=[export_group(static,'decon_whole_v2_static_full_detail',(0,0,0)),export_group(gate,'decon_whole_v2_gate_full_detail',(0,32,1.4)),export_group(terminal,'decon_whole_v2_terminal_full_detail',(0,16,3.2))]
report={'scope':'High runtime derivative;actual whole-room Tripo geometry plus measured corrections;originals preserved;no native acceptance','atlas_size':4096,'external_shared_maps':3,'mesh_materials':1,'asset_groups':assets,'source_roles':stats,'source_triangles':sum(x['triangles_before'] for x in stats),'runtime_triangles':sum(x['triangles_after'] for x in stats)};(P/'optimized/runtime-full-detail-control-report.json').write_text(json.dumps(report,indent=2));print('WHOLE_V2_RUNTIME_EXPORTED',report['runtime_triangles'],assets)

