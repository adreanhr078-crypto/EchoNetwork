extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/opening_native_room.tscn")
	var main = scene.instantiate()
	main.native_checkpoint_path = "user://pause_capture_only.json"
	main.native_preferences_path = "user://pause_capture_only.cfg"
	root.add_child(main)
	await process_frame
	main.set_audio_muted(true)
	var menu = main.native_pause_menu
	menu.set_session_paused(true)
	var evidence := ProjectSettings.globalize_path("res://../audits/evidence/")
	DirAccess.make_dir_recursive_absolute(evidence)
	for sample in [[1280, 720, "ar"], [1920, 1080, "en"], [2408, 1080, "ar"]]:
		root.size = Vector2i(sample[0], sample[1])
		main.presentation_language = sample[2]
		menu.refresh_labels()
		for i in range(4): await process_frame
		await RenderingServer.frame_post_draw
		print("LAYOUT ", root.get_visible_rect().size, " panel=", menu.panel.get_global_rect(), " minimum=", menu.panel.get_combined_minimum_size(), " status=", menu.status.get_global_rect())
		var file: String = evidence + "batch2-native-pause-%s-%dx%d.png" % [sample[2], sample[0], sample[1]]
		root.get_texture().get_image().save_png(file)
		print("CAPTURE ", file)
	menu.set_session_paused(false)
	main.queue_free()
	await process_frame
	for path in ["user://pause_capture_only.json", "user://pause_capture_only.json.bak", "user://pause_capture_only.cfg"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	quit(0)
