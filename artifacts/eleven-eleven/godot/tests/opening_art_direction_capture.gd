extends SceneTree

## Reversible light comparison in the real opening scene; no avatar/rig edits.
const OUTPUT := "res://../audits/evidence/third-person-foundation-20261001/implementation/art-light-review/"

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var main = load("res://scenes/opening_native_room.tscn").instantiate()
	main.native_checkpoint_path = "user://opening_art_light_review.json"
	main.native_preferences_path = "user://opening_art_light_review.cfg"
	root.add_child(main)
	await process_frame
	main.set_audio_muted(true)
	var player: EchoPlayer = main.player
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
	var folder := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(folder)
	var material_evidence := []
	for candidate in player.get_node("ModelRoot").find_children("*", "MeshInstance3D", true, false):
		var mesh := candidate as MeshInstance3D
		var row := {"name": mesh.name, "blend_shapes": mesh.mesh.get_blend_shape_count() if mesh.mesh is ArrayMesh else 0, "materials": []}
		for surface in mesh.mesh.get_surface_count():
			var mat := mesh.get_active_material(surface) as ShaderMaterial
			if mat:
				row.materials.append({"skin_limit": mat.get_shader_parameter("limit_skin_highlights"), "skin_light_scale": mat.get_shader_parameter("skin_light_scale"), "albedo_gamma": mat.get_shader_parameter("albedo_gamma"), "ambient_lift": mat.get_shader_parameter("ambient_lift")})
		material_evidence.append(row)
	var metadata := FileAccess.open(folder + "runtime-materials.json", FileAccess.WRITE)
	metadata.store_string(JSON.stringify(material_evidence, "\t"))
	metadata.close()
	var world_environment: WorldEnvironment = main.get_node("WorldEnvironment")
	var directional: DirectionalLight3D = main.get_node("DirectionalLight3D")
	var room_fill: OmniLight3D = main.get_node("Sector11KeyFill")
	var violet_rim: OmniLight3D = main.get_node("Sector11NeonVioletRim")
	var face_fill: OmniLight3D = player.get_node("ModelRoot/EchoFaceFill")
	var shoulder_fill: OmniLight3D = player.get_node("ModelRoot/EchoShoulderFill")
	for variant in ["baseline", "soft_key", "skin_response"]:
		if variant == "soft_key":
			world_environment.environment.ambient_light_energy = 0.48
			directional.light_energy = 0.85
			room_fill.light_energy = 1.4
			violet_rim.light_energy = 0.45
			face_fill.light_energy = 1.25
			shoulder_fill.light_energy = 0.65
		elif variant == "skin_response":
			world_environment.environment.ambient_light_energy = 0.72
			directional.light_energy = 0.65
			room_fill.light_energy = 1.2
			violet_rim.light_energy = 1.1
			face_fill.light_energy = 0.35
			shoulder_fill.light_energy = 0.85
			var body := player.find_child("EchoOpeningUniformBody", true, false) as MeshInstance3D
			var material := body.get_active_material(0) as ShaderMaterial
			material.set_shader_parameter("skin_light_scale", 0.18)
		for view in ["back", "front", "side"]:
			player.set_gameplay_orbit(Vector3(-0.08, PI if view == "front" else (PI/2 if view == "side" else 0), 0))
			for i in range(20): await physics_frame
			for i in range(3): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder + variant + "-" + view + ".png")
	main.queue_free()
	await process_frame
	for path in ["user://opening_art_light_review.json", "user://opening_art_light_review.cfg"]:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("CAPTURED real opening lighting comparison in back/front/side; review required")
	quit(0)
