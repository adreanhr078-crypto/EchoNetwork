extends SceneTree

const OUTPUT := "res://../audits/evidence/character-shading-20261001/prop/integrated/"

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	var main = load("res://scenes/opening_native_room.tscn").instantiate()
	main.native_checkpoint_path = "user://conduit_review_capture.json"
	main.native_preferences_path = "user://conduit_review_capture.cfg"
	root.add_child(main)
	await process_frame
	main.set_audio_muted(true)
	main.player.finish_opening_recovery()
	var conduit := main.find_child("EnergyPowerConduit_A", true, false) as EnergyPowerConduit
	if not conduit:
		push_error("Actual opening conduit missing")
		quit(1)
		return
	var dialogue = main.hud.find_child("DialogueOverlay", true, false)
	for i in range(8):
		if dialogue.is_active: dialogue.continue_button.pressed.emit()
		await process_frame
	main.native_pause_menu.set_session_paused(false)
	main.player.position = conduit.global_position + Vector3(1.2, 0.05, 2.2)
	for i in range(20): await physics_frame
	main.player.control_locked = true
	main.player.visible = false # Prop-only comparison; gameplay placement is unchanged.
	main.player.suspend_gameplay_camera()
	var camera := Camera3D.new()
	main.add_child(camera)
	camera.fov = 48
	camera.global_position = conduit.global_position + Vector3(1.8, 1.4, 2.6)
	camera.look_at(conduit.global_position + Vector3(0, 0.95, 0))
	camera.current = true
	main.process_mode = Node.PROCESS_MODE_DISABLED
	for particles in main.find_children("*", "GPUParticles3D", true, false): particles.speed_scale = 0.0
	var core := conduit.get_node("CoreMesh") as MeshInstance3D
	var material := core.get_active_material(0) as StandardMaterial3D
	var folder := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(folder)
	var observations := []
	var presentation := conduit.get_node("Presentation") as Node3D
	for variant in ["occluded_baseline", "legacy_dormant", "legacy_energized", "production_dormant", "production_energized"]:
		var production: bool = variant.begins_with("production")
		presentation.visible = production
		conduit.get_node("PillarMesh").visible = not production
		core.visible = not production
		core.position.z = 0 if variant == "occluded_baseline" else 0.23
		conduit.is_energized = variant.ends_with("energized")
		conduit._update_visuals()
		if variant == "occluded_baseline":
			material.albedo_color = Color(0, 0.9, 1)
			material.emission = Color(0, 0.9, 1)
			material.emission_energy_multiplier = 2.5
		for i in range(5): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder + variant + ".png")
		var signals := []
		for signal_material in conduit._signal_materials:
			signals.append({"emission": str(signal_material.emission), "energy": signal_material.emission_energy_multiplier})
		observations.append({"variant": variant, "energized": conduit.is_energized, "prompt": conduit.get_interaction_prompt(), "production_binding": production, "signal_materials": signals, "collider": str(conduit.get_node("CollisionShape3D").shape)})
	var metadata := FileAccess.open(folder + "capture.json", FileAccess.WRITE)
	metadata.store_string(JSON.stringify({"staged_camera": true, "player_hidden_for_prop_comparison": true, "actual_opening": true, "actual_production_instance": true, "node_processes_frozen": true, "variants": observations}, "\t"))
	metadata.close()
	main.queue_free()
	await process_frame
	for path in ["user://conduit_review_capture.json", "user://conduit_review_capture.cfg"]:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("CAPTURED actual integrated opening conduit with production state bindings")
	quit(0)
