import bpy
bpy.ops.wm.open_mainfile(filepath='C:/Users/yasmo/EchoNetwork/artifacts/eleven-eleven/audits/evidence/chapter-cp45-20261020/stage11/sword-shield/single-motion.blend')
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath='C:/Users/yasmo/EchoNetwork/artifacts/eleven-eleven/godot/assets/characters/echo_v31_short_jacket.glb')
print('VARIANT_IMPORT_OBJECTS',[(o.name,o.type,len(o.vertex_groups) if o.type=='MESH' else None,[(m.type,m.object.name if m.type=='ARMATURE' and m.object else '') for m in o.modifiers] if o.type=='MESH' else None) for o in set(bpy.data.objects)-before])