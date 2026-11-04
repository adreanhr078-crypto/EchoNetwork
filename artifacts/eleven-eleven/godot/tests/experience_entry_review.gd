extends SceneTree

const Bindings = preload("res://scripts/ui/control_bindings.gd")
var failures := 0
var checks := 0
var evidence := "res://../audits/evidence/experience-rebuild-20261103"

class RetryBoot extends "res://scripts/boot.gd":
	var missing := true
	func _ready() -> void:
		# Use Boot's existing isolated review branch before the destination's
		# _ready can read or write a player's real chapter/preferences.
		_title_review = true
		_preferences_path = "user://experience_review/preferences.cfg"
		DirAccess.make_dir_recursive_absolute("user://experience_review")
	func _take_native_scene() -> PackedScene:
		return null if missing else super._take_native_scene()

func _init() -> void: _run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
	print("PASS " if ok else "FAIL ", message)

func frames(count: int) -> void:
	for i in count: await process_frame

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join(name + ".png"))

func _run() -> void:
	evidence = ProjectSettings.globalize_path(evidence)
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	Engine.max_fps = 60
	var initial := Bindings.current()
	check(Bindings.apply(initial), "default keyboard bindings validate")
	var changed := initial.duplicate()
	changed.interact = KEY_Y
	check(Bindings.apply(changed) and Bindings.caption("interact") == "Y", "physical interact key changes")
	changed.jump = KEY_Y
	check(not Bindings.apply(changed) and Bindings.caption("jump") == "Space", "duplicate key rejected atomically")
	changed = initial.duplicate()
	changed.interact = KEY_ESCAPE
	check(not Bindings.apply(changed), "pause key cannot be stolen")
	check(Bindings.apply(initial), "original bindings restored")
	var cover = load("res://scripts/ui/cover_recovery.gd").new()
	root.add_child(cover)
	await frames(3)
	var before: Array = cover.order.duplicate()
	var source: Vector2 = cover.tiles[0].get_global_rect().get_center()
	var destination: Vector2 = cover.tiles[1].get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = source
	down.global_position = source
	root.push_input(down, true)
	await frames(2)
	for point in [source + Vector2(22,0), destination]:
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		motion.relative = point - source
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion, true)
		await frames(2)
	var data: Variant = {"board":cover.get_instance_id(),"piece":0}
	check(cover.tiles[1]._can_drop_data(Vector2.ZERO, data), "board accepts its own drag")
	check(not cover.tiles[1]._can_drop_data(Vector2.ZERO, {"board":0,"piece":0}), "foreign drag rejected")
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = destination
	up.global_position = destination
	root.push_input(up, true)
	await frames(3)
	check(cover.order != before and cover.history.size() == 1, "drop swaps exactly once")
	cover._undo()
	check(cover.order == before, "drag can be undone")
	cover._reference_open = true
	check(not cover.tiles[1]._can_drop_data(Vector2.ZERO,data), "reference blocks drag")
	cover._reference_open = false
	await capture("cover-drag")
	cover.queue_free()
	await frames(2)
	var boot := RetryBoot.new()
	boot._reduced_motion = true
	root.add_child(boot)
	current_scene = boot
	boot._enter_chapter()
	await frames(8)
	var loader: CanvasLayer = boot._loading_screen
	check(is_instance_valid(loader) and loader.get_parent() == root and loader.phase == "failed", "failed destination retains visible root-owned curtain")
	check(loader.retry_button.visible, "failed loading offers retry")
	await capture("loading-error")
	var loader_id := loader.get_instance_id()
	boot._enter_chapter()
	check(boot._loading_screen.get_instance_id() == loader_id, "duplicate handoff does not duplicate curtain")
	# Successful retry uses the real existing native chapter, not a dummy scene.
	boot.missing = false
	loader.retry_button.pressed.emit()
	for i in 600:
		await process_frame
		if current_scene != boot: break
	check(current_scene != boot and current_scene.has_node("NativeCampaignController"), "retry opens actual native chapter")
	var main = current_scene
	if main == boot:
		quit(1)
		return
	main.set_audio_muted(true)
	if "--echo-school-candidate" in OS.get_cmdline_user_args():
		var avatar = main.player.get_node("ModelRoot/EchoOpeningUniform")
		check(not avatar.supports_inverted_hull_outline(), "School refuses the garment-penetrating hull")
		var clean_outline := true
		for mesh in avatar.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():
				clean_outline = clean_outline and mesh.get_active_material(surface).next_pass == null
		check(clean_outline, "actual native School keeps cel materials without internal ink hull")
	main.native_checkpoint_path = "user://experience_review/opening.json"
	main.native_preferences_path = "user://experience_review/preferences.cfg"
	DirAccess.make_dir_recursive_absolute("user://experience_review")
	await frames(30)
	check(not is_instance_valid(loader), "curtain releases after destination frames in reduced motion")
	var menu = main.native_pause_menu
	menu.set_session_paused(true)
	await frames(4)
	check(paused and menu.resume_button.has_focus(), "pause freezes world and focuses continue")
	await capture("pause-journey-ar")
	menu._show_page("controls")
	check(menu._pages.controls.visible and not menu._pages.journey.visible, "controls have a dedicated navigable page")
	menu._begin_binding("interact")
	var press := InputEventKey.new()
	press.physical_keycode = KEY_Y
	press.keycode = KEY_Y
	press.pressed = true
	menu._input(press)
	check(Bindings.caption("interact") == "Y", "pause menu binds physical key")
	var saved := ConfigFile.new()
	saved.load(main.native_preferences_path)
	check(saved.get_value("controls","settings",{}).get("bindings",{}).get("interact") == KEY_Y, "rebind persists to actual native preferences")
	await capture("pause-controls-ar")
	menu._show_page("audio")
	menu._volume_slider.value = .4
	check(absf(main.master_volume - .4) < .001 and absf(db_to_linear(AudioServer.get_bus_volume_db(0)) - .4) < .001, "volume slider changes actual audio bus")
	main._load_native_preferences()
	check(absf(main.master_volume - .4) < .001, "volume preference reloads")
	main.set_presentation_language("en")
	menu._show_page("display")
	await capture("pause-display-en")
	menu.set_session_paused(false)
	check(not paused and not Input.is_action_pressed("interact"), "resume does not leak binding input")
	Bindings.apply(initial)
	main.queue_free()
	await frames(5)
	var report := {"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"scope":"Entry curtain, native pause, keyboard persistence, master bus and cover drag; not cinematic/fun/chapter acceptance"}
	var file := FileAccess.open(evidence.path_join("review-" + DisplayServer.get_name() + ".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("EXPERIENCE_REVIEW ",JSON.stringify(report))
	quit(0 if failures == 0 else 1)
