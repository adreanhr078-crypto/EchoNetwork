extends SceneTree

## Render the real applicator/shader under a single front/back light.
const Applicator = preload("res://scripts/combat/shader_applicator.gd")
const CelShader = preload("res://shaders/anime_cel.gdshader")

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Light-response regression requires rendered pixels")
		quit(1)
		return
	root.size = Vector2i(256, 256)
	root.content_scale_size = root.size
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.BLACK
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.add_child(environment)
	var camera := Camera3D.new()
	camera.position.z = 3
	camera.current = true
	world.add_child(camera)
	var light := DirectionalLight3D.new()
	light.light_energy = 0.4
	light.light_color = Color.WHITE
	light.shadow_enabled = false
	world.add_child(light)
	var mesh := MeshInstance3D.new()
	mesh.name = "EchoOpeningUniformLightProbe"
	mesh.mesh = QuadMesh.new()
	mesh.mesh.size = Vector2(3, 3)
	var source := StandardMaterial3D.new()
	source.albedo_color = Color(0.5, 0.5, 0.5)
	source.roughness = 1.0
	mesh.mesh.material = source
	world.add_child(mesh)
	Applicator.apply_cel_shader(mesh, CelShader, Color.WHITE, Color.BLACK, Color(0.42, 0.45, 0.58), 3.2, 0, null, 1, 0)
	var material := mesh.get_active_material(0) as ShaderMaterial
	material.set_shader_parameter("limit_skin_highlights", false)
	var front := await _sample()
	mesh.set_surface_override_material(0, source)
	var native_front := await _sample()
	mesh.set_surface_override_material(0, material)
	light.rotation.y = PI
	var behind := await _sample()
	print("LIGHT_RESPONSE front=", front, " native_front=", native_front, " behind=", behind)
	if front < 0.05 or behind > front * 0.03:
		push_error("Echo receives excessive diffuse energy from a light behind the surface")
		quit(1)
		return
	if absf(front - native_front) > native_front * 0.08:
		push_error("Echo front-lit albedo energy differs from native material reference")
		quit(1)
		return
	material.set_shader_parameter("normalize_light_response", false)
	var legacy_behind := await _sample()
	if legacy_behind < front * 0.05:
		push_error("Non-Echo legacy shader response changed")
		quit(1)
		return
	# A real non-Echo material must retain default response through applicator.
	mesh.set_surface_override_material(0, source)
	mesh.name = "NonEchoLightProbe"
	Applicator.apply_cel_shader(mesh, CelShader, Color.WHITE, Color.BLACK, Color(0.42, 0.45, 0.58), 3.2, 0, null, 1, 0)
	var untouched_behind := await _sample()
	if absf(untouched_behind - legacy_behind) > maxf(0.0005, legacy_behind * 0.03):
		push_error("Non-Echo applicator unexpectedly enables Echo light calibration")
		quit(1)
		return
	print("PASS rendered Echo hemisphere response; non-Echo legacy response preserved")
	quit(0)

func _sample() -> float:
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	var sum := 0.0
	for y in range(120, 136):
		for x in range(120, 136):
			var value := capture.get_pixel(x, y).srgb_to_linear()
			sum += (value.r + value.g + value.b) / 3.0
	return sum / 256.0
