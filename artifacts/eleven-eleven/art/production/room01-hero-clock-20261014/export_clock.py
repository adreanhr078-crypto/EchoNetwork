import bpy, json, struct
from pathlib import Path

dest=Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\room01-hero-clock-20261014')
scene=bpy.data.scenes['Room01ClockCraft']
bpy.context.window.scene=scene
collection=bpy.data.collections['Room01ClockAsset']
body=bpy.data.objects['ClockBody']
old=list(body.data.materials)
roles=[];remap={}
for i,mat in enumerate(old):
    role=mat.name.split('.')[0]
    index=next((k for k,m in enumerate(roles) if m.name.split('.')[0]==role),None)
    if index is None:index=len(roles);roles.append(mat)
    remap[i]=index
indices=[remap[p.material_index] for p in body.data.polygons]
body.data.materials.clear()
for mat in roles:body.data.materials.append(mat)
for polygon,index in zip(body.data.polygons,indices):polygon.material_index=index
rotations={name:bpy.data.objects[name].rotation_euler.copy() for name in ['HourHand','MinuteHand']}
for name in rotations:bpy.data.objects[name].rotation_euler.z=0
bpy.ops.object.select_all(action='DESELECT')
for item in collection.objects:item.select_set(True)
path=dest/'room01-clock-hero.glb'
try:
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',
        use_selection=True,use_active_scene=True,export_apply=True,
        export_animations=False,export_cameras=False,export_lights=False)
finally:
    for name,rotation in rotations.items():bpy.data.objects[name].rotation_euler=rotation
raw=path.read_bytes();size=struct.unpack_from('<I',raw,12)[0]
document=json.loads(raw[20:20+size])
names=[node.get('name') for node in document['nodes']]
assert set(names)=={'ClockBody','HourHand','MinuteHand'},names
assert len(document['materials'])==3
result={'export':str(path),'bytes':len(raw),'materials':3,'nodes':names,
        'triangles':sum(sum(len(p.vertices)-2 for p in item.data.polygons) for item in collection.objects),
        'native_hand_direction':'12 oclock; centre origin; runtime applies335.5/66 exactly once',
        'textures':len(document.get('images',[])),
        'scope_failure':'Initial selection-only exporter included Cube from preserved Scene; fixed with use_active_scene=True before runtime integration.'}
(dest/'export-report.json').write_text(json.dumps(result,indent=2))
