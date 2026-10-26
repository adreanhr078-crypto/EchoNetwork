extends SceneTree

## Four views of the actual ward. No avatar, story grant or art acceptance.
var folder := ""
func _initialize() -> void: _run.call_deferred()
func frames(count: int) -> void:
	for i in count: await process_frame
func _run() -> void:
	root.unfocusable=true;root.size=Vector2i(1280,720)
	var args:=OS.get_cmdline_user_args()
	var version:=args[0] if not args.is_empty() else "baseline"
	folder=ProjectSettings.globalize_path("res://../audits/evidence/pre-tripo-20261018/cp37/hospital/"+version).simplify_path()
	DirAccess.make_dir_recursive_absolute(folder)
	var room=load("res://scenes/environment/hospital_bedside_room.tscn").instantiate()
	root.add_child(room)
	var observer:=Node3D.new()
	room.add_child(observer);room.player=observer
	observer.position=room.SAFE_ANCHOR_BEDSIDE
	var camera:=Camera3D.new()
	camera.fov=58;camera.near=.05
	room.add_child(camera);camera.make_current()
	camera.environment=room.get_node("HospitalWorldEnvironment").environment
	for spec in [["entry",Vector3(2.6,1.65,2.2),Vector3(-1,1,-.6)],["bedside",Vector3(-.25,1.15,1.5),Vector3(-1.5,.9,-.8)],["window",Vector3(2.6,1.7,-2.3),Vector3(-1.5,1.2,0)],["mirror",Vector3(1.6,1.65,-.7),Vector3(3,1.45,-1.0)]]:
		camera.position=spec[1];camera.look_at(spec[2])
		await frames(18)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join(spec[0]+".png"))
	var collision:=[]
	for shape:CollisionShape3D in room.find_children("*","CollisionShape3D",true,false):
		collision.append({"path":str(room.get_path_to(shape)),"transform":str(shape.global_transform),"shape":shape.shape.get_class(),"bounds":str(shape.shape.get_debug_mesh().get_aabb()),"disabled":shape.disabled})
	var lights:=[]
	for light:Light3D in room.find_children("*","Light3D",true,false):
		lights.append({"path":str(room.get_path_to(light)),"type":light.get_class(),"energy":light.light_energy,"color":str(light.light_color),"visible":light.is_visible_in_tree(),"shadow":light.shadow_enabled})
	var dressing: Node=room.get_node("WardPresentation")
	if dressing.get_meta("linen_surfaces",0)!=1:
		push_error("The imported linen surface did not receive its native cloth material");quit(1);return
	var before: float=dressing.elapsed
	room.reduced_motion=true
	await frames(4)
	if dressing.elapsed!=before:
		push_error("Reduced Motion did not freeze ward rain");quit(1);return
	room.reduced_motion=false
	paused=true
	await create_timer(.1).timeout
	if dressing.elapsed!=before:
		push_error("Pause did not freeze ward rain");quit(1);return
	paused=false
	if room.bed_awakened_done or room.mark_revealed_done or room.chapter_completed_done:
		push_error("Presentation advanced hospital story flags");quit(1);return
	if room.get_node("WardFurniture/Mattress").layers!=0 or room._bed_body.get_child(0).disabled:
		push_error("Visual replacement removed the existing mattress collision");quit(1);return
	if not room.has_node("WardFurniture/WardVisitorChair") or not room.has_node("VanityMirrorStation/WardVanity"):
		push_error("Qualified furniture derivative is missing");quit(1);return
	if room.get_node("VanityMirrorStation/CounterMesh").layers!=0 or room.get_node("VanityMirrorStation/CounterCollisionShape3D").disabled:
		push_error("Vanity visual replacement changed the physical counter");quit(1);return
	var hashes:={}
	for name in ["scripts/environment/hospital_bedside_room.gd","scripts/environment/hospital_bedside_foundation.gd","scripts/environment/hospital_mirror_station.gd","scripts/environment/hospital_room_dressing.gd","shaders/ward_floor.gdshader","shaders/ward_linen.gdshader","shaders/ward_rain_window.gdshader","assets/props/ward_bed_original_v1.glb"]: hashes[name]=FileAccess.get_sha256("res://"+name)
	for name in ["assets/props/ward_visitor_chair_v1.glb","assets/props/ward_vanity_v1.glb","scripts/environment/planar_inspection_mirror.gd","tests/hospital_visual_review.gd"]: hashes[name]=FileAccess.get_sha256("res://"+name)
	var result:=FileAccess.open(folder.path_join("review.json"),FileAccess.WRITE)
	result.store_string(JSON.stringify({"scope":"Isolated actual ward four views; no avatar/route/fun/acceptance claim","display":DisplayServer.get_name(),"collision_signature":collision,"lights":lights,"source_hashes":hashes},"\t"))
	print("HOSPITAL_FOUR_VIEWS complete; collisions=",collision.size()," lights=",lights.size()," version=",version)
	quit(0)
