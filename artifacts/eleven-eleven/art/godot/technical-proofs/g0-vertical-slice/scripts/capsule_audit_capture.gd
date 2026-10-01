extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--audit-output="):
			output = arg.trim_prefix("--audit-output=")
	if output.is_empty():
		push_error("Missing --audit-output absolute PNG path")
		quit(1)
		return

	var stage := Node3D.new()
	root.add_child(stage)
	var packed := load("res://assets/candidates/Sector11_WakeCapsule_G0_Runtime.glb") as PackedScene
	if packed == null:
		push_error("Capsule asset failed to load")
		quit(1)
		return
	var capsule := packed.instantiate()
	capsule.position = Vector3(0.52, 0.0, 0.0)
	capsule.rotation_degrees.y = 180.0
	stage.add_child(capsule)

	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#020711")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#4a7898")
	environment.ambient_light_energy = 0.34
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.18
	world_environment.environment = environment
	stage.add_child(world_environment)

	_add_light(stage, Vector3(-2.4, 3.4, -3.0), Color("#8fdfff"), 9.0, 5.0)
	_add_light(stage, Vector3(2.8, 2.4, -1.2), Color("#276d9b"), 6.0, 4.0)
	_add_light(stage, Vector3(0.0, 2.6, 2.8), Color("#12d7ff"), 7.0, 4.0)

	var camera := Camera3D.new()
	camera.position = Vector3(2.75, 2.20, -4.55)
	camera.fov = 38.0
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.22, 0.0), Vector3.UP)
	stage.add_child(camera)
	camera.current = true

	for frame in range(30):
		await process_frame
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	var result := screenshot.save_png(output)
	print("G0_CAPSULE_CAPTURE_RESULT=", result)
	quit(0 if result == OK else 1)


func _add_light(parent: Node3D, position: Vector3, color: Color, energy: float, range_value: float) -> void:
	var light := OmniLight3D.new()
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	parent.add_child(light)
