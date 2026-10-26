extends SceneTree

## Candidate-only acting study. Actual runtime actor, combat and save untouched.
const PoseStudy=preload("res://tests/fixtures/kinja_p2_pose_study.gd")
var checks := 0
var model: Node3D
var rig: Skeleton3D
var pose: Node3D
var folder := ""

func _initialize() -> void: _run.call_deferred()
func _check(value: bool, label: String) -> bool:
	checks+=1
	if not value: push_error(label);quit(1)
	return value

func _head(label: String) -> Vector3:
	return rig.get_bone_global_pose(rig.find_bone("mixamorig_"+label)).origin

func _capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+label+".png")

func _run() -> void:
	root.unfocusable=true
	root.size=Vector2i(1100,800)
	var args:=OS.get_cmdline_user_args()
	if args.size()<2: push_error("Provide preserved raw animated GLB and output folder");quit(1);return
	folder=args[1]
	DirAccess.make_dir_recursive_absolute(folder)
	var before:=FileAccess.get_sha256(args[0])
	var doc:=GLTFDocument.new()
	var state:=GLTFState.new()
	if not _check(doc.append_from_file(args[0],state)==OK,"Candidate source unreadable"): return
	model=doc.generate_scene(state,24.0,false,false)
	root.add_child(model)
	model.scale=Vector3.ONE*1.8
	rig=model.find_child("Skeleton3D",true,false)
	var anim:=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	pose=PoseStudy.new()
	root.add_child(pose)
	if not _check(pose.setup(rig,anim),"P2 rig/mixer binding failed"): return
	pose.set_process(false)
	if not _check(rig.get_bone_count()==66,"Candidate skeleton changed"): return
	pose.evaluate_source(1.0/24.0)
	if not _check(_head("LeftHand").y<_head("Spine1").y and _head("RightHand").y<_head("Spine1").y,"Candidate resumed T-pose or fighter guard"): return
	var feet:=[_head("LeftFoot"),_head("RightFoot"),_head("LeftToeBase"),_head("RightToeBase")]
	var head:=_head("Head")
	pose.set_contact_count(3)
	pose._impact_age=.16
	pose.evaluate_source(1.0/24.0)
	var impact_head:=_head("Head")
	if not _check(impact_head.z<head.z,"Impact reaction moved head toward incoming contact"): return
	pose._impact_age=2.0
	pose.evaluate_source(1.0/24.0)
	if not _check(_head("Head").z>head.z,"Settled reaction did not lean forward"): return
	var settled:=_head("Head")
	pose.evaluate_source(1.0/24.0)
	if not _check(settled.distance_to(_head("Head"))<0.000001,"Repeated evaluation accumulates procedural deltas"): return
	pose.begin_collar()
	var max_foot_delta:=0.0
	for i in 4:
		var difference: float=feet[i].distance_to(_head(["LeftFoot","RightFoot","LeftToeBase","RightToeBase"][i]))
		max_foot_delta=maxf(max_foot_delta,difference)
		if not _check(difference<0.000001,"Upper-body reactions altered planted source legs"): return
	pose.reduced_motion=true
	var frozen: float=pose._source_time
	pose._process(2.0)
	if not _check(pose._source_time==frozen,"Reduced Motion advanced source idle"): return
	pose.set_contact_count(99)
	if not _check(pose.contacts==3,"Contact presentation exceeded three"): return
	pose._process(2.0)
	if not _check(pose._impact_age>=2.0,"Reduced Motion retained a stale impact for later replay"): return
	pose.reduced_motion=false
	preload("res://scripts/characters/kinja_surface_profile.gd").apply(model)
	var world:=WorldEnvironment.new();world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR
	world.environment.background_color=Color(.045,.055,.07)
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color(.72,.8,.92)
	world.environment.ambient_light_energy=.45;root.add_child(world)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-30,-35,0);sun.light_energy=1.1;sun.shadow_enabled=true;root.add_child(sun)
	var floor:=MeshInstance3D.new();floor.mesh=PlaneMesh.new();floor.mesh.size=Vector2(5,5)
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.13,.16,.19);mat.roughness=.9;floor.material_override=mat;root.add_child(floor)
	var camera:=Camera3D.new();camera.fov=35;camera.far=12;root.add_child(camera);camera.make_current()
	for view in ["front","quarter","side"]:
		camera.position={"front":Vector3(0,1.2,4.1),"quarter":Vector3(2.8,1.25,3.0),"side":Vector3(4.1,1.2,0)}[view]
		camera.look_at(Vector3(0,.94,0))
		for moment in ["idle","hit","settled","collar"]:
			pose.collar=false
			pose.contacts=0 if moment=="idle" else 3
			pose._impact_age=.16 if moment=="hit" else 2.0
			pose.collar=moment=="collar"
			pose.evaluate_source(1.0/24.0)
			await _capture(view+"-"+moment)
	if not _check(before==FileAccess.get_sha256(args[0]),"Study modified preserved source"): return
	var report:={"checks":checks,"source_sha256":before,"fps":24,"bones":66,"source_foot_deltas_from_reaction_m":max_foot_delta,"scope":"Isolated upper-body study only; actual three-hit combat/collar contact, coat skin quality, face acting and runtime replacement remain OPEN"}
	var output:=FileAccess.open(folder+"/study.json",FileAccess.WRITE);output.store_string(JSON.stringify(report,"\t"));output.close()
	print("KINJA_P2_STUDY ",JSON.stringify(report))
	quit(0)
