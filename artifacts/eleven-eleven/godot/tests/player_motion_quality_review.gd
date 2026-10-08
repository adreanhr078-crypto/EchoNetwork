extends SceneTree

## Actual existing avatar/controller on a neutral measured floor. No source edits.
var player: EchoPlayer
var world: Node3D
var folder: String
var trace := []
var frame := 0
var capture_interval := 15

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var label := args[0].validate_filename() if not args.is_empty() else "before"
	if args.has("--dense"): capture_interval = 1
	folder = ProjectSettings.globalize_path("res://../audits/evidence/quality-repair-20261006/motion-" + label + "/")
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(960, 540)
	world = Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.13, 0.16, 0.21)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_energy = 0.7
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -25, 0)
	light.light_energy = 1.2
	world.add_child(light)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(100, 0.2, 100)
	floor_body.position.y = -0.1
	floor_body.add_child(shape)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = BoxMesh.new()
	floor_mesh.mesh.size = shape.shape.size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.36, 0.42)
	mat.roughness = 0.95
	floor_mesh.material_override = mat
	floor_body.add_child(floor_mesh)
	world.add_child(floor_body)
	player = load("res://scenes/player/echo_player.tscn").instantiate()
	world.add_child(player)
	player.finish_opening_recovery()
	player.set_combat_available(false)
	player.set_gameplay_orbit(Vector3(0.06, PI * 0.5, 0))
	player.camera_boom.spring_length = 3
	for i in range(15): await physics_frame
	await _segment("idle", Vector2.ZERO, 60)
	await _segment("walk", Vector2(0, -0.45), 90)
	await _segment("run", Vector2(0, -1), 120)
	await _segment("turn", Vector2(1, 0), 45)
	await _segment("stop", Vector2.ZERO, 60)
	var file := FileAccess.open(folder + "trace.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"CAPTURED_FOR_REVIEW", "source_motion_edited":false, "physical_phone":false, "frames":trace}, "\t"))
	file.close()
	world.queue_free()
	await process_frame
	await physics_frame
	print("PASS captured actual motion: ", folder)
	quit()

func _segment(label: String, stick: Vector2, count: int) -> void:
	player.set_mobile_input_vector(stick, not stick.is_zero_approx())
	var skeleton := player.find_child("Skeleton3D", true, false) as Skeleton3D
	for i in range(count):
		await process_frame
		await RenderingServer.frame_post_draw
		var toes := []
		for name in ["tripo__1_Left_Limb_3", "tripo__1_Right_Limb_3"]:
			var index := skeleton.find_bone(name)
			var pos := skeleton.global_transform * skeleton.get_bone_global_pose(index).origin
			toes.append([pos.x, pos.y, pos.z])
		trace.append({"frame":frame,"label":label,"clip":player.current_anim,"speed":Vector2(player.velocity.x,player.velocity.z).length(),"rate":player.animation_player.speed_scale,"clip_time":player.animation_player.current_animation_position,"root_y":player.visual_root.position.y,"root_euler":[player.visual_root.rotation.x,player.visual_root.rotation.y,player.visual_root.rotation.z],"toes":toes,"grounded":player.is_on_floor()})
		if i % capture_interval == 0: root.get_texture().get_image().save_png(folder + "%05d.png" % frame)
		frame += 1
