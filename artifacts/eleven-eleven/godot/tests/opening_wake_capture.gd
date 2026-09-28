extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = load("res://scenes/opening_native_room.tscn").instantiate()
	main.native_checkpoint_path = "user://wake_capture.json"
	main.native_preferences_path = "user://wake_capture.cfg"
	for path in [main.native_checkpoint_path, main.native_checkpoint_path + ".bak", main.native_preferences_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	root.size = Vector2i(1280, 720)
	root.add_child(main)
	await process_frame
	main.set_audio_muted(true)
	main.native_pause_menu.queue_free()
	main.native_pause_menu = null
	var evidence := ProjectSettings.globalize_path("res://../audits/evidence/")
	for i in range(4):
		await create_timer(0.15 if i == 0 else 1.0).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(evidence + "opening-wake-live-%02d.png" % i)
		print("WAKE frame=", i, " active=", main.player.opening_recovery_active, " offset=", main.player.visual_root.position.y, " anim=", main.player.animation_player.current_animation)
	main.queue_free()
	await process_frame
	for path in ["user://wake_capture.json", "user://wake_capture.json.bak", "user://wake_capture.cfg"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	quit(0)
