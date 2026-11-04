"""Author a separately gated wing derivative; preserve the approved source and body."""
from pathlib import Path
import bpy,hashlib,json,math
from mathutils import Vector,Matrix
app=Path(__file__).resolve().parents[2]
base=app/'art/production/echo-contract-rebuild-20261101'
source=base/'source/contract-rig4k.glb'
intake=base/'work/wing-intake'
out=base/'work/wing-rig-v2';out.mkdir(exist_ok=True)
mask=json.loads((intake/'wing-mask.json').read_text())
assert mask['status']=='PASS_SEMANTIC_SELECTION'
digest=hashlib.sha256(source.read_bytes()).hexdigest()
assert digest==mask['source_sha256']
for name,h in mask['reviewed_capture_hashes'].items():assert hashlib.sha256((intake/name).read_bytes()).hexdigest()==h
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH')
wing=set(mask['vertex_indices'])
assert len(wing)==32860 and max(wing)<len(mesh.data.vertices)
def body_weights():
    rows=[(v.index,[(mesh.vertex_groups[g.group].name,g.weight) for g in v.groups]) for v in mesh.data.vertices if v.index not in wing]
    return hashlib.sha256(json.dumps(rows,separators=(',',':')).encode()).hexdigest()
body_hash=body_weights()
coordinates=[v.co.copy() for v in mesh.data.vertices]
uv_hash=hashlib.sha256(b''.join(bytes(str(tuple(v.uv)),'ascii') for v in mesh.data.uv_layers.active.data)).hexdigest()
specs=[
 ('WingRootLeft',(.062,-.232,.795),(.118,-.10,.838),'mixamorig:Spine2'),
 ('WingInnerLeft',(.118,-.10,.838),(.19,.04,.90),'WingRootLeft'),
 ('WingOuterLeft',(.19,.04,.90),(.29,.24,.95),'WingInnerLeft'),
 ('WingTipLeft',(.29,.24,.95),(.35,.35,.89),'WingOuterLeft'),
 ('WingFanInnerLeft',(.13,-.08,.81),(.13,-.04,.63),'WingInnerLeft'),
 ('WingFanMidLeft',(.20,.07,.85),(.22,.10,.55),'WingOuterLeft'),
 ('WingFanOuterLeft',(.29,.23,.89),(.33,.29,.35),'WingTipLeft'),
]
inverse=rig.matrix_world.inverted()
bpy.context.view_layer.objects.active=rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for name,head,tail,parent in specs:
    bone=rig.data.edit_bones.new(name)
    bone.head=inverse@Vector(head);bone.tail=inverse@Vector(tail)
    bone.parent=rig.data.edit_bones[parent]
    bone.use_connect=False
bpy.ops.object.mode_set(mode='OBJECT')
groups={name:mesh.vertex_groups.new(name=name) for name,*_ in specs}
root=Vector(specs[0][1])
def segment_distance(p,a,b):
    a,b=Vector(a),Vector(b);v=b-a
    t=max(0,min(1,(p-a).dot(v)/v.length_squared))
    return (p-a-v*t).length
for index in sorted(wing):
    vertex=mesh.data.vertices[index]
    for entry in list(vertex.groups):mesh.vertex_groups[entry.group].remove([index])
    p=mesh.matrix_world@vertex.co
    nearest=sorted((segment_distance(p,head,tail),name) for name,head,tail,_ in specs)[:3]
    weights=[(name,1/max(distance,.006)**4) for distance,name in nearest]
    total=sum(w for _,w in weights)
    attachment=max(0,min(1,1-(p-root).length/.055))*.9
    for name,weight in weights:groups[name].add([index],weight/total*(1-attachment),'REPLACE')
    if attachment:mesh.vertex_groups['mixamorig:Spine2'].add([index],attachment,'REPLACE')
assert body_weights()==body_hash
assert all((v.co-coordinates[v.index]).length==0 for v in mesh.data.vertices)
assert uv_hash==hashlib.sha256(b''.join(bytes(str(tuple(v.uv)),'ascii') for v in mesh.data.uv_layers.active.data)).hexdigest()
bpy.context.view_layer.update()
evaluated=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
rest_error=max((v.co-coordinates[v.index]).length for v in evaluated.vertices)
mesh.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh_clear()
assert rest_error<1e-5,rest_error
max_weight_error=max(abs(sum(g.weight for g in v.groups)-1) for v in mesh.data.vertices)
assert max_weight_error<1e-5
# Bake the single uniform unit conversion into derivative data. Native Godot
# SpringBone requires an unscaled skeleton; v1 with a scaled parent is retained.
topology=json.loads((intake/'topology.json').read_text())
body_top=topology['components'][0]['high'][2]
factor=1.77/body_top
feet=[Vector(topology['bones']['mixamorig:'+side+'Foot']['head']) for side in ['Left','Right']]
center=(feet[0]+feet[1])*.5
normalizer=bpy.data.objects.new('EchoPactMetricRoot',None)
bpy.context.scene.collection.objects.link(normalizer)
original_world={obj:obj.matrix_world.copy() for obj in bpy.context.scene.objects if obj!=normalizer}
original_points=[mesh.matrix_world@v.co for v in mesh.data.vertices]
for obj in list(bpy.context.scene.objects):
    if obj!=normalizer and obj.parent is None:obj.parent=normalizer
