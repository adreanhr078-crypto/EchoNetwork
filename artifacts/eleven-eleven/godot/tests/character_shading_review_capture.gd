extends SceneTree

## Same saved avatar, pose, lighting and camera; isolate shader light units.
const OUTPUT := "res://../audits/evidence/character-shading-20261001/"

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Rendered shading evidence requires a display")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var main = load("res://scenes/opening_native_room.tscn").instantiate()
	main.native_checkpoint_path = "user://character_shading_review.json"
	main.native_preferences_path = "user://character_shading_review.cfg"
	root.add_child(main)
	await process_frame
	main.set_audio_muted(true)
	var player: EchoPlayer = main.player
	var facial := player.get_node("EchoFacialController")
	facial.set_process(false)
	var face_mesh := player.find_child("EchoOpeningUniformBody", true, false) as MeshInstance3D
	var facial_weights := {}
	for shape in ["Blink_L", "Blink_R", "Brow_Frown", "Mouth_Grimace"]:
		facial_weights[shape] = face_mesh.get_blend_shape_value(face_mesh.find_blend_shape_by_name(shape))
	player.finish_opening_recovery()
	var dialogue = main.hud.find_child("DialogueOverlay", true, false)
	for i in range(8):
		if dialogue.is_active: dialogue.continue_button.pressed.emit()
		await process_frame
	main.native_pause_menu.set_session_paused(false)
	player.position = Vector3(0, 0.06, -7)
	player.velocity = Vector3.ZERO
	for i in range(30): await physics_frame
	player.control_locked = true
	player.play_anim("IDLE", 0)
	player.animation_player.seek(0, true)
	player.animation_player.pause()
	player.suspend_gameplay_camera()
	var camera := Camera3D.new()
	main.add_child(camera)
	camera.fov = 40
	camera.current = true
	# Freeze node-driven strobe/companion/animation and particles before A/B.
	# Rendering continues; the SceneTree fixture advances its own frames.
	main.process_mode = Node.PROCESS_MODE_DISABLED
	for particles in main.find_children("*", "GPUParticles3D", true, false):
		particles.speed_scale = 0.0
	var maps_review := "--authored-maps-review" in OS.get_cmdline_user_args()
	var facial_review := "--facial-review" in OS.get_cmdline_user_args()
	var folder := ProjectSettings.globalize_path(OUTPUT + ("maps/" if maps_review else ""))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--review-output="):
			folder = argument.trim_prefix("--review-output=").replace("\\", "/").rstrip("/") + "/"
	DirAccess.make_dir_recursive_absolute(folder)
	var baseline_code := FileAccess.get_file_as_string(folder + ("before-authored-maps.gdshader.txt" if maps_review else "baseline-anime-cel.gdshader.txt"))
	if baseline_code.is_empty() and not facial_review:
		push_error("Saved baseline shader missing; comparison cannot be reproduced")
		quit(1)
		return
	var bindings := []
	for candidate in player.get_node("ModelRoot").find_children("*", "MeshInstance3D", true, false):
		var mesh := candidate as MeshInstance3D
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as ShaderMaterial
			if material and material.shader.resource_path == "res://shaders/anime_cel.gdshader":
				var scalar: Variant = material.get_shader_parameter("metallic")
				bindings.append({"material": material, "original": material.shader, "metallic": scalar if scalar is float or scalar is int else 0.05, "specular": material.get_shader_parameter("specular_color"), "echo": mesh.name.to_lower().begins_with("echoopeninguniform")})
	var audit := {"renderer": RenderingServer.get_current_rendering_method(), "variants": [], "facial_weights": facial_weights, "node_processes_frozen": true, "particles_frozen": true, "lights_modified": false, "pose_modified_between_variants": false, "production_shader_sha256": FileAccess.get_sha256("res://shaders/anime_cel.gdshader"), "applicator_sha256": FileAccess.get_sha256("res://scripts/combat/shader_applicator.gd"), "baseline_shader_sha256": baseline_code.sha256_text()}
	var variants := ["neutral", "blink", "damage", "recovered"] if facial_review else (["baseline", "full_highlights", "production"] if maps_review else ["baseline", "production"])
	for variant in variants:
		if facial_review:
			for shape in facial_weights:
				var weight := 0.0
				if variant == "blink" and shape.begins_with("Blink"): weight = 1.0
				if variant == "damage":
					weight = 0.42 if shape.begins_with("Blink") else (0.6 if shape == "Mouth_Grimace" else 0.35)
				face_mesh.set_blend_shape_value(face_mesh.find_blend_shape_by_name(shape), weight)
		for binding in bindings:
			if variant == "baseline":
				var isolated := Shader.new()
				isolated.code = baseline_code
				binding.material.shader = isolated
				if maps_review and binding.echo:
					# Before the map fix the applicator capped the scalar, so the
					# saved shader must receive that earlier scalar in this A/B.
					binding.material.set_shader_parameter("metallic", minf(float(binding.metallic),0.1))
			else:
				binding.material.shader = binding.original
				if maps_review and binding.echo: binding.material.set_shader_parameter("metallic", binding.metallic)
			if maps_review and binding.echo:
				binding.material.set_shader_parameter("specular_color",Color.WHITE if variant == "full_highlights" else binding.specular)
		for view in (["portrait", "three_quarter"] if facial_review else ["portrait", "three_quarter", "room"]):
			var target := player.global_position + Vector3(0, 1.54, 0)
			var offset := Vector3(1.05, 0.01, 0)
			if view == "three_quarter": offset = Vector3(0.95, 0.02, -0.65)
			if view == "room":
				target = player.global_position + Vector3(0, 0.95, 0)
				offset = Vector3(3.4, 0.4, 0)
			camera.global_position = target + offset
			camera.look_at(target)
			for i in range(4): await process_frame
			await RenderingServer.frame_post_draw
			var capture := root.get_texture().get_image()
			capture.save_png(folder + variant + "-" + view + ".png")
			var lights := []
			for light in main.find_children("*", "Light3D", true, false):
				lights.append({"path": str(main.get_path_to(light)), "energy": light.light_energy, "color": str(light.light_color), "position": str(light.global_position)})
			var captured_weights := {}
			for shape in facial_weights:
				captured_weights[shape] = face_mesh.get_blend_shape_value(face_mesh.find_blend_shape_by_name(shape))
			audit.variants.append({"variant": variant, "view": view, "size": [capture.get_width(), capture.get_height()], "camera": str(camera.global_position), "lights": lights, "captured_facial_weights": captured_weights})
	for binding in bindings: binding.material.shader = binding.original
	var metadata := FileAccess.open(folder + "capture.json", FileAccess.WRITE)
	metadata.store_string(JSON.stringify(audit, "\t"))
	metadata.close()
	main.queue_free()
	await process_frame
	for path in ["user://character_shading_review.json", "user://character_shading_review.cfg"]:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("CAPTURED isolated light-unit comparison; artistic review required")
	quit(0)
