extends SceneTree
## Actual opening/controller/HUD regression; camera probe geometry is staged,
## and neither these checks nor virtual touch events establish phone acceptance.

const Saves = preload("res://scripts/systems/save_manager.gd")
const SAVE := "user://player_foundation_smoke.json"
const PREFS := "user://player_foundation_smoke.cfg"
var main: Node
var player: CharacterBody3D
var touch: Control
var menu: Node
var jumps := 0
var rolls := 0
var uses := 0
var ghosts := 0
var observations: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_clear_files()
	var checkpoint := {"schema": Saves.OPENING_SCHEMA, "milestones": {"wake": true, "clock": true, "photo": true, "memory": true, "terminal": false, "conduit": false, "ending": false}, "terminal": {"frequency": 93.0, "phase": 85.0, "harmonic": 3.0}}
	if not _check(Saves.save_opening_checkpoint(checkpoint, SAVE), "isolated checkpoint could not be created"): return
	await _boot()
	if not _check(player.is_on_floor() and not player.control_locked and not player.combat_available, "opening checkpoint did not restore controllable human player"): return
	node_added.connect(func(node: Node):
		if str(node.name).begins_with("GhostPhantom"): ghosts += 1)
	touch.jump_tapped.connect(func(): jumps += 1)
	touch.use_tapped.connect(func(): uses += 1)
	player.combat_roll_executed.connect(func(_direction: Vector3): rolls += 1)
	if not _mouse_and_touch_ownership(): return
	if not await _three_fingers_and_jump(): return
	if not await _dash_hold_release(): return
	if not await _mixed_dash_ownership_and_drop(): return
	if not await _jump_during_dash(): return
	if not await _cancel_focus_and_modal(): return
	if not await _resize_cancel(): return
	if not await _interaction_and_captions(): return
	if not await _camera_and_collision(): return
	if not await _tutorial_hint_layout(): return
	if not await _settings_and_reload(): return
	if not _check(ghosts == 0, "human input spawned forbidden ghost silhouettes"): return
	observations["ghost_phantoms_before_contract"] = ghosts
	observations["status"] = "PASS"
	observations["scope"] = "Actual opening/controller/HUD, virtual touch and staged camera-collision probes; no physical-device or full-route claim."
	var args := OS.get_cmdline_user_args()
	if args.size() == 1:
		var output := FileAccess.open(args[0], FileAccess.WRITE)
		if not _check(output != null, "could not write requested regression report"): return
		output.store_string(JSON.stringify(observations, "\t") + "\n")
	main.queue_free()
	await process_frame
	_clear_files()
	print("PASS player foundation: three fingers, jump on press, one camera-relative human Roll, keyboard/touch ownership, single-edge DROP, hold/release/cancel/focus/modal, interaction in combat, FOV/reduced motion, wall/floor/ceiling collision, bounded persisted controls")
	quit(0)

func _mouse_and_touch_ownership() -> bool:
	if DisplayServer.get_name() == "headless":
		observations["pointer_ownership"] = "UNVERIFIED on headless; requires rendered run with mouse capture"
		print("SKIP pointer ownership on headless display; rendered regression required")
		return true
	# Touch-to-mouse emulation stays available to GUI controls, but it may not
	# apply the camera delta a second time or capture a mobile pointer.
	player.touch_input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var before: Vector3 = player.camera_target_rotation
	var motion := InputEventMouseMotion.new()
	motion.device = -1
	motion.relative = Vector2(40, 0)
	player._unhandled_input(motion)
	if not _check(player.camera_target_rotation == before, "emulated mouse moved the touch camera"): return false
	touch.camera_swiped.emit(Vector2(40, 0))
	if not _check(not player.camera_target_rotation.is_equal_approx(before), "owned touch camera stopped responding"): return false
	var after_touch: Vector3 = player.camera_target_rotation
	player._unhandled_input(motion)
	if not _check(player.camera_target_rotation == after_touch, "one touch drag applied a second emulated look delta"): return false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	main._on_terminal_puzzle_closed()
	if not _check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "terminal return captured the touch pointer"): return false
	player.touch_input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	motion.device = 0
	player._unhandled_input(motion)
	if not _check(not player.camera_target_rotation.is_equal_approx(after_touch), "desktop mouse look regressed"): return false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	main._on_terminal_puzzle_closed()
	if not _check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "desktop terminal return lost mouse capture"): return false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.touch_input_enabled = true
	observations["pointer_ownership"] = {"emulated_look_ignored": true, "touch_look": true, "desktop_look": true, "terminal_return": true}
	return true

