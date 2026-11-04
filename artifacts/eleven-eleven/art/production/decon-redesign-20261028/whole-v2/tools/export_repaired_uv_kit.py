import bpy,pathlib
P=pathlib.Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\decon-redesign-20261028\whole-v2');bpy.ops.wm.open_mainfile(filepath=str(P/'uv-repaired-metric-source.blend'));bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
 if o.type=='MESH' and o.name.startswith(('Measured','Native')):o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(P/'authored-uv-kit-repaired.glb'),export_format='GLB',use_selection=True,export_apply=True);print('REPAIRED_KIT_READY')
