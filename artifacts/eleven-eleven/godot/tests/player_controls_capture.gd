extends SceneTree

## Real opening renderer; staged idle/HUD view, not a full-route acceptance.
const SAVE := "user://player_controls_capture.json"
const PREFS := "user://player_controls_capture.cfg"

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var main = load("res://scenes/opening_native_room.tscn").instantiate()
	main.native_checkpoint_path = SAVE
	main.native_preferences_path = PREFS
	root.add_child(main)
	await process_frame
	main.set_audio_muted(true)
	var touch = main.hud.find_child("MobileTouchControls", true, false)
	touch._platform_touch_enabled = true
	touch.set_interaction_blocked(false)
	main.player.finish_opening_recovery()
	var dialogue = main.hud.find_child("DialogueOverlay", true, false)
	for i in range(8):
		if dialogue.is_active: dialogue.continue_button.pressed.emit()
		await process_frame
	touch.set_interaction_available(true)
	main.player.player_camera.make_current()
	main.player.set_gameplay_orbit(Vector3(-0.15, 0, 0))
	for i in range(35): await physics_frame
	main.player.play_anim("IDLE", 0)
	var folder := ProjectSettings.globalize_path("res://../audits/evidence/third-person-foundation-20261001/implementation/render/")
	DirAccess.make_dir_recursive_absolute(folder)
	for size in [Vector2i(1280,720), Vector2i(1920,1080), Vector2i(2408,1080)]:
		root.size = size
		root.content_scale_size = size
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
		for language in ["ar", "en"]:
			main.set_presentation_language(language)
			main.hud.show_tutorial_toast("TOAST_MOVE", "TOUCH", main.opening_text("التحرك والتفاعل", "Move and inspect"), main.opening_text("حرّك إيكو بالمقبض، ثم افحص الساعة المتوقفة.", "Move Echo with the stick, then inspect the stopped clock."), 6)
			for i in range(5): await process_frame
			await RenderingServer.frame_post_draw
			var output := folder + "controls-%s-%dx%d.png" % [language, size.x, size.y]
			root.get_texture().get_image().save_png(output)
			print("CAPTURE ", output)
	# One timed press feedback image, and an accessible scrollable settings view.
	var down := InputEventScreenTouch.new()
	down.index = 2
	down.pressed = true
	down.position = touch.dodge_btn.get_global_rect().get_center()
	touch._input(down)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder + "controls-pressed.png")
	touch.reset_input()
	main.native_pause_menu.set_session_paused(true)
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder + "controls-settings.png")
	var scroll: ScrollContainer
	for candidate in main.native_pause_menu.find_children("*", "ScrollContainer", true, false):
		scroll = candidate
	if scroll:
		scroll.scroll_vertical = 10000
		for i in range(5): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder + "controls-settings-bottom-en.png")
		main.set_presentation_language("ar")
		for i in range(5): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder + "controls-settings-bottom-ar.png")
	main.native_pause_menu.set_session_paused(false)
	main.queue_free()
	await process_frame
	for path in [SAVE, SAVE + ".bak", SAVE + ".tmp", PREFS]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	quit(0)