func _boot() -> void:
	main = load("res://scenes/opening_native_room.tscn").instantiate()
	main.native_checkpoint_path = SAVE
	main.native_preferences_path = PREFS
	root.add_child(main)
	await process_frame
	player = main.player
	touch = main.hud.find_child("MobileTouchControls", true, false)
	menu = main.native_pause_menu
	touch._platform_touch_enabled = true
	touch.set_interaction_blocked(false)
	main.set_audio_muted(true)
	player.player_camera.make_current()
	await _steps(8)

func _ground() -> void:
	Input.action_release("sprint")
	touch.reset_input()
	player.clear_traversal_input()
	player.control_locked = false
	player.global_position = Vector3(0, 0, -7)
	player.velocity = Vector3.ZERO
	player.stamina = player.MAX_STAMINA
	await _steps(28)

func _three_fingers_and_jump() -> bool:
	await _ground()
	var size := root.get_visible_rect().size
	var move_point: Vector2 = touch.joystick_center
	var look_point := Vector2(size.x * 0.62, size.y * 0.2)
	_touch(0, move_point, true)
	_drag(0, move_point + Vector2(60, 0))
	_touch(1, look_point, true)
	var yaw: float = player.camera_boom.rotation.y
	_drag(1, look_point + Vector2(35, 0))
	var jump := touch.find_child("JumpBtn", true, false) as Button
	_touch(2, jump.get_global_rect().get_center(), true)
	if not _check(jumps == 1 and player.jump_buffer_timer > 0, "touch jump did not request exactly once on press"): return false
	if not _check(touch.joystick_touch_index == 0 and touch.camera_touch_index == 1 and touch._action_touches.has(2), "three fingers did not retain separate movement/camera/action ownership"): return false
	if not _check(player.mobile_input_vector.length() > 0.5 and not is_equal_approx(yaw, player.camera_target_rotation.y), "simultaneous movement and camera drag failed"): return false
	_touch(3, jump.get_global_rect().get_center(), true)
	_touch(3, jump.get_global_rect().get_center(), false)
	_touch(2, Vector2.ZERO, false)
	if not _check(jumps == 1, "held/released jump repeated from a second finger or release"): return false
	await _steps(4)
	if not _check(player.velocity.y > 0 and not player.is_on_floor(), "press-requested jump never reached actual player physics"): return false
	_touch(0, move_point, false)
	_touch(1, look_point, false)
	observations["three_finger_jump"] = {"press_signals": jumps, "actual_upward_velocity": player.velocity.y}
	return true

func _dash_hold_release() -> bool:
	await _ground()
	player.camera_boom.rotation = Vector3(0, PI / 2, 0)
	await _steps(3)
	var expected: Vector3 = player.movement_world_direction(Vector2(0, -1))
	# Partial stick chooses Walk. Roll is a single edge, never held sprint.
	_touch(0, touch.joystick_center, true)
	_drag(0, touch.joystick_center + Vector2(0, -touch.joystick_radius() * 0.6))
	var initial := rolls
	var point: Vector2 = touch.dodge_btn.get_global_rect().get_center()
	_touch(2, point, true)
	await _steps(3)
	if not _check(rolls == initial + 1 and player.is_dodging and not player.mobile_sprint_active, "Roll press did not produce one Roll"): return false
	if not _check(player.dodge_direction.dot(expected) > 0.99, "Roll direction ignored camera"): return false
	_touch(3, point, true)
	_touch(3, point, false)
	await _steps(int(ceil(player.locomotion_controller.ROLL_DURATION*60))+8)
	if not _check(rolls == initial + 1 and not player.is_dodging and not player.mobile_sprint_active, "held Roll repeated or requested Run"): return false
	_touch(2, point, false)
	touch.reset_input()
	await _ground()
	initial = rolls
	_touch(2, point, true)
	_touch(2, point, false)
	await _steps(28)
	if not _check(rolls == initial + 1 and not player.mobile_sprint_active, "quick Roll tap was lost or became Run"): return false
	observations["separate_roll"] = "PASS"
	return true

