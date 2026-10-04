extends SceneTree

const PATH := "user://maintenance_service_smoke.json"
var main: Node
var director: Node
var player: EchoPlayer

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for capability in ["TwoBoneIK3D","RetargetModifier3D","SpringBoneSimulator3D"]:
		if not _check(ClassDB.class_exists(capability), "Godot animation capability unavailable: " + capability): return
	_cleanup()
	# Save-state fixture, not a claim of completing the chapter.
	_write(5)
	main = load("res://scenes/system_journey_preview.tscn").instantiate()
	main.native_checkpoint_path = "user://service_opening_smoke.json"
	main.native_preferences_path = "user://service_prefs_smoke.cfg"
	root.add_child(main)
	director = main.get_node("SystemJourneyPreview")
	director.checkpoint_path = PATH
	await process_frame
	player = main.player
	main.set_audio_muted(true)
	if "--reduced" in args: main.set_reduced_motion(true)
	player.finish_opening_recovery()
	var dialogue = main.hud.find_child("DialogueOverlay",true,false)
	for i in range(8):
		if dialogue.is_active: dialogue.continue_button.pressed.emit()
		await process_frame
	main.opening_web_handoff.reported_milestones.append("memory_scene_completed")
	for i in range(15): await physics_frame
	var room = director.room
	if not _check(director.stage == 5 and not room.service_open, "old stage-5 checkpoint skipped the new task"): return
	player.camera_boom.rotation.y = 0
	player.set_mobile_input_vector(Vector2.RIGHT, true)
	for i in range(35):
		await physics_frame
		if player.position.x >= 2.8: break
	player.set_mobile_input_vector(Vector2.ZERO, true)
	for i in range(5): await physics_frame
	if not _check(not room.request_service_release(player).released, "wheel accepted remote interaction"): return
	player.set_mobile_input_vector(Vector2.LEFT, true)
	for i in range(100):
		await physics_frame
		if player.position.x <= 1.25: break
	player.set_mobile_input_vector(Vector2.ZERO, true)
	for i in range(8): await physics_frame
	if not _check(player.get_nearest_interactable() == room.service_interaction, "wheel proximity not registered"): return
	# Physical capsule must be blocked by the sealed panel.
	var from := player.global_transform
	from.origin = Vector3(0,5.41,-30.4)
	if not _check(player.test_move(from,Vector3(0,0,-1)), "closed panel has no physical barrier"): return
	main.set_presentation_language("en")
	if not _check(room.service_interaction.prompt_target_name == "Pressure relief wheel", "English wheel label missing"): return
	main.set_presentation_language("ar")
	if not _check(room.service_interaction.prompt_target_name.contains("الضغط"), "Arabic wheel label missing"): return
	main.set_audio_muted(false)
	var result := player.interact_with_nearest()
	if not _check(result.get("data",{}).get("released",false) and room._release_audio.playing, "actual interaction did not start the provider cue"): return
	if not _check(not room.request_service_release(player).released, "duplicate wheel activation accepted"): return
	var cinematic = director.service_cinematic
	var player_camera = player.find_child("Camera3D",true,false)
	if not _check(cinematic.active == (not main.reduced_motion), "cinematic ignored reduced motion"): return
	if "--normal" in args:
		if not _check(room.hand_contact.active, "service gesture failed: " + room.hand_contact.start_result): return
	if "--skip" in args:
		cinematic._skip.pressed.emit()
		await create_timer(0.5).timeout
		if not _check(not cinematic.active and not player.control_locked and not room.service_open and room.service_opening and root.get_camera_3d() == player_camera, "skip changed gate authority or retained control/camera"): return
	for i in range(12): await physics_frame
	main.native_pause_menu.set_session_paused(true)
	var gate_pose: Vector3 = room._gate.position
	var paused_camera = root.get_camera_3d()
	var paused_camera_pose: Transform3D = paused_camera.global_transform
	var paused_gesture_time: float = room.hand_contact.elapsed
	await create_timer(0.12).timeout
	if not _check(room._gate.position == gate_pose and director.stage == 5, "pause advanced the gate or task"): return
	if not _check(paused_camera.global_transform.is_equal_approx(paused_camera_pose), "pause advanced the cinematic camera"): return
	if not _check(is_equal_approx(room.hand_contact.elapsed,paused_gesture_time), "pause advanced hand gesture"): return
	if "--normal" not in args:
		main.set_reduced_motion(true)
		if not _check(room._valve.rotation == room._closed_valve and not cinematic.active and not player.control_locked, "reduced motion did not end the camera insert and wheel rotation"): return
	main.set_audio_muted(true)
	if not _check(AudioServer.is_bus_mute(0), "provider cue bypassed mute"): return
	main.native_pause_menu.set_session_paused(false)
	for i in range(220): await physics_frame
	if not _check(room.service_open and director.stage == 6 and room._gate_collider.disabled, "release never cleared the barrier"): return
	if not _check(not cinematic.active and not player.control_locked and root.get_camera_3d() == player_camera, "normal insert retained camera or controls"): return
	if "--normal" in args:
		print("HAND_CONTACT samples=",room.hand_contact.contact_sample_count," max_m=",room.hand_contact.max_contact_error)
		if not _check(room.hand_contact.contact_sample_count >= 20 and room.hand_contact.max_contact_error < 0.04, "service wrists do not reach wheel rim"): return
	if not _check(not room.hand_contact.active and room.hand_contact._solvers.is_empty(), "service retained skeleton modifiers"): return
	if not _check(not player.test_move(from,Vector3(0,0,-1)), "cleared panel still blocks the capsule"): return
	_write(6)
	director._restore()
	if not _check(room.service_open and not room._release_audio.playing and director.stage == 6, "resume replayed audio or closed the door"): return
	if not _check(not player.contract_with_zero_sealed and not player.combat_available, "service task enabled powers"): return
	# Negative staged fixture: presentation may never pull the capsule through a wall.
	player.control_locked = true
	var anchor: Vector3 = room.to_global(Vector3(1.25,5.4,-12.18))
	player.global_position = anchor + Vector3(0.8,0,0)
	var blocker := StaticBody3D.new()
	var blocker_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.1,2,0.8)
	blocker_shape.shape = box
	blocker.add_child(blocker_shape)
	root.add_child(blocker)
	blocker.global_position = anchor + Vector3(0.4,1,0)
	await physics_frame
	var blocked_gesture = room.HAND_CONTACT.new()
	room.add_child(blocked_gesture)
	var initial_pose: Transform3D = player.global_transform
	if not _check(not blocked_gesture.begin(player,room) and blocked_gesture.start_result == "alignment_blocked" and blocked_gesture._solvers.is_empty() and player.global_transform == initial_pose, "blocked gesture moved player or created IK"): return
	blocked_gesture.queue_free()
	blocker.queue_free()
	player.global_position = anchor + Vector3(2,0,0)
	var distant_gesture = room.HAND_CONTACT.new()
	room.add_child(distant_gesture)
	if not _check(not distant_gesture.begin(player,room) and distant_gesture.start_result == "alignment_too_far", "gesture accepted distant alignment"): return
	distant_gesture.queue_free()
	player.control_locked = false
	main.queue_free()
	for i in range(4): await process_frame
	await create_timer(0.12).timeout
	_cleanup()
	print("PASS maintenance service: old checkpoint migration, proximity, blocked/clear capsule, bilingual labels, single activation, sound/mute, pause, reduced motion, silent restore and no powers")
	quit()

func _write(stage: int) -> void:
	var file := FileAccess.open(PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":"echo-maintenance-preview-v1","stage":stage}))
	file.close()

func _cleanup() -> void:
	for base in [PATH,"user://service_opening_smoke.json","user://service_prefs_smoke.cfg"]:
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(base+suffix): DirAccess.remove_absolute(base+suffix)

func _check(condition: bool, detail: String) -> bool:
	if condition: return true
	push_error(detail)
	paused = false
	quit(1)
	return false