rig.data.transform(Matrix.Scale(factor,4))
mesh.data.transform(Matrix.Scale(factor,4))
for obj,matrix in original_world.items():
    desired=matrix.copy();desired.translation*=factor
    obj.matrix_world=desired
normalizer.location=Vector((-center.x*factor,-center.y*factor,0))
normalizer['source_sha256']=digest
normalizer['wing_mask_sha256']=hashlib.sha256((intake/'wing-mask.json').read_bytes()).hexdigest()
normalizer['qualification']='ISOLATED_WING_DERIVATIVE_NOT_RUNTIME'
bpy.context.view_layer.update()
metric_error=max((mesh.matrix_world@v.co-(original_points[v.index]*factor+normalizer.location)).length for v in mesh.data.vertices)
assert metric_error<1e-5,metric_error
assert all(abs(v-1)<1e-5 for v in rig.matrix_world.to_scale())
blend=out/'contract-wing-metric.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
bpy.ops.object.select_all(action='DESELECT')
for obj in [normalizer,rig,mesh]:obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(out/'contract-wing-metric.glb'),export_format='GLB',use_selection=True,export_animations=False,export_skins=True,export_yup=True)
# Independent wing articulation must leave every body vertex unchanged.
def evaluated_points():
    obj=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    result=obj.to_mesh();points=[mesh.matrix_world@v.co for v in result.vertices];obj.to_mesh_clear();return points
baseline=evaluated_points()
rig.pose.bones['WingOuterLeft'].rotation_mode='XYZ'
rig.pose.bones['WingOuterLeft'].rotation_euler.y=math.radians(12)
rig.pose.bones['WingFanOuterLeft'].rotation_mode='XYZ'
rig.pose.bones['WingFanOuterLeft'].rotation_euler.x=math.radians(6)
bpy.context.view_layer.update()
posed=evaluated_points()
body_error=max((a-b).length for i,(a,b) in enumerate(zip(baseline,posed)) if i not in wing)
wing_travel=max((baseline[i]-posed[i]).length for i in wing)
# Skin evaluation at metre scale varies by a few float32 micrometres after
# modifier recomputation. Body weights are independently bit-identical above.
assert body_error<1e-5 and wing_travel>.015,(body_error,wing_travel)
scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH'
scene.display.shading.light='STUDIO';scene.display.shading.color_type='TEXTURE';scene.display.shading.show_cavity=True
scene.render.resolution_x=900;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('PactRigReview');scene.world.color=(.045,.055,.075)
camera=bpy.data.objects.new('ReviewCamera',bpy.data.cameras.new('ReviewCamera'));scene.collection.objects.link(camera);scene.camera=camera
camera.data.type='ORTHO';camera.data.ortho_scale=2.05
for pose in ['wing-articulation','neutral','body-articulation']:
    if pose!='wing-articulation':
        for pb in rig.pose.bones:pb.rotation_mode='QUATERNION';pb.rotation_quaternion=(1,0,0,0)
    if pose=='body-articulation':
        from mathutils import Quaternion
        rig.pose.bones['mixamorig:Spine2'].rotation_quaternion=Quaternion((0,1,0),math.radians(12))
        rig.pose.bones['mixamorig:LeftArm'].rotation_quaternion=Quaternion((1,0,0),math.radians(25))
    bpy.context.view_layer.update()
    for view,direction in [('front',(0,-4,0)),('back',(0,4,0)),('side',(4,0,0))]:
        target=Vector((.08,.25,.88));camera.location=target+Vector(direction)
        camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(out/(pose+'-'+view+'.png'));bpy.ops.render.render(write_still=True)
result={'status':'NUMERIC_WING_DERIVATIVE_PASS_VISUAL_PENDING','source_sha256':digest,'source_unchanged':hashlib.sha256(source.read_bytes()).hexdigest()==digest,'body_weights_sha256_before_and_after':body_hash,'geometry_change':'One uniform metric unit conversion only;UVs and topology unchanged','rest_deformation_error_source_units':rest_error,'metric_conversion_error_m':metric_error,'skeleton_world_scale':list(rig.matrix_world.to_scale()),'weight_sum_max_error':max_weight_error,'wing_bones':[s[0] for s in specs],'total_bones':len(rig.data.bones),'wing_vertices':len(wing),'body_movement_during_wing_test_m':body_error,'wing_movement_m':wing_travel,'uniform_metric_scale':factor,'body_height_m':1.77,'blend_sha256':hashlib.sha256(blend.read_bytes()).hexdigest(),'glb_sha256':hashlib.sha256((out/'contract-wing-metric.glb').read_bytes()).hexdigest(),'runtime_integrated':False,'physics_simulation':'UNVERIFIED;authored articulation only'}
(out/'review.json').write_text(json.dumps(result,indent=2)+'\n')
assert result['source_unchanged']
print(json.dumps(result))