func _mixed_dash_ownership_and_drop() -> bool:
	await _ground()
	var initial := rolls
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _steps(8)
	if not _check(rolls == initial and player.mobile_sprint_active, "Shift rolled instead of Run"): return false
	var point: Vector2 = touch.dodge_btn.get_global_rect().get_center()
	_touch(2, point, true)
	_touch(2, point, false)
	await _steps(int(ceil(player.locomotion_controller.ROLL_DURATION*60))+8)
	if not _check(rolls == initial + 1 and player.mobile_sprint_active, "touch Roll canceled separately held keyboard Run"): return false
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await _ground()
	initial = rolls
	player.surface_traversal_enabled = true
	player.traversal.start_climbing(Vector3.BACK, player.global_position + Vector3.UP)
	touch.set_traversal_active(true)
	_touch(2, point, true)
	await _steps(3)
	if not _check(not player.traversal.is_climbing() and not player.is_dodging, "DROP did not release wall"): return false
	await _steps(30)
	if not _check(rolls == initial and not player.mobile_sprint_active, "held DROP became ground Roll/Run"): return false
	_touch(2, point, false)
	player.surface_motor.reset(player)
	player.surface_traversal_enabled = false
	touch.set_traversal_active(false)
	observations["keyboard_run_touch_roll_and_drop"] = "PASS"
	return true

func _jump_during_dash() -> bool:
	await _ground()
	var before_rolls := rolls
	var before_jumps := jumps
	_touch(2, touch.dodge_btn.get_global_rect().get_center(), true)
	await _steps(3)
	if not _check(rolls == before_rolls + 1 and player.is_dodging, "dash prerequisite missing for grounded jump cancellation"): return false
	var jump := touch.find_child("JumpBtn", true, false) as Button
	_touch(3, jump.get_global_rect().get_center(), true)
	if not _check(player.jump_buffer_timer > 0 and jumps == before_jumps + 1, "grounded dash did not accept press-requested jump"): return false
	_touch(3, Vector2.ZERO, false)
	_touch(2, Vector2.ZERO, false)
	# Requests enter the controller on the next physics tick, not within the
	# touch callback; two frame boundaries include its completed update.
	await _steps(2)
	if not _check(not player.is_dodging and player.velocity.y > 0 and not player.is_on_floor() and jumps == before_jumps + 1, "jump during dash did not start within the next physics update"): return false
	await _steps(100)
	if not _check(player.is_on_floor() and not player.is_dodging and player.jump_buffer_timer == 0 and jumps == before_jumps + 1, "landing replayed a delayed dash/jump"): return false
	observations["jump_during_dash"] = "PASS"
	return true

func _cancel_focus_and_modal() -> bool:
	await _ground()
	var initial := rolls
	var point: Vector2 = touch.dodge_btn.get_global_rect().get_center()
	_touch(2, point, true)
	_touch(2, point, false, true)
	await _steps(28)
	if not _check(rolls == initial and not player._dash_held and not player._requested_roll, "canceled touch replayed a queued dash"): return false
	_touch(2, point, true)
	main._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	if not _check(paused and not player._dash_held and not player._requested_roll and touch._action_touches.is_empty(), "focus loss retained a queued or held dash"): return false
	menu.set_session_paused(false)
	await _steps(28)
	if not _check(rolls == initial and not player.mobile_sprint_active, "focus resume replayed held input"): return false
	_touch(2, point, false)
	_touch(2, point, true)
	var jump := touch.find_child("JumpBtn", true, false) as Button
	_touch(3, jump.get_global_rect().get_center(), true)
	main._on_opening_dialogue_started()
	if not _check(player.control_locked and not touch.visible and player.jump_buffer_timer == 0 and not player._requested_roll, "dialogue modal retained queued jump/dash"): return false
	main._on_dialogue_finished()
	await _steps(28)
	if not _check(rolls == initial and not player.is_dodging and not player.mobile_sprint_active and player.is_on_floor(), "modal close replayed an action or bypassed floor state"): return false
	_touch(2, point, false)
	_touch(3, Vector2.ZERO, false)
	var window=main.hud.find_child("SystemWindow",true,false)
	var desktop:bool=not player.touch_input_enabled and DisplayServer.get_name()!="headless"
	if desktop: Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	window.show_system_window(0,"Record","Nonmodal record",[],4.0)
	if not _check(not player.control_locked,"Notification locked gameplay"): return false
	if desktop and not _check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Notification stole the desktop orbit cursor"): return false
	window.show_decision("Contract","Explicit action",[{"id":"ACCEPT","text":"Accept"}])
	if not _check(player.control_locked,"Decision did not own input"): return false
	window.show_system_window(0,"Record","Replaced decision",[],4.0)
	if not _check(not player.control_locked,"Modal replaced by notification retained its input lock"): return false
	if desktop and not _check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Modal replacement lost desktop orbit cursor"): return false
	window.close_window()
	observations["cancel_focus_modal"] = "PASS"
	return true

