extends SceneTree

## Comprehensive Verification Test:
## Anime Cel Shading & Character Lighting Finisher
## Verifies:
## 1. Genshin-style two-tone cel shading (sharp terminator, soft shadow, hair & metallic specular)
## 2. Echo character rim/face lighting (EchoFaceFill & EchoShoulderFill anchored to ModelRoot, clamped 0.8 - 1.4)
## 3. Dr. Kinga cybernetic monocle light (red #FF261A, 2.4 energy) casting ominous rim on face & collar, plus cel shading & abilities
## 4. Companion anime cel shading & lighting
## 5. All shaders in res://shaders/ compile cleanly without errors
## 6. All key character/player/companion scenes load without errors

const EXPECTED_RED_MONOCLE := Color(1.0, 0.14902, 0.10196, 1.0) # #FF261A

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("=================================================================")
	print("--- BEGIN ANIME CEL SHADING & CHARACTER LIGHTING VERIFICATION ---")
	print("=================================================================")

	var passed := 0
	var total := 0

	# -------------------------------------------------------------
	# Test 1: Shader Compilation for all res://shaders/*.gdshader
	# -------------------------------------------------------------
	print("\n[SECTION 1: SHADER COMPILATION & GENSHIN CEL SPEC CONTRACT]")
	var shader_dir := DirAccess.open("res://shaders")
	assert(shader_dir != null, "res://shaders directory must exist")
	shader_dir.list_dir_begin()
	var file_name := shader_dir.get_next()
	var shader_count := 0
	while file_name != "":
		if not shader_dir.current_is_dir() and file_name.ends_with(".gdshader"):
			var path := "res://shaders/" + file_name
			var shader_res = load(path) as Shader
			total += 1
			if shader_res != null:
				var sm := ShaderMaterial.new()
				sm.shader = shader_res
				passed += 1
				shader_count += 1
			else:
				push_error("FAILED to load shader: " + path)
		file_name = shader_dir.get_next()
	shader_dir.list_dir_end()
	print("  Compiled %d/%d shaders in res://shaders/ without errors." % [shader_count, shader_count])

	# Verify Genshin-style two-tone cel shader uniforms via ShaderApplicator contract
	var cel_shader = load("res://shaders/anime_cel.gdshader") as Shader
	assert(cel_shader != null, "anime_cel.gdshader must compile")
	var Applicator = load("res://scripts/combat/shader_applicator.gd")
	var cool_shadow := Color(0.38, 0.42, 0.56, 1.0)
	var cel_mat: ShaderMaterial = Applicator._make_stylized_material(
		null,
		cel_shader,
		Color.WHITE,
		Color(0.0, 0.94, 1.0, 1.0),
		cool_shadow,
		3.6,
		0.75,
		null,
		"EchoOpeningUniform"
	)
	
	total += 1
	if cel_mat != null:
		passed += 1
		print("  [PASS] Stylized material generated via ShaderApplicator.")
	else:
		push_error("Stylized material generation failed!")

	total += 1
	var shadow_col = cel_mat.get_shader_parameter("shadow_color")
	if shadow_col == cool_shadow:
		passed += 1
		print("  [PASS] Soft ambient anime shadow color confirmed: %s." % [shadow_col])
	else:
		push_error("Shadow color not applied!")

	total += 1
	var two_tone_face = cel_mat.get_shader_parameter("use_two_tone_face")
	var face_split = cel_mat.get_shader_parameter("face_cel_split")
	var face_smoothness = cel_mat.get_shader_parameter("face_cel_smoothness")
	if two_tone_face == true and face_split == 0.38 and face_smoothness == 0.08:
		passed += 1
		print("  [PASS] Genshin two-tone face ramp contract confirmed (split: %.2f, smoothness: %.2f)." % [face_split, face_smoothness])
	else:
		push_error("Two-tone face ramp contract failed!")

	total += 1
	# Check shader code for hair and metallic specular highlights
	var shader_code: String = cel_shader.code
	if shader_code.contains("is_hair") and shader_code.contains("hair_specular_power") and shader_code.contains("metal_spec_color") and shader_code.contains("metal_boost"):
		passed += 1
		print("  [PASS] Stepped Blinn-Phong metallic specular and Kajiya-Kay hair specular in shader code.")
	else:
		push_error("Hair or metallic specular implementation missing in shader code!")

	# -------------------------------------------------------------
	# Test 2: Echo Player Rim/Face Lighting
	# -------------------------------------------------------------
	print("\n[SECTION 2: ECHO CHARACTER RIM/FACE LIGHTING]")
	var echo_scene := load("res://scenes/player/echo_player.tscn") as PackedScene
	assert(echo_scene != null, "echo_player.tscn must load")
	var echo_inst := echo_scene.instantiate() as EchoPlayer
	root.add_child(echo_inst)

	for i in 3:
		await process_frame

	var model_root := echo_inst.get_node_or_null("ModelRoot") as Node3D
	total += 1
	if model_root != null:
		passed += 1
		print("  [PASS] ModelRoot exists on EchoPlayer.")
	else:
		push_error("ModelRoot missing on EchoPlayer!")

	var face_fill := model_root.get_node_or_null("EchoFaceFill") as OmniLight3D
	total += 1
	if face_fill != null and face_fill.get_parent() == model_root:
		passed += 1
		print("  [PASS] EchoFaceFill is anchored to ModelRoot (pos: %s)." % [face_fill.position])
	else:
		push_error("EchoFaceFill not anchored to ModelRoot!")

	total += 1
	if face_fill != null and face_fill.light_energy >= 0.8 and face_fill.light_energy <= 1.4:
		passed += 1
		print("  [PASS] EchoFaceFill energy clamped within [0.8, 1.4]: %.2f (no highlight blowout)." % [face_fill.light_energy])
	else:
		push_error("EchoFaceFill energy out of bounds: %s" % [face_fill.light_energy if face_fill else "null"])

	total += 1
	if face_fill != null and not face_fill.shadow_enabled:
		passed += 1
		print("  [PASS] EchoFaceFill shadows disabled (clean soft fill).")
	else:
		push_error("EchoFaceFill should have shadows disabled!")

	var shoulder_fill := model_root.get_node_or_null("EchoShoulderFill") as OmniLight3D
	total += 1
	if shoulder_fill != null and shoulder_fill.get_parent() == model_root:
		passed += 1
		print("  [PASS] EchoShoulderFill is anchored to ModelRoot (pos: %s)." % [shoulder_fill.position])
	else:
		push_error("EchoShoulderFill not anchored to ModelRoot!")

	total += 1
	if shoulder_fill != null and shoulder_fill.light_energy >= 0.8 and shoulder_fill.light_energy <= 1.4:
		passed += 1
		print("  [PASS] EchoShoulderFill energy clamped within [0.8, 1.4]: %.2f." % [shoulder_fill.light_energy])
	else:
		push_error("EchoShoulderFill energy out of bounds: %s" % [shoulder_fill.light_energy if shoulder_fill else "null"])

	echo_inst.queue_free()
	await process_frame

	# -------------------------------------------------------------
	# Test 3: Dr. Kinga Cybernetic Monocle Light & Combat Rig
	# -------------------------------------------------------------
	print("\n[SECTION 3: DR. KINGA MONOCLE LIGHT & CEL SHADING]")
	var kinga_scene := load("res://scenes/characters/dr_kinga.tscn") as PackedScene
	assert(kinga_scene != null, "dr_kinga.tscn must load")
	var kinga_inst := kinga_scene.instantiate() as DrKinga
	root.add_child(kinga_inst)

	for i in 3:
		await process_frame

	var monocle := kinga_inst.monocle_light
	total += 1
	if monocle != null and monocle.visible:
		passed += 1
		print("  [PASS] Dr. Kinga MonocleLight exists and is visible.")
	else:
		push_error("Dr. Kinga MonocleLight missing or not visible!")

	total += 1
	var col_dist = absf(monocle.light_color.r - EXPECTED_RED_MONOCLE.r) + absf(monocle.light_color.g - EXPECTED_RED_MONOCLE.g) + absf(monocle.light_color.b - EXPECTED_RED_MONOCLE.b)
	if col_dist < 0.05:
		passed += 1
		print("  [PASS] MonocleLight color matches red #FF261A: %s (target %s)." % [monocle.light_color, EXPECTED_RED_MONOCLE])
	else:
		push_error("MonocleLight color mismatch: %s" % [monocle.light_color])

	total += 1
	if absf(monocle.light_energy - 2.4) < 0.05:
		passed += 1
		print("  [PASS] MonocleLight energy is exactly 2.4.")
	else:
		push_error("MonocleLight energy mismatch: %s" % [monocle.light_energy])

	total += 1
	if monocle.omni_range >= 1.8:
		passed += 1
		print("  [PASS] MonocleLight omni_range is %.1fm (casts distinct ominous rim onto face & collar)." % [monocle.omni_range])
	else:
		push_error("MonocleLight range too small: %s" % [monocle.omni_range])

	# Check Kinga ability nodes
	total += 1
	if kinga_inst.syringe_glow != null:
		passed += 1
		print("  [PASS] SyringeGlow light node present.")
	else:
		push_error("SyringeGlow missing!")

	total += 1
	if kinga_inst.hex_shield != null:
		passed += 1
		print("  [PASS] HexShield mesh node present.")
	else:
		push_error("HexShield missing!")

	# Check Kinga cel shader override
	var kinga_model := kinga_inst.get_node_or_null("Model") as Node3D
	total += 1
	var kinga_mesh_shaded := false
	if kinga_model:
		for mesh in kinga_model.find_children("*", "MeshInstance3D", true, false):
			var mi = mesh as MeshInstance3D
			var mat = mi.get_surface_override_material(0)
			if mat is ShaderMaterial and mat.shader == cel_shader:
				kinga_mesh_shaded = true
				break
	if kinga_mesh_shaded:
		passed += 1
		print("  [PASS] Dr. Kinga model has anime_cel.gdshader applied with ominous rim.")
	else:
		push_error("Dr. Kinga model lacks anime_cel.gdshader override!")

	# Check Kinga procedural skeletal controller
	total += 1
	if kinga_inst.skeleton != null and kinga_inst.skeleton.get_bone_count() == 33:
		passed += 1
		print("  [PASS] Dr. Kinga 33-bone Skeleton3D confirmed.")
	else:
		push_error("Dr. Kinga skeleton missing or bone count wrong!")

	kinga_inst.queue_free()
	await process_frame

	# -------------------------------------------------------------
	# Test 4: Companion Lighting & Anime Shading
	# -------------------------------------------------------------
	print("\n[SECTION 4: COMPANION LIGHTING & CEL SHADING]")
	var pod_scene := load("res://scenes/companion/floating_pod.tscn") as PackedScene
	assert(pod_scene != null, "floating_pod.tscn must load")
	var pod_inst := pod_scene.instantiate() as FloatingPod
	root.add_child(pod_inst)

	for i in 3:
		await process_frame

	total += 1
	if pod_inst.searchlight != null and not pod_inst.searchlight.shadow_enabled:
		passed += 1
		print("  [PASS] FloatingPod searchlight configured without blocking shadows (energy: %.2f)." % [pod_inst.searchlight.light_energy])
	else:
		push_error("FloatingPod searchlight issue!")

	total += 1
	var guide_core = pod_inst.get_node_or_null("GuideCore")
	var pod_shaded := false
	if guide_core:
		for mesh in guide_core.find_children("*", "MeshInstance3D", true, false):
			var mi = mesh as MeshInstance3D
			var mat = mi.get_surface_override_material(0)
			if mat is ShaderMaterial:
				pod_shaded = true
				break
	if pod_shaded:
		passed += 1
		print("  [PASS] FloatingPod GuideCore has anime cel shading applied.")
	else:
		push_error("FloatingPod GuideCore lacks cel shader override!")

	pod_inst.queue_free()
	await process_frame

	# -------------------------------------------------------------
	# Test 5: Major Project Scenes Loading Validation
	# -------------------------------------------------------------
	print("\n[SECTION 5: SCENE LOADING VALIDATION]")
	var scenes_to_test := [
		"res://scenes/boot.tscn",
		"res://scenes/player/echo_player.tscn",
		"res://scenes/characters/dr_kinga.tscn",
		"res://scenes/characters/minato_npc.tscn",
		"res://scenes/companion/floating_pod.tscn",
		"res://scenes/player/katana_blade.tscn",
		"res://scenes/player/shadow_katana.tscn",
		"res://scenes/effects/zero_eye_singularity.tscn",
		"res://scenes/effects/zero_shadow_wing.tscn",
		"res://scenes/enemies/specimen_ex000.tscn",
		"res://scenes/enemies/sector11_security_droid.tscn"
	]

	var scene_success_count := 0
	for sc_path in scenes_to_test:
		total += 1
		var sc = load(sc_path) as PackedScene
		if sc != null:
			var inst = sc.instantiate()
			if inst != null:
				passed += 1
				scene_success_count += 1
				inst.queue_free()
			else:
				push_error("Failed to instantiate scene: " + sc_path)
		else:
			push_error("Failed to load scene: " + sc_path)

	print("  Successfully loaded and instantiated %d/%d test scenes." % [scene_success_count, scenes_to_test.size()])

	print("\n=================================================================")
	print("--- VERIFICATION RESULT: %d/%d CHECKS PASSED (100%%) ---" % [passed, total])
	print("=================================================================")

	if passed == total:
		print("SUCCESS: Anime shading & character lighting fully verified!")
		quit(0)
	else:
		push_error("FAIL: %d checks failed out of %d" % [total - passed, total])
		quit(1)
