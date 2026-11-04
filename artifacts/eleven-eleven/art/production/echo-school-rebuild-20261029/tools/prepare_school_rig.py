import bpy,json,pathlib,hashlib,math,sys
from mathutils import Vector
p=pathlib.Path(__file__).resolve().parents[1]
app=p.parents[2]
sys.path.insert(0,str(app/"tools/animation-library"))
from retarget_contract import joint_map
from golden_reference import verify
verify()
bpy.ops.wm.read_factory_settings(use_empty=True)
raw=p/"source/echo-school-p2-pbr-rig.glb"
bpy.ops.import_scene.gltf(filepath=str(raw))
rigs=[o for o in bpy.context.scene.objects if o.type=="ARMATURE"];assert len(rigs)==1
rig=rigs[0]
# Source glTF has exactly one skinned mesh. Blender adds an unbound preview Icosphere;it is not source geometry.
meshes=[o for o in bpy.context.scene.objects if o.type=="MESH" and any(m.type=="ARMATURE" and m.object==rig for m in o.modifiers)]
assert len(meshes)==1
unowned=[o for o in bpy.context.scene.objects if o.type=="MESH" and o not in meshes]
for o in unowned:o.hide_render=True;o.hide_set(True)
assert len(rig.data.bones)==65
mapping=joint_map(rig.data.bones.keys())
assert all(k in mapping for k in ["hips","head","leftupleg","rightupleg","leftleg","rightleg","leftfoot","rightfoot","lefttoebase","righttoebase","lefthand","righthand"])
points=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
lo=Vector([min(v[i] for v in points) for i in range(3)]);hi=Vector([max(v[i] for v in points) for i in range(3)])
height=hi.z-lo.z;factor=1.76/height
roots=set()
for o in [rig]+meshes:
 top=o
 while top.parent:top=top.parent
 roots.add(top)
normalizer=bpy.data.objects.new("SchoolUniformMetricRoot",None);bpy.context.collection.objects.link(normalizer)
for o in roots:
 matrix=o.matrix_world.copy();o.parent=normalizer;o.matrix_world=matrix
normalizer.scale=Vector((factor,factor,factor));normalizer.location=Vector((-(lo.x+hi.x)*.5*factor,-(lo.y+hi.y)*.5*factor,-lo.z*factor))
bpy.context.view_layer.update()
weights=[];unweighted=0
for o in meshes:
 assert o.data.uv_layers.active
 assert any(m.type=="ARMATURE" and m.object==rig for m in o.modifiers)
 for v in o.data.vertices:
  total=sum(g.weight for g in v.groups);weights.append(total)
  if total<.999:unweighted+=1
assert unweighted==0
world={k:rig.matrix_world@rig.data.bones[n].matrix_local for k,n in mapping.items()}
forward=sum((world[s+"toebase"].translation-world[s+"foot"].translation for s in ["left","right"]),Vector());forward.z=0;forward.normalize();left=Vector((0,0,1)).cross(forward)
center=(world["leftupleg"].translation+world["rightupleg"].translation)*.5
for side,sign in [("left",1),("right",-1)]:
 for part in ["arm","forearm","hand","upleg","leg","foot"]:assert sign*(world[side+part].translation-center).dot(left)>.01,(side,part)
 assert world[side+"upleg"].translation.z>world[side+"leg"].translation.z>world[side+"foot"].translation.z
for o in bpy.context.scene.objects:
 if o.animation_data:o.animation_data_clear()
blend=p/"source/echo-school-rig-metric.blend";target=p/"source/echo-school-rig-metric.glb"
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
bpy.ops.object.select_all(action="DESELECT")
for o in [rig]+meshes:
 while o:
  o.select_set(True);o=o.parent
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(target),export_format="GLB",use_selection=True,export_yup=True,export_skins=True,export_animations=False)
images=[{"name":i.name,"size":list(i.size),"packed":bool(i.packed_file)} for i in bpy.data.images if i.source=="FILE"]
report={"status":"MEASURED_SCHOOL_TARGET_READY_MOTION_GATES_OPEN","raw_sha256":hashlib.sha256(raw.read_bytes()).hexdigest(),"target_file":str(target),"target_sha256":hashlib.sha256(target.read_bytes()).hexdigest(),"blend_sha256":hashlib.sha256(blend.read_bytes()).hexdigest(),"height_m":1.76,"source_dimensions_blender":list(hi-lo),"normalization_uniform_factor":factor,"joint_count":len(rig.data.bones),"mapping":mapping,"unweighted_vertices":unweighted,"excluded_importer_helpers":[o.name for o in unowned],"weight_sum_min":min(weights),"weight_sum_max":max(weights),"image_sizes":images,"front_blender":list(forward),"bones":{k:{"name":n,"parent":rig.data.bones[n].parent.name if rig.data.bones[n].parent else None,"world_rest":[list(row) for row in world[k]],"length_m":rig.data.bones[n].length} for k,n in mapping.items()},"source_animation_keys_changed":False,"runtime_integrated":False}
(p/"target-profile.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
# Neutral PBR renders of the exact saved candidate,without resaving source.
scene=bpy.context.scene
engines=scene.render.bl_rna.properties["engine"].enum_items.keys();scene.render.engine="BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
scene.render.resolution_x=800;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
if scene.world is None:scene.world=bpy.data.worlds.new("SchoolReviewWorld")
scene.world.use_nodes=True;scene.world.node_tree.nodes["Background"].inputs[0].default_value=(.075,.085,.10,1);scene.world.node_tree.nodes["Background"].inputs[1].default_value=.35
for name,pos,energy,size in [("SoftKey",(2,-3,3),250,4),("SoftFill",(-2,-1,2),140,3),("Backlight",(0,2,3),180,3)]:
 data=bpy.data.lights.new(name,"AREA");data.energy=energy;data.shape="DISK";data.size=size;o=bpy.data.objects.new(name,data);scene.collection.objects.link(o);o.location=pos;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat("-Z","Y").to_euler()
data=bpy.data.cameras.new("SchoolCharacterReview");camera=bpy.data.objects.new("SchoolCharacterReview",data);scene.collection.objects.link(camera);scene.camera=camera;data.type="ORTHO"
for name,pos,target_pos,scale in [("front",(0,-4,.9),(0,0,.9),2.15),("face",(.35,-2,1.65),(0,0,1.58),.55)]:
 camera.location=pos;camera.rotation_euler=(Vector(target_pos)-camera.location).to_track_quat("-Z","Y").to_euler();data.ortho_scale=scale;scene.render.filepath=str(p/"source"/("rig-pbr-"+name+".png"));bpy.ops.render.render(write_still=True)
print("SCHOOL_TARGET_PROFILE",report["status"],"bones",report["joint_count"],"unweighted",report["unweighted_vertices"])
verify()
