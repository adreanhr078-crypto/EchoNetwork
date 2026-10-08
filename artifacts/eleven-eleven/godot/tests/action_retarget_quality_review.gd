extends SceneTree
var player: EchoPlayer
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var after := not OS.get_cmdline_user_args().has("--before")
	var args := OS.get_cmdline_user_args()
	var action := "ATTACK_1"
	for key in preload("res://scripts/player/mixamo_animation_bridge.gd").ANIM_DEFS:
		if args.has(key): action=key
	root.size=Vector2i(960,540)
	var env := WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color(0.13,0.16,0.2)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_energy=0.6
	root.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-40,-25,0)
	light.light_energy=0.8
	root.add_child(light)
	var floor := StaticBody3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size=Vector3(30,0.2,30)
	mesh.mesh=box
	floor.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=box.size
	collision.shape=shape
	floor.add_child(collision)
	floor.position.y=-0.1
	root.add_child(floor)
	player=load("res://scenes/player/echo_player.tscn").instantiate()
	root.add_child(player)
	player.finish_opening_recovery()
	for i in range(20): await physics_frame
	player.set_physics_process(false)
	player.set_process(false)
	var cam := Camera3D.new()
	cam.position=Vector3(2.5,1.9,2.6)
	cam.fov=45
	root.add_child(cam)
	cam.look_at(Vector3(0,1.0,0))
	cam.current=true
	var source_path: String = ""
	for path in preload("res://scripts/player/mixamo_animation_bridge.gd").ANIM_DEFS[action]:
		if ResourceLoader.exists(path):
			source_path=path
			break
	var source = load(source_path).instantiate()
	root.add_child(source)
	source.hide()
	var source_rig := source.find_child("Skeleton3D",true,false) as Skeleton3D
	var source_ap := source.find_child("AnimationPlayer",true,false) as AnimationPlayer
	print("SOURCE ",source_path," clips=",source_ap.get_animation_list())
	for name in source_ap.get_animation_list():
		var a: Animation = source_ap.get_animation(name)
		print("SOURCE CLIP ",name," duration=",a.length," first=",a.track_get_path(0)," type=",a.track_get_type(0))
	var target := player.find_child("Skeleton3D",true,false) as Skeleton3D
	var mapping: Dictionary = preload("res://scripts/player/mixamo_animation_bridge.gd").BONE_MAP.duplicate()
	if after:
		var source_clip: Animation = source_ap.get_animation("mixamo_com") if source_ap.has_animation("mixamo_com") else source_ap.get_animation(source_ap.get_animation_list()[0])
		var clip: Animation = preload("res://scripts/player/rest_pose_action_retarget.gd").adapt(source_clip,source_rig,target,mapping,"EchoOpeningUniformRig/Skeleton3D")
		if not clip:
			push_error("Target anatomy contract failed")
			quit(1)
			return
		player.animation_player.get_animation_library("").add_animation("ACTION_REVIEW",clip)
	player.animation_player.play("ACTION_REVIEW" if after else action,0)
	var folder := ProjectSettings.globalize_path("res://../audits/evidence/quality-repair-20261006/actions-"+("adapted" if after else "raw")+"/"+action+"/")
	DirAccess.make_dir_recursive_absolute(folder)
	var count := int(ceil(player.animation_player.current_animation_length*60))+1
	for frame in range(count):
		player.animation_player.seek(frame/60.0,true)
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			if frame%15==0: root.get_texture().get_image().save_png(folder+"%03d.png" % frame)
		for bone in target.get_bone_count():
			if not target.get_bone_global_pose(bone).is_finite():
				push_error("Non-finite retarget")
				quit(1)
				return
	print("CAPTURED action retarget: ",folder)
	player.queue_free()
	source.queue_free()
	await process_frame
	quit()
