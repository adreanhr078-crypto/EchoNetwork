import bpy,pathlib,json,math,hashlib
P=pathlib.Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\decon-redesign-20261028\whole-v2');bpy.ops.wm.open_mainfile(filepath=str(P/'corrected-metric-source.blend'));objects=[o for o in bpy.data.objects if o.type=='MESH'];repairs=[]
for o in objects:
 if not o.name.startswith(('Measured','Native')):continue
 before=[v.co.copy() for v in o.data.vertices];old=len(set((round(l.uv.x,6),round(l.uv.y,6)) for l in o.data.uv_layers.active.data)) if o.data.uv_layers else 0
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.003);bpy.ops.object.mode_set(mode='OBJECT')
 assert all((v.co-p).length==0 for v,p in zip(o.data.vertices,before))
 unique=len(set((round(l.uv.x,6),round(l.uv.y,6)) for l in o.data.uv_layers.active.data));repairs.append({'name':o.name,'unique_uv_before':old,'unique_uv_after':unique,'positions_unchanged':True})
bpy.ops.object.select_all(action='DESELECT')
for o in objects:o.select_set(True)
bpy.context.view_layer.objects.active=objects[0];bpy.ops.export_scene.gltf(filepath=str(P/'uv-repaired-metric-source.glb'),export_format='GLB',use_selection=True,export_apply=True);bpy.ops.wm.save_as_mainfile(filepath=str(P/'uv-repaired-metric-source.blend'))
floor=next(x for x in repairs if x['name']=='MeasuredFloor');assert floor['unique_uv_after']>floor['unique_uv_before']*10
r={'status':'AUTHORED_UV_REPAIRED_RETEXTURE_PENDING','source':'corrected-metric-source.blend','new_source':'uv-repaired-metric-source.glb','new_sha256':hashlib.sha256((P/'uv-repaired-metric-source.glb').read_bytes()).hexdigest(),'repairs':repairs,'warning':'Old PBR remains valid only for generated perimeter/pod/arch groups;seven authored groups require fresh texturing or an explicitly qualified material transfer. Do not reuse their overlapping-UV maps or claim room acceptance.'};(P/'uv-repair-result.json').write_text(json.dumps(r,indent=2));print('UV_REPAIR_PASS',floor)
