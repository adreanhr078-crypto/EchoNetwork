extends SceneTree

## Staged render fixture: actual proximity/action, not a chapter acceptance.
func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	root.content_scale_size = Vector2i(int(args[0]),int(args[1])) if args.size() == 2 else Vector2i(1920,1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	var main = load("res://scenes/system_journey_preview.tscn").instantiate()
	main.native_checkpoint_path = "user://service_capture_opening.json"
	main.native_preferences_path = "user://service_capture.cfg"
	root.add_child(main)
	var director = main.get_node("SystemJourneyPreview")
	director.checkpoint_path = "user://service_capture.json"
	await process_frame
	main.set_audio_muted(true)
	main.player.finish_opening_recovery()
	var dialogue = main.hud.find_child("DialogueOverlay",true,false)
	for i in range(8):
		if dialogue.is_active: dialogue.continue_button.pressed.emit()
		await process_frame
	main.native_pause_menu.queue_free()
	main.native_pause_menu = null
	main.opening_web_handoff.reported_milestones.append("memory_scene_completed")
	for i in range(5): await physics_frame
	# Only entry is staged. The wheel uses the same player action as gameplay.
	director.stage = 5
	director.refresh_objective()
	main.hud.find_child("TutorialToastSystem",true,false).dismiss_toast()
	main.player.position = Vector3(0.45,5.41,-30.1)
	main.player.velocity = Vector3.ZERO
	main.player.camera_boom.rotation.y = 0
	main.player.camera_boom.rotation.x = -0.12
	main.player.control_locked = false
	var touch = main.hud.find_child("MobileTouchControls",true,false)
	if root.content_scale_size.x > 2000:
		touch._platform_touch_enabled = true
		touch.set_interaction_blocked(false)
		main.refresh_opening_language()
	for i in range(20): await physics_frame
	await RenderingServer.frame_post_draw
	if not _save("closed-ar"): return
	main.set_presentation_language("en")
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	if not _save("closed-en"): return
	main.set_presentation_language("ar")
	main.player.interact_with_nearest()
	for i in range(64): await physics_frame
	await RenderingServer.frame_post_draw
	if not _save("opening-ar"): return
	for i in range(180): await physics_frame
	await RenderingServer.frame_post_draw
	if not _save("open-ar"): return
	if not director.room.service_open:
		push_error("Service capture did not complete actual wheel interaction")
		quit(1)
		return
	main.queue_free()
	for i in range(4): await process_frame
	await create_timer(0.12).timeout
	for base in ["user://service_capture_opening.json","user://service_capture.cfg","user://service_capture.json"]:
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(base+suffix): DirAccess.remove_absolute(base+suffix)
	print("PASS service visual fixture: closed/bilingual/opening/open; staged entry only")
	quit()

func _save(state: String) -> bool:
	var capture := root.get_texture().get_image()
	if capture == null or capture.is_empty() or capture.get_size() != root.content_scale_size:
		push_error("Service capture missing or has incorrect viewport dimensions: requested %s actual %s" % [root.content_scale_size,capture.get_size() if capture else Vector2i.ZERO])
		quit(1)
		return false
	var path := ProjectSettings.globalize_path("res://../audits/evidence/service-%s-%dx%d.png" % [state,capture.get_width(),capture.get_height()])
	var error := capture.save_png(path + ".tmp.png")
	if error == OK: error = DirAccess.rename_absolute(path + ".tmp.png",path)
	if error != OK:
		push_error("Service capture failed: %s, error %d" % [path,error])
		quit(1)
		return false
	print("CAPTURE ",path)
	return true
