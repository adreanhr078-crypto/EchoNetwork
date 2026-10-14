extends SceneTree

const EyeScene = preload("res://scenes/player/zero_eye_singularity.tscn")
const WingScene = preload("res://scenes/player/zero_shadow_wing.tscn")
const EchoScene = preload("res://assets/characters/echo_opening_uniform_v13.glb")
var output := "res://../audits/evidence/zero-manifestation-20261009/v4"
var viewport: SubViewport
var camera: Camera3D
var player: Authority
var eye: Node3D
var wing: Node3D
var records := []
var import_fingerprints := {}
const RUN_FILES := ["res://scripts/player/zero_eye_singularity.gd", "res://scripts/player/zero_shadow_wing.gd", "res://scripts/player/zero_manifestation_attachment.gd", "res://scripts/player/echo_rig_profile.gd", "res://scenes/player/zero_eye_singularity.tscn", "res://scenes/player/zero_shadow_wing.tscn", "res://shaders/zero_feather_detail.gdshader", "res://assets/characters/echo_shadow_wing_feathers_v1.glb", "res://assets/characters/echo_opening_uniform_v13.glb", "res://tests/zero_manifestation_capture.gd"]

class Authority extends Node3D:
	var contract_with_zero_sealed := false
	var reduced_motion := false

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var frozen := {}
	for path in RUN_FILES: frozen[path] = FileAccess.get_sha256(path)
	var checked := {}
	for path in RUN_FILES:
		if not guard_current_import(path, checked):
			quit(2)
			return
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	DirAccess.make_dir_recursive_absolute(output + "/motion")
	viewport = SubViewport.new()
	viewport.size = Vector2i(960, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.012, 0.016, 0.035)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.47, 0.46, 0.61)
	settings.ambient_light_energy = 0.56
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	stage.add_child(environment)
	for spec in [[Vector3(2.0, 2.4, -1.1), Color(0.82, 0.78, 0.90), 2.6], [Vector3(-1.5, 2.1, 1.5), Color(0.24, 0.10, 0.62), 1.8]]:
		var light := OmniLight3D.new()
		light.position = spec[0]
		light.light_color = spec[1]
		light.light_energy = spec[2]
		light.omni_range = 6.0
		stage.add_child(light)
	player = Authority.new()
	stage.add_child(player)
	var model := Node3D.new()
	model.name = "ModelRoot"
	player.add_child(model)
	var avatar := EchoScene.instantiate() as Node3D
	avatar.name = "EchoOpeningUniform"
	avatar.scale = Vector3.ONE * 1.72
	model.add_child(avatar)
	eye = EyeScene.instantiate() as Node3D
	model.add_child(eye)
	wing = WingScene.instantiate() as Node3D
	model.add_child(wing)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.45
	camera.near = 0.025
	viewport.add_child(camera)
	camera.current = true
	await process_frame
	assert(eye.mount_valid and wing.mount_valid)
	eye.set_process(false)
	wing.set_process(false)
	await capture("01-dormant", Vector3(3, 1.34, 0.10), Vector3(0, 1.28, 0.10), 2.25)
	player.contract_with_zero_sealed = true
	eye.activate_singularity(0.80)
	wing.manifest_wing(0.80)
	for frame in 24:
		eye._process(1.0 / 30.0)
		wing._process(1.0 / 30.0)
	await capture("02-pact-front", Vector3(3, 1.55, -0.50), Vector3(0, 1.52, -0.45), 2.5)
	eye.visible = false
	eye.eye_light.visible = false
	await capture("03a-iris-source", Vector3(0.80, 1.553, -0.031), Vector3(0.1588, 1.553, -0.031), 0.29)
	eye.visible = true
	eye._set_presentation(0.8, false)
	await capture("03b-iris-contract", Vector3(0.80, 1.553, -0.031), Vector3(0.1588, 1.553, -0.031), 0.29)
	await capture("04-wing-back", Vector3(-3, 1.55, -0.45), Vector3(0, 1.51, -0.45), 2.5)
	var bone: int = eye.attachment.bone_index
	var skeleton: Skeleton3D = eye.attachment.skeleton
	skeleton.set_bone_pose_rotation(bone, Quaternion(Vector3.UP, 0.23))
	skeleton.force_update_all_bone_transforms()
	eye.attachment.update_socket()
	eye.visible = false
	eye.eye_light.visible = false
	await capture("05a-head-turn-source-eye", Vector3(0.90, 1.553, -0.07), Vector3(0.1588, 1.553, -0.03), 0.40)
	eye.visible = true
	eye._set_presentation(0.8, false)
	await capture("05b-head-turn-contract-eye", Vector3(0.90, 1.553, -0.07), Vector3(0.1588, 1.553, -0.03), 0.40)
	skeleton.reset_bone_pose(bone)
	skeleton.force_update_all_bone_transforms()
	eye.attachment.update_socket()
	player.reduced_motion = true
	eye._process(0.01)
	wing._process(0.01)
	await capture("06-reduced", Vector3(3, 1.55, -0.50), Vector3(0, 1.52, -0.45), 2.5)
	player.reduced_motion = false
	wing.set_quality_tier(0)
	wing._process(0.01)
	await capture("07-low-tier", Vector3(3, 1.55, -0.50), Vector3(0, 1.52, -0.45), 2.5)
	wing.set_quality_tier(2)
	camera.position = Vector3(3, 1.55, -0.50)
	camera.look_at(Vector3(0, 1.52, -0.45))
	camera.size = 2.5
	var motion_records := []
	for frame in 72:
		eye._process(1.0 / 30.0)
		wing._process(1.0 / 30.0)
		await process_frame
		RenderingServer.force_draw()
		var motion_path := output + "/motion/%04d.png" % frame
		assert(viewport.get_texture().get_image().save_png(motion_path) == OK)
		var pose := []
		for fin in wing.feather_skeleton.get_bone_count():
			pose.append(var_to_str(wing.feather_skeleton.get_bone_pose_rotation(fin)))
		motion_records.append({"frame":frame,"time":wing.local_time,"pose":pose,"image_sha256":FileAccess.get_sha256(motion_path)})
	var report := {"status":"NATIVE_CAPTURE_REQUIRES_PIXEL_REVIEW", "engine":Engine.get_version_info(),
		"renderer":RenderingServer.get_current_rendering_method(), "stills":records, "frames":72,
		"frame_rate":30, "duration":2.4, "wing_bones":wing.feather_skeleton.get_bone_count(),
		"wing_sha256":FileAccess.get_sha256("res://assets/characters/echo_shadow_wing_feathers_v1.glb"),
		"eye_socket":var_to_str(eye.global_transform), "wing_socket":var_to_str(wing.global_transform), "source_hashes":frozen,
		"eye_skin_bones":var_to_str(eye.attachment.skin_bones), "eye_skin_weights":var_to_str(eye.attachment.skin_weights),
		"motion":motion_records,"import_fingerprints":import_fingerprints}
	for path in RUN_FILES:
		if FileAccess.get_sha256(path) != frozen[path]:
			push_error("Native capture source changed during run: " + path)
			quit(2)
			return
	for path in import_fingerprints:
		if FileAccess.get_sha256(path) != import_fingerprints[path]:
			push_error("Native capture compiled resource changed: " + String(path))
			quit(2)
			return
	var file := FileAccess.open(output + "/native-review.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	viewport.queue_free()
	for frame in 4: await process_frame
	print("ZERO_MANIFESTATION_CAPTURE ", output)
	quit(0)

func capture(label: String, position_value: Vector3, target: Vector3, camera_size: float) -> void:
	camera.position = position_value
	camera.look_at(target)
	camera.size = camera_size
	for frame in 3: await process_frame
	RenderingServer.force_draw()
	var image := viewport.get_texture().get_image()
	var filename := output + "/" + label + ".png"
	assert(image.save_png(filename) == OK)
	records.append({"name":label,"file":filename,"camera":var_to_str(camera.global_transform),"size":camera_size})

func guard_current_import(path: String, checked: Dictionary) -> bool:
	if checked.has(path): return true
	checked[path] = true
	if not path.get_extension().to_lower() in ["glb", "png", "jpg"]: return true
	var settings := ConfigFile.new()
	if settings.load(path + ".import") != OK:
		push_error("Missing native importer: " + path)
		return false
	import_fingerprints[path] = FileAccess.get_sha256(path)
	import_fingerprints[path + ".import"] = FileAccess.get_sha256(path + ".import")
	var pattern := RegEx.new()
	pattern.compile('source_md5="([0-9a-f]{32})"')
	var destinations: Variant = settings.get_value("deps", "dest_files", [])
	if destinations.is_empty(): return false
	for value in destinations:
		var destination: String = value
		var digest_path := destination.get_basename() + ".md5"
		if not FileAccess.file_exists(destination) or not FileAccess.file_exists(digest_path): return false
		var matched := pattern.search(FileAccess.get_file_as_string(digest_path))
		if not matched or matched.get_string(1) != FileAccess.get_md5(path):
			push_error("Stale native import rejects capture: " + path)
			return false
		import_fingerprints[destination] = FileAccess.get_sha256(destination)
		import_fingerprints[digest_path] = FileAccess.get_sha256(digest_path)
	for descriptor in ResourceLoader.get_dependencies(path):
		for token in String(descriptor).split("::"):
			if token.begins_with("res://") and not guard_current_import(token, checked): return false
	return true
