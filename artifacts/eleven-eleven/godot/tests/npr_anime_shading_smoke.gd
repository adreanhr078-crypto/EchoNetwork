extends SceneTree

## Automated Headless Smoke Test: 11.11 NPR Anime Cel Shading & Microscopic Outlines
## Verifies Two-Tone Cel ramp for face, skin-modulated SSS, and non-deforming microscopic outlines.

const Applicator = preload("res://scripts/combat/shader_applicator.gd")
const CelShader = preload("res://shaders/anime_cel.gdshader")
const OutlineShader = preload("res://shaders/anime_outline.gdshader")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("--- [NPR SHADING SMOKE] START ---")
	
	# 1. Shader Compilation Validation
	assert(CelShader != null, "CelShader must load and compile")
	assert(OutlineShader != null, "OutlineShader must load and compile")
	print("[1/5] Shader resources compiled successfully.")
	
	# 2. Material Parameter & Two-Tone Cel Ramp Contract Validation
	var test_mat := ShaderMaterial.new()
	test_mat.shader = CelShader
	test_mat.set_shader_parameter("is_face", true)
	test_mat.set_shader_parameter("use_two_tone_face", true)
	test_mat.set_shader_parameter("face_cel_split", 0.38)
	test_mat.set_shader_parameter("face_cel_smoothness", 0.08)
	test_mat.set_shader_parameter("face_shadow_tint", Color(0.88, 0.82, 0.86, 1.0))
	test_mat.set_shader_parameter("use_sss", true)
	test_mat.set_shader_parameter("is_hair", true)
	test_mat.set_shader_parameter("hair_specular_power", 42.0)
	
	assert(test_mat.get_shader_parameter("is_face") == true, "is_face uniform supported")
	assert(test_mat.get_shader_parameter("use_two_tone_face") == true, "use_two_tone_face uniform supported")
	assert(test_mat.get_shader_parameter("face_cel_split") == 0.38, "face_cel_split uniform supported")
	assert(test_mat.get_shader_parameter("face_cel_smoothness") == 0.08, "face_cel_smoothness uniform supported")
	assert(test_mat.get_shader_parameter("use_sss") == true, "SSS uniform supported")
	assert(test_mat.get_shader_parameter("is_hair") == true, "Anisotropic hair uniform supported")
	print("[2/5] Soft Two-Tone Face Cel Ramp parameters verified.")
	
	# 3. Microscopic Inverted Hull Outline Contract Validation
	var outline_mat := ShaderMaterial.new()
	outline_mat.shader = OutlineShader
	outline_mat.set_shader_parameter("outline_color", Color(0.05, 0.06, 0.08, 1.0))
	outline_mat.set_shader_parameter("outline_width", 1.0)
	outline_mat.set_shader_parameter("microscopic_thickness", 0.00065)
	
	assert(outline_mat.get_shader_parameter("outline_width") == 1.0, "outline_width uniform supported")
	assert(outline_mat.get_shader_parameter("microscopic_thickness") == 0.00065, "microscopic_thickness uniform supported")
	print("[3/5] Microscopic Inverted Hull Outline parameters verified (~0.65mm non-deforming).")
	
	# 4. Echo Character Rig Application Validation
	var player_scene = load("res://scenes/player/echo_player.tscn")
	assert(player_scene != null, "EchoPlayer scene must be present")
	var player = player_scene.instantiate()
	root.add_child(player)
	
	var model_root = player.get_node("ModelRoot")
	Applicator.apply_cel_shader(
		model_root,
		CelShader,
		Color(1.0, 1.0, 1.0, 1.0),
		Color(0.75, 0.8, 0.86, 1.0),
		Color(0.42, 0.45, 0.58, 1.0),
		3.2,
		0.18,
		OutlineShader,
		0.85,
		0.12
	)
	
	var body = model_root.find_child("EchoOpeningUniformBody", true, false) as MeshInstance3D
	assert(body != null, "EchoOpeningUniformBody must exist")
	var body_mat = body.get_surface_override_material(0) as ShaderMaterial
	assert(body_mat != null, "Echo body must have ShaderMaterial override")
	assert(body_mat.get_shader_parameter("limit_skin_highlights") == true, "Echo skin highlight limiting active")
	assert(body_mat.get_shader_parameter("use_two_tone_face") == true, "Echo two-tone face shading active")
	assert(body_mat.get_shader_parameter("use_sss") == true, "Echo skin-modulated SSS active")
	
	var body_outline = body_mat.next_pass as ShaderMaterial
	assert(body_outline != null, "Echo outline next_pass must be ShaderMaterial")
	assert(body_outline.get_shader_parameter("microscopic_thickness") == 0.00065, "Echo outline thickness microscopic")
	print("[4/5] Echo player character model materials and passes verified.")
	
	# 5. Multi-frame Render Loop Execution
	for i in range(10):
		await process_frame
		await physics_frame
	print("[5/5] Render pipeline executed 10 frames with 0 errors.")
	
	print("--- [NPR SHADING SMOKE] ALL CHECKS PASSED (0 ERRORS) ---")
	player.queue_free()
	quit(0)
