import bpy,json,pathlib,hashlib
P=pathlib.Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\decon-redesign-20261028\tripo');r=json.loads((P/'precision-pod-atlas-layout.json').read_text());bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=r['source']);objects=[o for o in bpy.data.objects if o.type=='MESH'];before=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects)
mat=bpy.data.materials.new('Clinical pressure vessel packed PBR');mat.use_nodes=True;n=mat.node_tree.nodes;l=mat.node_tree.links;s=n.get('Principled BSDF')
for channel in ['basecolor','normal','orm']:
 tex=n.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(P/('precision-pod-atlas-'+channel+'.png')))
 if channel!='basecolor':tex.image.colorspace_settings.name='Non-Color'
 if channel=='basecolor':l.new(tex.outputs['Color'],s.inputs['Base Color'])
 elif channel=='normal':normal=n.new('ShaderNodeNormalMap');l.new(tex.outputs['Color'],normal.inputs['Color']);l.new(normal.outputs['Normal'],s.inputs['Normal'])
 else:
  sep=n.new('ShaderNodeSeparateColor');sep.mode='RGB';l.new(tex.outputs['Color'],sep.inputs[0]);l.new(sep.outputs['Green'],s.inputs['Roughness']);l.new(sep.outputs['Blue'],s.inputs['Metallic'])
for o in objects:
 uv=o.data.uv_layers.active.data
 for p in o.data.polygons:
  name=o.data.materials[p.material_index].name;t=r['tiles'][name]
  for idx in p.loop_indices:
   q=uv[idx].uv.copy();uv[idx].uv=((q.x-t['uv_min'][0])/t['uv_span'][0]*t['atlas_scale'][0]+t['atlas_offset'][0],(q.y-t['uv_min'][1])/t['uv_span'][1]*t['atlas_scale'][1]+t['atlas_offset'][1])
  p.material_index=0
 o.data.materials.clear();o.data.materials.append(mat)
bpy.ops.object.select_all(action='DESELECT')
for o in objects:o.select_set(True)
bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();obj=bpy.context.object;obj.name='PrecisionClinicalPressureVessel';after=sum(len(p.vertices)-2 for p in obj.data.polygons);assert before==after
bpy.ops.export_scene.gltf(filepath=r['runtime'],export_format='GLB',use_selection=True,export_apply=True)
r.update({'triangles':after,'runtime_sha256':hashlib.sha256(pathlib.Path(r['runtime']).read_bytes()).hexdigest(),'geometry_unchanged':True});(P/'precision-pod-atlas-report.json').write_text(json.dumps(r,indent=2));print('ATLAS_POD_EXPORTED',before,after)