func _resize_cancel() -> bool:
	await _ground()
	var size := root.get_visible_rect().size
	var move_point: Vector2 = touch.joystick_center
	var look_point := Vector2(size.x * 0.62, size.y * 0.2)
	var dash_point: Vector2 = touch.dodge_btn.get_global_rect().get_center()
	var initial := rolls
	_touch(0, move_point, true)
	_drag(0, move_point + Vector2(60, 0))
	_touch(1, look_point, true)
	_touch(2, dash_point, true)
	# Emit the viewport's actual reflow signal before the queued dash executes.
	touch.get_viewport().size_changed.emit()
	if not _check(touch.joystick_touch_index == -1 and touch.camera_touch_index == -1 and touch._action_touches.is_empty(), "viewport reflow retained obsolete finger ownership"): return false
	if not _check(player.mobile_input_vector == Vector2.ZERO and not player._dash_held and not player._requested_roll, "viewport reflow retained movement or queued dash"): return false
	_touch(2, dash_point, false)
	await _steps(28)
	if not _check(rolls == initial and not player.mobile_sprint_active, "old release after viewport reflow replayed a dash/sprint"): return false
	observations["viewport_resize_cancel"] = "PASS"
	return true

func _interaction_and_captions() -> bool:
	touch.set_interaction_available(true)
	player.set_combat_available(true)
	if not _check(touch.use_btn.visible and touch.attack_btn.visible, "combat availability hid contextual interaction"): return false
	var before := uses
	var point: Vector2 = touch.use_btn.get_global_rect().get_center()
	_touch(2, point, true)
	if not _check(uses == before, "interaction activated on press instead of release"): return false
	_touch(2, point, false)
	if not _check(uses == before + 1, "combat interaction release did not reach the live signal"): return false
	player.set_combat_available(false)
	if not _check(touch.use_btn.visible and not touch.attack_btn.visible, "combat removal hid interaction or left combat action visible"): return false
	main.set_presentation_language("en")
	if not _check(_caption(touch.dodge_btn) == "ROLL" and _caption(touch.use_btn) == "USE", "English captions incomplete"): return false
	touch.set_traversal_active(true)
	if not _check(_caption(touch.dodge_btn) == "DROP", "traversal failed to relabel the unified control"): return false
	touch.set_traversal_active(false)
	main.set_presentation_language("ar")
	if not _check(_caption(touch.dodge_btn) == "تدحرج" and _caption(touch.use_btn) == "تفاعل", "Arabic captions incomplete"): return false
	for button in [touch.dodge_btn, touch.use_btn, touch.find_child("JumpBtn", true, false)]:
		var glyph = button.get_node_or_null("ActionGlyph")
		if not _check(glyph != null and glyph.texture != null and button.get_node_or_null("ActionCaption") != null and button.text == "", "control lost native glyph or independent live caption"): return false
		if not _check(button.size.x >= 48 and button.size.y >= 48, "touch target smaller than 48 logical pixels"): return false
	touch.set_interaction_available(false)
	observations["contextual_interaction_and_captions"] = "PASS"
	return true

