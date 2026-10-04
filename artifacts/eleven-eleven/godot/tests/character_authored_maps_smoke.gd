extends SceneTree

## Actual imported material ownership plus rendered, channel-specific highlights.
const Applicator = preload("res://scripts/combat/shader_applicator.gd")
const Cel = preload("res://shaders/anime_cel.gdshader")

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var imported = load("res://assets/characters/echo_opening_uniform_v13.glb").instantiate()
	var body := imported.find_child("EchoOpeningUniformBody", true, false) as MeshInstance3D
	if not _check(body != null, "actual Echo mesh missing"): return
	var authored := body.get_active_material(0) as BaseMaterial3D
	var styled := Applicator._make_stylized_material(authored, Cel, Color.WHITE, Color.BLACK, Color.WHITE, 3.2, 0, null, body.name)
	if not _check(styled.get_shader_parameter("roughness_texture") == authored.roughness_texture and styled.get_shader_parameter("metallic_texture") == authored.metallic_texture, "authored PBR textures lost"): return
	if not _check(styled.get_shader_parameter("roughness_channel") == Vector4(0,1,0,0) and styled.get_shader_parameter("metallic_channel") == Vector4(0,0,1,0), "actual ORM channel interpretation changed"): return
	if not _check(styled.get_shader_parameter("metallic") == authored.metallic and styled.get_shader_parameter("metallic_limit") == 0.1, "metallic cap applied before authored sampling"): return
	imported.free()
	if DisplayServer.get_name() == "headless":
		push_error("Map highlight regression requires rendered pixels")
		quit(1)
		return
	root.size = Vector2i(256,256)
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
	world.add_child(light)
	var mesh := MeshInstance3D.new()
	mesh.name = "EchoOpeningUniformMapProbe"
	mesh.mesh = QuadMesh.new()
	mesh.mesh.size = Vector2(3,3)
	var source := StandardMaterial3D.new()
	source.albedo_color = Color.BLACK
	source.roughness = 1
	source.metallic = 0
	source.roughness_texture = _map(Color(0.9,0.2,0.05,1))
	source.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	mesh.mesh.material = source
	world.add_child(mesh)
	Applicator.apply_cel_shader(mesh,Cel,Color.WHITE,Color.BLACK,Color.WHITE,3.2,0,null,1,0)
	var material := mesh.get_active_material(0) as ShaderMaterial
	# Isolate channel transport from the deliberately subdued cloth art response.
	material.set_shader_parameter("specular_color",Color.WHITE)
	var glossy := await _sample()
	material.set_shader_parameter("roughness_texture", _map(Color(0.9,0.8,0.05,1)))
	var rough := await _sample()
	material.set_shader_parameter("roughness_texture", _map(Color(0.1,0.8,0.95,1)))
	var other_channels := await _sample()
	if not _check(glossy > rough * 2.5 and rough > 0.03, "authored roughness does not affect custom specular highlight"): return
	if not _check(absf(other_channels - rough) < 0.002, "roughness read red/blue instead of authored green"): return
	material.set_shader_parameter("use_roughness_texture", false)
	var no_map := await _sample()
	if not _check(no_map < 0.002, "no-map material lost its scalar roughness fallback"): return
	print("MAP_HIGHLIGHTS glossy=",glossy," rough=",rough," other_channels=",other_channels," scalar=",no_map)
	print("PASS actual Echo authored PBR resources/channels, rendered roughness highlight and scalar fallback")
	quit(0)

func _map(color: Color) -> ImageTexture:
	var data := Image.create(4,4,false,Image.FORMAT_RGBAF)
	data.fill(color)
	return ImageTexture.create_from_image(data)

func _sample() -> float:
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var data := root.get_texture().get_image()
	var sum := 0.0
	for y in range(120,136):
		for x in range(120,136):
			var pixel := data.get_pixel(x,y).srgb_to_linear()
			sum += (pixel.r + pixel.g + pixel.b) / 3.0
	return sum / 256

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
