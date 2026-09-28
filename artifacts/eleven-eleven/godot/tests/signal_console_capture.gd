extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(960, 960)
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.018, 0.025, 0.035)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.66, 0.74, 0.83)
	environment.environment.ambient_light_energy = 0.45
	scene.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -35, 0)
	light.light_energy = 1.1
	scene.add_child(light)
	var model: Node3D = load("res://scenes/environment/substation_terminal.tscn").instantiate()
	scene.add_child(model)
	var floor := MeshInstance3D.new()
	floor.mesh = PlaneMesh.new()
	floor.mesh.size = Vector2(8, 8)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.055, 0.065, 0.08)
	floor.material_override = floor_material
	scene.add_child(floor)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(2.05, 2.1, 3.25)
	camera.look_at(Vector3(0, 0.95, 0.12))
	camera.fov = 38
	camera.current = true
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../audits/evidence/signal-console-portable-study.png"))
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	print("CONSOLE_PORTABLE animations=", player.get_animation_list() if player else [])
	scene.queue_free()
	await process_frame
	quit(0)
