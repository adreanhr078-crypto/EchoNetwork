"""Inspect the approved pact rig and render welded component IDs; source read-only."""
import bpy,hashlib,json,colorsys
from pathlib import Path
from mathutils import Vector
app=Path(__file__).resolve().parents[2]
source=app/'art/production/echo-contract-rebuild-20261101/source/contract-rig4k.glb'
out=source.parent.parent/'work/wing-intake'
out.mkdir(exist_ok=True)
digest=hashlib.sha256(source.read_bytes()).hexdigest()
assert digest=='edf2e892ccfa0c66bb829745d1b434bb462a0edda0e50fd341d5d7ab96cbd533'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH')
points=[mesh.matrix_world@v.co for v in mesh.data.vertices]
parent=list(range(len(points)))
def find(i):
    while parent[i]!=i:
        parent[i]=parent[parent[i]];i=parent[i]
    return i
def union(a,b):
    a,b=find(a),find(b)
    if a!=b:parent[b]=a
by_position={}
for i,v in enumerate(points):
    key=tuple(round(c,6) for c in v)
    if key in by_position:union(i,by_position[key])
    else:by_position[key]=i
for polygon in mesh.data.polygons:
    for v in polygon.vertices[1:]:union(polygon.vertices[0],v)
groups={}
for i in range(len(points)):groups.setdefault(find(i),[]).append(i)
groups=sorted(groups.values(),key=len,reverse=True)
ids={v:i for i,group in enumerate(groups) for v in group}
components=[]
for i,group in enumerate(groups):
    low=[min(points[j][a] for j in group) for a in range(3)]
    high=[max(points[j][a] for j in group) for a in range(3)]
    components.append({'id':i,'vertices':len(group),'low':low,'high':high})
scene=bpy.context.scene
scene.render.engine='BLENDER_WORKBENCH'
scene.display.shading.light='STUDIO'
scene.display.shading.show_shadows=True
scene.display.shading.show_cavity=True
scene.render.resolution_x=900;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('WingIntake');scene.world.color=(.045,.055,.075)
low=Vector(tuple(min(v[a] for v in points) for a in range(3)))
high=Vector(tuple(max(v[a] for v in points) for a in range(3)))
center=(low+high)*.5
camera=bpy.data.objects.new('ReviewCamera',bpy.data.cameras.new('ReviewCamera'))
scene.collection.objects.link(camera);scene.camera=camera
camera.data.type='ORTHO';camera.data.ortho_scale=max(high.z-low.z,(high.x-low.x)*1000/900)*1.1
attribute=mesh.data.color_attributes.new(name='DiagnosticComponents',type='FLOAT_COLOR',domain='CORNER')
for loop in mesh.data.loops:
    cid=ids[loop.vertex_index]
    rgb=colorsys.hsv_to_rgb((cid*.61803398875)%1,.7,.85)
    attribute.data[loop.index].color=(*rgb,1)
mesh.data.color_attributes.active_color=attribute
for mode in ['TEXTURE','VERTEX']:
    scene.display.shading.color_type=mode
    for name,direction in [('front',(0,-4,0)),('back',(0,4,0)),('side',(4,0,0))]:
        camera.location=center+Vector(direction)
        camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(out/(mode.lower()+'-'+name+'.png'))
        bpy.ops.render.render(write_still=True)
data={'source_sha256':digest,'source_unchanged':hashlib.sha256(source.read_bytes()).hexdigest()==digest,'status':'COMPONENT_CAPTURE_PENDING_SEMANTIC_REVIEW','bounds':{'low':list(low),'high':list(high)},'rig_world_matrix':[list(row) for row in rig.matrix_world],'bones':{b.name:{'head':list(rig.matrix_world@b.head_local),'tail':list(rig.matrix_world@b.tail_local),'parent':b.parent.name if b.parent else None} for b in rig.data.bones},'component_count':len(groups),'components':components}
(out/'topology.json').write_text(json.dumps(data,indent=2)+'\n')
(out/'component-vertices.json').write_text(json.dumps(groups)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(out/'diagnostic-components.blend'))
assert data['source_unchanged']
print('CONTRACT_COMPONENTS',len(groups),[len(g) for g in groups[:12]])
