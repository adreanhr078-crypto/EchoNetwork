extends SceneTree

## Live existing-avatar review; no source motion, retarget or Golden changes.
## Isolated entry and input are staged; this is not a chapter or phone verdict.
var FOLDER := "res://../audits/evidence/quality-repair-20261006/locomotion-before/"
var main: Node
var player: EchoPlayer
var touch: MobileTouchControls
var trace := []
var frame := 0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): FOLDER = "res://../audits/evidence/quality-repair-20261006/" + args[0].validate_filename() + "/"
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var folder := ProjectSettings.globalize_path(FOLDER)
	DirAccess.make_dir_recursive_absolute(folder)
	main = load("res://scenes/opening_native_room.tscn").instantiate()
	main.native_checkpoint_path = "user://art_review_opening.json"
	main.native_preferences_path = "user://art_review_prefs.cfg"
	root.add_child(main)
	await process_frame
	main.set_audio_muted(true)
	player = main.player
	touch = main.hud.find_child("MobileTouchControls", true, false)
	touch._platform_touch_enabled = true
	touch.set_interaction_blocked(false)
	player.finish_opening_recovery()
	var dialogue = main.hud.find_child("DialogueOverlay", true, false)
	for i in range(8):
		if dialogue.is_active: dialogue.continue_button.pressed.emit()
		await process_frame
	main.native_pause_menu.set_session_paused(false)
	# Cross the verified clear central strip, away from cryopod/prop colliders.
	player.position = Vector3(-5, 0.06, -10)
	player.velocity = Vector3.ZERO
	player.set_gameplay_orbit(Vector3(-0.15, -PI/2, 0))
	for i in range(30): await physics_frame
	await _capture("idle", 30, Vector2.ZERO)
	await _capture("partial_walk", 60, Vector2(0, -0.4))
	await _capture("stop", 25, Vector2.ZERO)
	await _capture("full_run", 90, Vector2(0, -1))
	await _capture("run_stop", 40, Vector2.ZERO)
	var max_run := 0.0
	for row in trace:
		if row.label == "full_run": max_run = maxf(max_run, row.speed_mps)
	if max_run < 5.7:
		push_error("art review did not reach actual Run; do not accept the fixture")
	var file := FileAccess.open(folder + "trace.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"status": "CAPTURED_FOR_REVIEW", "fixed_render_fps": 60, "physical_phone": false, "source_motion_edited": false, "frames": trace}, "\t"))
	file.close()
	main.queue_free()
	await process_frame
	for path in ["user://art_review_opening.json", "user://art_review_prefs.cfg"]:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("CAPTURED existing player idle/walk/run/stop for artistic review; max_run=", max_run, "; no quality acceptance implied")
	quit(0 if max_run >= 5.7 else 1)

func _capture(label: String, frames: int, input: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = touch.joystick_center
	press.pressed = not input.is_zero_approx()
	touch._input(press)
	if press.pressed:
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = touch.joystick_center + input.normalized() * touch.joystick_radius() * (touch.joystick_deadzone + (1.0-touch.joystick_deadzone)*input.length())
		touch._input(drag)
	for i in range(frames):
		await process_frame
		await RenderingServer.frame_post_draw
		var screenshot := root.get_texture().get_image()
		screenshot.save_png(ProjectSettings.globalize_path(FOLDER) + "frame-%05d.png" % frame)
		trace.append({"frame": frame, "label": label, "clip": player.current_anim, "position": [player.position.x,player.position.y,player.position.z], "speed_mps": Vector2(player.velocity.x,player.velocity.z).length(), "playback_rate": player.animation_player.speed_scale, "grounded": player.is_on_floor(), "control_locked": player.control_locked, "stick_owned": player.mobile_move_owned, "paused": paused})
		frame += 1
