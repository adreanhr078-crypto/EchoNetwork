extends SceneTree
## Independent wing chains only; no source keys, body simulation or game settings.
var skeleton: Skeleton3D
var body_reference: Dictionary
var baseline: Dictionary
var samples:=0
var finite:=true
var body_error:=0.0
var length_error:=0.0
var maximum_rotation:=0.0
var minimum_tip_y:=INF

func _initialize() -> void: _run.call_deferred()
func _sample() -> void:
	samples+=1
	for bone in skeleton.get_bone_count():
		var pose:=skeleton.get_bone_global_pose(bone)
		finite=finite and pose.origin.is_finite() and pose.basis.is_finite()
		if body_reference.has(bone):
			body_error=maxf(body_error,pose.origin.distance_to(body_reference[bone].origin))
			continue
		var parent:=skeleton.get_bone_parent(bone)
		if parent>=0:
			var length:=pose.origin.distance_to(skeleton.get_bone_global_pose(parent).origin)
			length_error=maxf(length_error,absf(length-skeleton.get_bone_rest(bone).origin.length()))
		var difference:=pose.basis.get_rotation_quaternion().angle_to(baseline[bone].basis.get_rotation_quaternion())
		maximum_rotation=maxf(maximum_rotation,difference)
		minimum_tip_y=minf(minimum_tip_y,skeleton.to_global(pose.origin).y)

func _run() -> void:
	var args:=OS.get_cmdline_user_args()
	Engine.max_fps=60
	Engine.physics_ticks_per_second=int(args[1])
	var world:=Node3D.new();root.add_child(world)
	var actor=load("res://candidate.glb").instantiate();world.add_child(actor)
	var captures:=[]
	var camera: Camera3D
	if args.has("--render"):
		root.size=Vector2i(600,800);root.unfocusable=true
		var environment:=WorldEnvironment.new();environment.environment=Environment.new()
		environment.environment.background_mode=Environment.BG_COLOR
		environment.environment.background_color=Color(.035,.045,.065)
		environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color=Color(.65,.72,.85)
		environment.environment.ambient_light_energy=.55
		var sky:=Sky.new();var sky_material:=ProceduralSkyMaterial.new()
		sky_material.sky_top_color=Color(.45,.52,.65);sky_material.sky_horizon_color=Color(.75,.75,.75)
		sky_material.ground_bottom_color=Color(.12,.15,.2);sky_material.ground_horizon_color=Color(.35,.4,.5)
		sky.sky_material=sky_material;environment.environment.sky=sky
		environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_SKY
		environment.environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
		world.add_child(environment)
		var light:=DirectionalLight3D.new();light.rotation=Vector3(-.6,-.65,0);light.light_energy=1.3;world.add_child(light)
		var rim:=DirectionalLight3D.new();rim.rotation=Vector3(-.3,2.4,0);rim.light_energy=.65;world.add_child(rim)
		camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.25;world.add_child(camera);camera.make_current()
	skeleton=actor.find_child("Skeleton3D",true,false)
	if not skeleton or skeleton.get_bone_count()!=72:push_error("Pact72 identity unavailable");quit(2);return
	for frame in 3:await process_frame
	var scale_ok: bool=skeleton.global_basis.get_scale().distance_to(Vector3.ONE)<1e-5
	for bone in skeleton.get_bone_count():
		baseline[bone]=skeleton.get_bone_global_pose(bone)
		if not skeleton.get_bone_name(bone).begins_with("Wing"):body_reference[bone]=baseline[bone]
	var spring:=SpringBoneSimulator3D.new()
	skeleton.add_child(spring)
	spring.setting_count=4
	var chains:=[["WingRootLeft","WingTipLeft",.15],["WingFanInnerLeft","WingFanInnerLeft",.33],["WingFanMidLeft","WingFanMidLeft",.54],["WingFanOuterLeft","WingFanOuterLeft",.96]]
	for index in chains.size():
		spring.set_root_bone_name(index,chains[index][0])
		spring.set_end_bone_name(index,chains[index][1])
		spring.set_extend_end_bone(index,true)
		spring.set_end_bone_length(index,chains[index][2])
		spring.set_stiffness(index,2.0)
		spring.set_drag(index,.6)
		spring.set_gravity(index,.18)
		spring.set_radius(index,.012)
		spring.set_center_from(index,SpringBoneSimulator3D.CENTER_FROM_BONE)
		spring.set_center_bone_name(index,"mixamorig_Spine2")
	var chest:=SpringBoneCollisionCapsule3D.new()
	chest.radius=.16;chest.height=.70
	spring.add_child(chest)
	var center: Vector3=skeleton.to_global((skeleton.get_bone_global_rest(skeleton.find_bone("mixamorig_Hips")).origin+skeleton.get_bone_global_rest(skeleton.find_bone("mixamorig_Neck")).origin)*.5)
	chest.global_transform=Transform3D(Basis.IDENTITY,center)
	for index in chains.size():spring.set_enable_all_child_collisions(index,true)
	spring.modification_processed.connect(_sample)
	for frame in 180:
		var time:=float(frame)/Engine.physics_ticks_per_second
		spring.external_force=Vector3(.12*sin(time*2),0,.08*cos(time*2))
		await physics_frame
		await process_frame
		if camera and frame in [0,60,120,179]:
			var view: String=["front","side","back","front"][int(frame/60)]
			var target:=Vector3(.08,.9,-.35)
			camera.position=target+({"front":Vector3(0,0,4),"side":Vector3(4,0,0),"back":Vector3(0,0,-4)}[view])
			camera.look_at(target)
			await RenderingServer.frame_post_draw
			var path: String=args[0].get_base_dir().path_join("spring-%03d-%s.png"%[frame,view])
			root.get_texture().get_image().save_png(path)
			captures.append({"path":path,"sha256":FileAccess.get_sha256(path)})
	var before:=samples
	paused=true
	for frame in 8:await process_frame
	var pause_ok:=samples==before
	paused=false
	spring.active=false
	skeleton.reset_bone_poses()
	for frame in 4:await process_frame
	var reduced_ok:=samples==before
	var passed:=scale_ok and finite and body_error<1e-5 and length_error<1e-5 and maximum_rotation>.005 and maximum_rotation<.8 and pause_ok and reduced_ok
	var report:={"status":"PASS_ISOLATED_NATIVE_SPRING" if passed else "FAIL","physics_hz":Engine.physics_ticks_per_second,"ticks":180,"modifier_samples":samples,"unscaled_skeleton":scale_ok,"finite":finite,"body_bones":body_reference.size(),"body_position_error_m":body_error,"bone_length_error_m":length_error,"maximum_wing_rotation_rad":maximum_rotation,"minimum_wing_joint_height_m":minimum_tip_y,"pause_freezes":pause_ok,"disabled_reduced_motion_stops_solver":reduced_ok,"scope":"Pact72 isolated native spring articulation and body/length/pause invariants;capsule configured,mesh contact and gameplay unqualified"}
	report.captures=captures
	report.source_sha256=FileAccess.get_sha256("res://candidate.glb")
	report.driver_sha256=FileAccess.get_sha256(get_script().resource_path)
	var file:=FileAccess.open(args[0],FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("CONTRACT_SPRING ",JSON.stringify(report))
	world.queue_free();await process_frame;quit(0 if passed else 1)
