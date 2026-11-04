import bpy,pathlib,json
P=pathlib.Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\decon-redesign-20261028\whole-v2');bpy.ops.wm.open_mainfile(filepath=str(P/'corrected-metric-source.blend'));objects=[o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith(('Measured','Native'))];bpy.ops.object.select_all(action='DESELECT')
for o in objects:o.select_set(True)
tri=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects);assert tri<80000,tri
bpy.ops.export_scene.gltf(filepath=str(P/'authored-uv-kit-source.glb'),export_format='GLB',use_selection=True,export_apply=True)
report={'source':'corrected-metric-source.blend','scope':'UV repair only for authored additions;existing whole-room generated geometry/materials preserved','objects':[o.name for o in objects],'triangles':tri,'uv_status':'Known overlapping primitive UVs;explicit SmartUV repair required before texture','original_pbr':'corrected-tripo-pbr-source.glb preserved;exclude these seven material groups from final composite'};(P/'authored-uv-repair-report.json').write_text(json.dumps(report,indent=2));print('AUTHORED_UV_KIT_EXPORTED',tri,report['objects'])