func _camera_and_collision() -> bool:
	await _ground()
	main.set_reduced_motion(false)
	player.camera_boom.rotation = Vector3.ZERO
	_move_forward()
	# Face backward through the clear center of this staged opening fixture.
	_drag(0, touch.joystick_center + Vector2(0, 75))
	await _steps(55)
	var sprint_fov: float = player.player_camera.fov
	if not _check(sprint_fov > 69 and sprint_fov <= 70, "actual sprint did not approach the bounded 70-degree FOV"): return false
	main.set_reduced_motion(true)
	await _steps(65)
	var reduced_fov: float = player.player_camera.fov
	if not _check(absf(reduced_fov - 65) < 0.03, "reduced motion retained the expanded sprint FOV"): return false
	touch.reset_input()
	await _steps(16)
	main.set_reduced_motion(false)
	await _ground()
	player.control_locked = true
	player.camera_boom.rotation = Vector3.ZERO
	await _steps(3)
	var boom: SpringArm3D = player.camera_boom
	var origin := boom.global_position
	var wall := _box("CameraWallProbe", Vector3(4, 4, 0.2), origin + Vector3(0, 0, 1.0))
	await _steps(8)
	var wall_hit := boom.get_hit_length()
	if not _check(wall_hit > 0 and wall_hit < 0.9 and player.player_camera.global_position.z < wall.global_position.z - 0.1, "camera penetrated the staged wall"): return false
	wall.queue_free()
	await process_frame
	boom.rotation.x = 0.8
	await _steps(8)
	var floor_hit := boom.get_hit_length()
	if not _check(player.player_camera.global_position.y > 0.1 and floor_hit < boom.spring_length, "camera penetrated the actual room floor"): return false
	boom.rotation.x = -0.3
	var ceiling := _box("CameraCeilingProbe", Vector3(10, 0.2, 10), origin + Vector3(0, 0.65, 0))
	await _steps(8)
	var ceiling_hit := boom.get_hit_length()
	if not _check(ceiling_hit <= boom.spring_length + 0.001 and ceiling_hit < 2.0 and player.player_camera.global_position.y < ceiling.global_position.y - 0.1, "camera penetrated the staged ceiling"): return false
	ceiling.queue_free()
	await process_frame
	boom.rotation = Vector3.ZERO
	await _steps(35)
	if not _check(boom.get_hit_length() > boom.spring_length - 0.05, "SpringArm hit the excluded player after obstruction removal"): return false
	player.control_locked = false
	observations["camera"] = {"sprint_fov": sprint_fov, "reduced_fov": reduced_fov, "wall_hit": wall_hit, "floor_hit": floor_hit, "ceiling_hit": ceiling_hit}
	return true

func _tutorial_hint_layout() -> bool:
	var hint = main.hud.tutorial_toast
	var original_size := root.size
	var original_scale := root.content_scale_size
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2408, 1080)]:
		root.size = size
		root.content_scale_size = size
		for language in ["ar", "en"]:
			main.set_presentation_language(language)
			hint.show_toast("HINT_LAYOUT", "TOUCH", main.opening_text("التحرك والتفاعل", "Move and inspect"), main.opening_text("حرّك إيكو بالمقبض، ثم افحص الساعة المتوقفة.", "Move Echo with the stick, then inspect the stopped clock."), 6)
			# HUD and translated Control reflow happen on rendered process frames.
			# Several physics ticks may share one frame on this integrated GPU.
			for i in range(3): await process_frame
			var rect: Rect2 = hint.toast_panel.get_global_rect()
			if not _check(Rect2(Vector2.ZERO, Vector2(size)).encloses(rect), "tutorial hint exceeds viewport: " + language): return false
			if not _check(not rect.intersects(main.hud.compass_bar.get_global_rect()) and not rect.intersects(main.hud.quest_container.get_global_rect()), "tutorial hint overlaps compass/objective: %s viewport=%s hint=%s compass=%s quest=%s" % [language, size, rect, main.hud.compass_bar.get_global_rect(), main.hud.quest_container.get_global_rect()]): return false
	root.size = original_size
	root.content_scale_size = original_scale
	hint.set_reduced_motion(false)
	hint.show_toast("OLD_HINT", "E", "Old", "Old description", 6)
	hint.dismiss_toast()
	hint.show_toast("NEW_HINT", "E", "New", "New description", 6)
	await _steps(22)
	if not _check(hint.visible and hint.active_toast_id == "NEW_HINT" and hint.modulate.a > 0.99, "old dismiss tween hid newer hint"): return false
	main.set_reduced_motion(true)
	hint.show_toast("REDUCED_HINT", "E", "Hint", "Description", 6)
	if not _check(hint.visible and hint.modulate.a == 1.0, "reduced-motion hint still fades in"): return false
	hint.dismiss_toast()
	if not _check(not hint.visible, "reduced-motion hint still fades out"): return false
	observations["tutorial_hint_layout_race_reduced_motion"] = "PASS"
	return true

