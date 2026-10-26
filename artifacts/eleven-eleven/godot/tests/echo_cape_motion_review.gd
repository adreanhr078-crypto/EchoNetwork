extends SceneTree
const Cape = preload("res://engine_visuals/EchoCapeMotion.gd")
var checks:=0
var folder:=""
func _initialize() -> void: _run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok: push_error(label);quit(1);assert(ok,label)
func capture(name:String) -> void:
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name+".png")
func _run() -> void:
	folder=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,720)
	var world:=Node3D.new();root.add_child(world)
	var env:=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color(0.025,0.04,0.065)
	env.environment.ambient_light_energy=0.65
	world.add_child(env)
	var key:=DirectionalLight3D.new();key.rotation_degrees=Vector3(-35,-40,0);key.light_energy=0.75;world.add_child(key)
	var player=load("res://scenes/player/echo_player.tscn").instantiate();world.add_child(player)
	player.finish_opening_recovery();player.set_physics_process(false);player.set_process(false)
	var model:Node3D=player.get_node("ModelRoot/EchoOpeningUniform")
	var skeleton:Skeleton3D=model.find_child("Skeleton3D",true,false)
	var ap:AnimationPlayer=player.animation_player
	var native_cape:Node=model.find_child("EchoCapeMotion",true,false)
	if native_cape: native_cape.active=false
	ap.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var cape=Cape.new();cape.name="EchoCapeMotion";skeleton.add_child(cape)
	check(cape.configure(player),"Actual V31 garment did not configure")
	cape.active=false # Deterministic source-clock inspection; real modifier is post-mixer.
	var hyper=root.get_node("HyperAnimeWorldManager");hyper.attach_scene(world,player)
	hyper.set_quality("high")
	var camera:=Camera3D.new();camera.fov=31;world.add_child(camera);camera.make_current()
	var material_count:=0
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			check(mesh.get_active_material(surface) is ShaderMaterial,"Echo bypassed custom shader")
			material_count+=1
	check(material_count>0,"No current Echo material checked")
	var max_angle:=0.0
	var states:={}
	var garment_base:={}
	for bone in skeleton.get_bone_count():
		if skeleton.get_bone_name(bone).begins_with("Cape_"): garment_base[bone]=skeleton.get_bone_pose(bone)
	for clip in ["IDLE","RUN","preset_jump"]:
		player.velocity=Vector3(0,0,7) if clip=="RUN" else Vector3.ZERO
		for sample in 91:
			# Direct invocation bypasses SkeletonModifier3D's automatic restoration.
			# Restore the original garment input before each independent mixer sample.
			for bone in garment_base: skeleton.set_bone_pose(bone,garment_base[bone])
			var t:=float(sample)/60.0
			ap.play(clip,0);ap.seek(fmod(t,ap.get_animation(clip).length),true);ap.pause()
			var before:=[]
			for bone in skeleton.get_bone_count(): before.append(skeleton.get_bone_pose(bone))
			cape._process_modification_with_delta(1.0/60.0)
			for bone in skeleton.get_bone_count():
				if not skeleton.get_bone_name(bone).begins_with("Cape_"):
					check(skeleton.get_bone_pose(bone).is_equal_approx(before[bone]),"Cape moved protected body joint: "+skeleton.get_bone_name(bone))
			for angle in cape._angles: max_angle=maxf(max_angle,angle)
		states[clip]=Array(cape._angles)
		camera.position=Vector3(1.95,1.2,-3.1);camera.look_at(Vector3(0,1.0,0))
		await capture(clip.to_lower()+"-cape")
	check(max_angle>deg_to_rad(4.0) and max_angle<=deg_to_rad(12.01),"Cape response absent or unbounded")
	# Replaying an identical original sample under Reduced Motion yields exactly
	# the source's fifteen garment transforms, not stale offsets or wind.
	player.reduced_motion=true
	for bone in garment_base: skeleton.set_bone_pose(bone,garment_base[bone])
	ap.play("RUN",0);ap.seek(0.8,true);ap.pause()
	var original:=[]
	for bone in skeleton.get_bone_count(): original.append(skeleton.get_bone_pose(bone))
	cape._process_modification_with_delta(1.0/60.0)
	for bone in skeleton.get_bone_count(): check(skeleton.get_bone_pose(bone).is_equal_approx(original[bone]),"Reduced Motion changed source pose")
	await capture("run-reduced-motion")
	player.reduced_motion=false
	for sample in 90:
		for bone in garment_base: skeleton.set_bone_pose(bone,garment_base[bone])
		ap.play("RUN",0);ap.seek(0.8,true);ap.pause()
		cape._process_modification_with_delta(1.0/60.0)
	await capture("run-same-pose-cape")
	player.reduced_motion=false
	player.control_locked=true
	cape._process_modification_with_delta(1.0/60.0)
	check(cape._angles.count(0.0)==15,"Cinematic retained cloth motion")
	var report:={"checks":checks,"status":"SCOPED_TECHNICAL_PASS","max_spring_angle_degrees":rad_to_deg(max_angle),"states":states,"collision_corrections":cape.collision_corrections,"source_or_skin_modified":false,"visual_acceptance":"REQUIRES_IMAGE_REVIEW","whole_character_animation_accepted":false}
	var file:=FileAccess.open(folder+"/review.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("CAPE_REVIEW ",JSON.stringify(report))
	quit(0)
