import bpy, json, sys
from pathlib import Path
source, output = map(Path,sys.argv[sys.argv.index('--')+1:])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source.resolve()))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
data={'rig':rig.name,'matrix':[list(row) for row in rig.matrix_world], 'bones':[{'name':b.name,'parent':b.parent.name if b.parent else None,'head':list(b.head_local),'tail':list(b.tail_local),'length':b.length} for b in rig.data.bones]}
output.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
print(json.dumps(data))