func _settings_and_reload() -> bool:
	main.set_control_preferences({"mouse_sensitivity": 10, "touch_sensitivity": -3, "scale": 10, "opacity": -4, "inset_x": -100, "inset_y": 500})
	var clamped: Dictionary = main.get_control_preferences()
	if not _check(is_equal_approx(clamped.mouse_sensitivity, 2) and is_equal_approx(clamped.touch_sensitivity, 0.5) and is_equal_approx(clamped.scale, 1.3) and is_equal_approx(clamped.opacity, 0.25) and is_zero_approx(clamped.inset_x) and is_equal_approx(clamped.inset_y, 100), "control bounds were not applied"): return false
	main.set_control_preferences({"mouse_sensitivity": NAN, "touch_sensitivity": INF, "scale": "invalid", "opacity": false, "inset_x": Vector2.ONE, "inset_y": null})
	var sanitized: Dictionary = main.get_control_preferences()
	for key in sanitized:
		if not _check((sanitized[key] is float or sanitized[key] is int) and is_finite(float(sanitized[key])), "invalid setting escaped validation: " + key): return false
	var saved := {"mouse_sensitivity": 1.8, "touch_sensitivity": 0.6, "scale": 1.1, "opacity": 0.65, "inset_x": 24.0, "inset_y": 36.0, "deadzone": 0.2, "joystick_x": 18.0, "joystick_y": 26.0}
	main.set_control_preferences(saved)
	player.set_gameplay_orbit(Vector3.ZERO)
	player.apply_camera_look(Vector2(100, 0))
	var mouse_delta: float = player.camera_target_rotation.y
	player.set_gameplay_orbit(Vector3.ZERO)
	player.apply_touch_camera_look(Vector2(100, 0))
	var touch_delta: float = player.camera_target_rotation.y
	if not _check(absf(mouse_delta) > absf(touch_delta) * 1.9 and absf(touch_delta) > 0.01, "mouse and touch sensitivity did not remain independent"): return false
	main.queue_free()
	await process_frame
	await _boot()
	var restored: Dictionary = main.get_control_preferences()
	for key in saved:
		if not _check(is_equal_approx(float(saved[key]), float(restored[key])), "control preference failed fresh-scene persistence: " + key): return false
	menu.set_session_paused(true)
	await process_frame
	var bounds: Rect2 = menu.panel.get_global_rect()
	if not _check(bounds.position.x >= 0 and bounds.position.y >= 0 and bounds.end.x <= root.get_visible_rect().size.x and bounds.end.y <= root.get_visible_rect().size.y, "settings pause panel clipped outside the viewport"): return false
	menu.set_session_paused(false)
	observations["controls"] = {"clamped": clamped, "sanitized": sanitized, "restored": restored, "mouse_yaw_delta": mouse_delta, "touch_yaw_delta": touch_delta}
	return true

func _move_forward() -> void:
	var origin: Vector2 = touch.joystick_center
	_touch(0, origin, true)
	_drag(0, origin + Vector2(0, -75))

func _touch(index: int, position: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	event.canceled = canceled
	touch._input(event)

func _drag(index: int, position: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	touch._input(event)

func _caption(button: Button) -> String:
	var label := button.get_node_or_null("ActionCaption") as Label
	return label.text if label else button.text

func _box(label: String, size: Vector3, position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	main.add_child(body)
	body.global_position = position
	return body

func _steps(count: int) -> void:
	for _frame in range(count): await physics_frame

func _clear_files() -> void:
	for path in [SAVE, SAVE + ".bak", SAVE + ".tmp", PREFS]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("PLAYER_FOUNDATION: " + message)
		paused = false
		quit(1)
	return condition
