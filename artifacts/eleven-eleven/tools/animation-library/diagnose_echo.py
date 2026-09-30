import bpy, json
from pathlib import Path
from mathutils import Vector
app=Path.cwd()
for label,path in [('source',app/'art/production/echo-master-character/rig-v2/tripo-out/echo-master-humanoid-rig-v2-rig-45c06226/model.glb'),('prepared',app/'art/production/echo-master-character/prepared-v1/echo-master-8k.blend')]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if path.suffix=='.glb': bpy.ops.import_scene.gltf(filepath=str(path))
    else: bpy.ops.wm.open_mainfile(filepath=str(path))
    rigs=[o for o in bpy.context.scene.objects if o.type=='ARMATURE']
    rows=[]
    for o in bpy.context.scene.objects:
        if o.type!='MESH': continue
        raw=[o.matrix_world@Vector(v) for v in o.bound_box]
        ev=o.evaluated_get(bpy.context.evaluated_depsgraph_get())
        eva=[ev.matrix_world@Vector(v) for v in ev.bound_box]
        rows.append(dict(name=o.name,parent=o.parent.name if o.parent else None,world=[list(r) for r in o.matrix_world],raw=[[min(v[i] for v in raw),max(v[i] for v in raw)] for i in range(3)],evaluated=[[min(v[i] for v in eva),max(v[i] for v in eva)] for i in range(3)]))
    rig=rigs[0]
    heads={n:list(rig.matrix_world@rig.data.bones[n].head_local) for n in ['mixamorig:LeftToeBase','mixamorig:Hips','mixamorig:Head']}
    print('DIAG2 '+json.dumps(dict(label=label,rig_world=[list(r) for r in rig.matrix_world],heads=heads,meshes=rows)),flush=True)
