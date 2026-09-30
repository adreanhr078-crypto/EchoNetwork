extends SceneTree

const Saves = preload("res://scripts/systems/save_manager.gd")
const SAVE = "user://pause_touch_smoke.json"
const PREFS = "user://pause_touch_smoke.cfg"
var uses := 0
var jumps := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for path in [SAVE, SAVE + ".bak", PREFS]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	var checkpoint := {"schema": Saves.OPENING_SCHEMA, "milestones": {"wake": true, "clock": true, "photo": true, "memory": true, "terminal": false, "conduit": false, "ending": false}, "terminal": {"frequency": 93.0, "phase": 85.0, "harmonic": 3.0}}
	Saves.save_opening_checkpoint(checkpoint, SAVE)
	var scene: PackedScene = load("res://scenes/opening_native_room.tscn")
	var main = scene.instantiate()
	main.native_checkpoint_path = SAVE
	main.native_preferences_path = PREFS
	root.add_child(main)
	await process_frame
	var touch = main.hud.find_child("MobileTouchControls", true, false)
	var player = main.player
	var menu = main.native_pause_menu
	touch._platform_touch_enabled = true
	touch.set_interaction_blocked(false)
	main.refresh_opening_language()
	if not _check(touch.use_btn.text == "تفاعل" and touch.sprint_btn.text == "اركض", "touch labels ignore Arabic"): return
	touch.use_tapped.connect(func(): uses += 1)
	touch.jump_tapped.connect(func(): jumps += 1)
	var size: Vector2 = root.get_visible_rect().size
	_touch(touch, 0, Vector2(120, size.y * 0.6), true)
	_drag(touch, 0, Vector2(180, size.y * 0.6))
	_touch(touch, 1, Vector2(size.x * 0.7, size.y * 0.25), true)
	_touch(touch, 2, touch.sprint_btn.get_global_rect().get_center(), true)
	_touch(touch, 3, touch.use_btn.get_global_rect().get_center(), true)
	_touch(touch, 3, touch.use_btn.get_global_rect().get_center(), false)
	var jump = touch.find_child("JumpBtn", true, false) as Button
	_touch(touch, 4, jump.get_global_rect().get_center(), true)
	if not _check(jumps == 1, "held touch jump waits for release"): return
	if not _check(player.jump_buffer_timer > 0.0, "touch press did not reach player jump request"): return
	_touch(touch, 5, jump.get_global_rect().get_center(), true)
	_touch(touch, 5, jump.get_global_rect().get_center(), false)
	if not _check(jumps == 1, "second finger duplicated held jump"): return
	_touch(touch, 4, Vector2.ZERO, false)
	if not _check(jumps == 1, "jump repeats on touch release"): return
	var boom = player.find_child("CameraBoom", true, false)
	var yaw: float = boom.rotation.y
	_drag(touch, 1, Vector2(size.x * 0.7 + 40, size.y * 0.25))
	if not _check(player.mobile_input_vector.length() > 0.5 and player.mobile_sprint_active and uses == 1 and not is_equal_approx(yaw, boom.rotation.y), "simultaneous movement/camera/sprint/use failed"): return
	menu.set_session_paused(true)
	for i in range(4): await process_frame
	var bounds: Rect2 = menu.panel.get_global_rect()
	if not _check(bounds.position.y >= 0 and bounds.end.y <= root.get_visible_rect().size.y, "pause panel clipped outside viewport"): return
	if not _check(paused and player.mobile_input_vector == Vector2.ZERO and not player.mobile_sprint_active and touch.camera_touch_index == -1, "pause retained held inputs"): return
	var position: Vector3 = player.global_position
	await create_timer(0.08).timeout
	if not _check(player.global_position == position and menu.resume_button.has_focus(), "pause did not freeze world or focus resume"): return
	menu.language_button.pressed.emit()
	if not _check(main.presentation_language == "en" and menu.resume_button.text == "Continue" and menu.status.text.begins_with("Time"), "menu localization incomplete"): return
	if not _check(touch.use_btn.text == "USE" and touch.sprint_btn.text == "RUN", "touch labels ignore language changes"): return
	menu.resume_button.pressed.emit()
	if not _check(not paused and touch.visible and touch.current_joystick_vector == Vector2.ZERO, "resume retained input or hid touch"): return
	# Pause during a terminal modal must restore its existing lock/visibility.
	main._on_terminal_accessed(main.find_child("SectorTerminal", true, false))
	menu.set_session_paused(true)
	menu.set_session_paused(false)
	if not _check(player.control_locked and not touch.visible, "pause bypassed terminal modal"): return
	main._on_terminal_puzzle_closed()
	# Focus loss requires an explicit resume; it does not resume automatically.
	main._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	if not _check(paused, "focus loss failed to pause"): return
	menu.resume_button.pressed.emit()
	main.native_checkpoint_path = "user://missing-pause-smoke-directory/checkpoint.json"
	menu.set_session_paused(true)
	if not _check(not menu._save_succeeded and menu.status.text.contains("Save failed"), "failed save reported success"): return
	menu.set_session_paused(false)
	main.queue_free()
	await process_frame
	for path in [SAVE, SAVE + ".bak", SAVE + ".tmp", PREFS]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("PASS native pause/touch: simultaneous input, jump on press without release/second-finger repeats, freeze, reset, localization, modal integrity, focus loss, save failure")
	quit(0)

func _touch(target: Node, index: int, pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = pos
	event.pressed = pressed
	target._input(event)

func _drag(target: Node, index: int, pos: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = pos
	target._input(event)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		paused = false
		quit(1)
	return condition
