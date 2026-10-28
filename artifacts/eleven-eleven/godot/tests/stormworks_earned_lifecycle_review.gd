extends "res://tests/stormworks_parkour_input_review.gd"

## Reloads a byte-identical checkpoint earned by the separate actual-input journey.
## Failure injection is explicitly scoped; it never fabricates chapter completion.
const Route = preload("res://scripts/systems/stormworks_route.gd")
const RoomSave = preload("res://scripts/systems/stormworks_checkpoint.gd")
var director: Node
var evidence: String
var earned: String
var opening: String
var case_path: String
var current_case: String

func _record(label: String, passed: bool, detail: Variant = null) -> void:
	report.checks.append({"case":current_case,"check":label,"pass":passed,"detail":detail})
	print("STORMWORKS_LIFECYCLE ",current_case," ",label," ",passed)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()<2:quit(2);return
	earned = args[0]
	opening = earned.get_base_dir().path_join("opening.json")
	evidence = args[1]
	if RoomSave.read(earned).get("stage") != 5 or not FileAccess.file_exists(opening):quit(2);return
	if DirAccess.dir_exists_absolute(evidence):quit(2);return
	DirAccess.make_dir_recursive_absolute(evidence)
	report.scope = "Actual earned-stage5 reload,service lifecycle,failed-save denial;opening-complete fixture inherited from journey;not chapter/art/performance acceptance"
	report.earned_profile_sha256 = FileAccess.get_sha256(earned)
	for mode in ["normal-pause","skip","reduced-motion","failed-save"]:
		current_case = mode
		await _load_earned_case(mode)
		if mode == "failed-save":await _failed_save_case()
		else:await _service_case(mode)
		await _dispose_case()
	report.status = "PASS_EARNED_LIFECYCLE" if report.checks.all(func(row: Dictionary):return row.pass) else "FAIL_EARNED_LIFECYCLE"
	report.earned_profile_unchanged = FileAccess.get_sha256(earned) == report.earned_profile_sha256
	if not report.earned_profile_unchanged:report.status = "FAIL_EARNED_LIFECYCLE"
	var file := FileAccess.open(evidence.path_join("review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("STORMWORKS_LIFECYCLE_RESULT ",report.status)
	quit(0 if report.status == "PASS_EARNED_LIFECYCLE" else 1)

func _load_earned_case(mode: String) -> void:
	case_path = evidence.path_join(mode)
	DirAccess.make_dir_recursive_absolute(case_path)
	DirAccess.copy_absolute(earned,case_path.path_join("maintenance.json"))
	DirAccess.copy_absolute(opening,case_path.path_join("opening.json"))
	world = load("res://tests/scenes/stormworks_native_candidate.tscn").instantiate()
	world.native_checkpoint_path = case_path.path_join("opening.json")
	world.native_preferences_path = case_path.path_join("preferences.cfg")
	world.get_node("SystemJourneyPreview").checkpoint_path = case_path.path_join("maintenance.json")
	world.get_node("NativeJourneyController").checkpoint_path = case_path.path_join("route.json")
	world.get_node("NativeCampaignController").checkpoint_path = case_path.path_join("campaign.json")
	root.add_child(world)
	for i in 40:
		if paused and world.native_pause_menu:world.native_pause_menu.resume_button.pressed.emit()
		await process_frame
		await physics_frame
	player = world.player
	director = world.get_node("SystemJourneyPreview")
	room = director.room
	world.set_audio_muted(true)
	world.set_reduced_motion(false)
	var dialogue = world.hud.find_child("DialogueOverlay",true,false)
	for i in 8:
		if dialogue.is_active:dialogue.continue_button.pressed.emit()
		await process_frame
	await _frames(10)
	_record("earned_stage5_restored",director.stage == 5 and director.course_step == 3 and director.has_confirmed_room_checkpoint())
	_record("restored_safe_anchor_without_teleport",_pos().distance_to(Route.anchor(5,3))<.25 and player.is_on_floor(),str(_pos()))
	_record("restored_gate_closed_and_silent",not room.service_open and not room._release_audio.playing and not director.service_cinematic.active)
	_record("source_profile_copy_identical",FileAccess.get_sha256(earned) == FileAccess.get_sha256(case_path.path_join("maintenance.json")))

func _service_case(mode: String) -> void:
	var reached := await _go_to(room.service_floor_anchor)
	await _frames(8)
	_record("wheel_reached_by_public_input",reached and player.get_nearest_interactable() == room.service_interaction)
	if not reached:return
	world.set_audio_muted(false)
	if mode == "reduced-motion":world.set_reduced_motion(true)
	var result := player.interact_with_nearest()
	_record("real_service_started",result.get("data",{}).get("released",false) and room._release_audio.playing)
	_record("duplicate_activation_denied",not room.request_service_release(player).get("released",false))
	var cinematic = director.service_cinematic
	_record("cinematic_respects_motion_preference",cinematic.active == (mode != "reduced-motion"))
	if mode == "skip":
		cinematic._skip.pressed.emit()
		await _frames(24)
		_record("skip_returns_camera_without_opening_gate",not cinematic.active and not player.control_locked and not room.service_open and room.service_opening and root.get_camera_3d() == player.player_camera)
	if mode == "normal-pause":
		await _frames(12)
		automatic_focus_resume = false
		world.native_pause_menu.set_session_paused(true)
		var gate_pose: Vector3 = room._gate.position
		var camera: Camera3D = root.get_camera_3d()
		var camera_pose := camera.global_transform
		var gesture_time: float = room.hand_contact.elapsed
		var water_time: float = room.presentation._elapsed
		await create_timer(.12,true,false,true).timeout
		_record("pause_freezes_gate_camera_contact_vfx",room._gate.position == gate_pose and camera.global_transform.is_equal_approx(camera_pose) and is_equal_approx(room.hand_contact.elapsed,gesture_time) and is_equal_approx(room.presentation._elapsed,water_time) and director.stage == 5)
		world.set_audio_muted(true)
		_record("pause_mute_applies_to_actual_audio_bus",AudioServer.is_bus_mute(0))
		world.native_pause_menu.set_session_paused(false)
		automatic_focus_resume = true
	if mode == "reduced-motion":
		var elapsed: float = room.presentation._elapsed
		var wheel: Vector3 = room._valve.rotation
		await _frames(12)
		_record("reduced_motion_freezes_ambient_and_wheel",is_equal_approx(room.presentation._elapsed,elapsed) and room._valve.rotation == wheel and not player.control_locked)
	await _frames(225)
	_record("actual_gate_completion_saved",room.service_open and room._gate_collider.disabled and director.stage == 6 and director.has_confirmed_room_checkpoint())
	_record("controls_camera_and_ik_released",not player.control_locked and not cinematic.active and root.get_camera_3d() == player.player_camera and not room.hand_contact.active and room.hand_contact._solvers.is_empty())
	if mode == "normal-pause":
		_record("actual_hand_contacts_within_tolerance",room.hand_contact.contact_sample_count>=20 and room.hand_contact.max_contact_error<.04,{"samples":room.hand_contact.contact_sample_count,"max_error_m":room.hand_contact.max_contact_error})
	world.set_audio_muted(true)
	var reload_path := case_path.path_join("maintenance.json")
	await _dispose_case()
	# Reload the exact stage6 file produced above into a fresh scene.
	world = load("res://tests/scenes/stormworks_native_candidate.tscn").instantiate()
	world.native_checkpoint_path = case_path.path_join("opening.json")
	world.native_preferences_path = case_path.path_join("preferences.cfg")
	world.get_node("SystemJourneyPreview").checkpoint_path = reload_path
	world.get_node("NativeJourneyController").checkpoint_path = case_path.path_join("route.json")
	world.get_node("NativeCampaignController").checkpoint_path = case_path.path_join("campaign.json")
	root.add_child(world)
	for i in 40:
		if paused and world.native_pause_menu:world.native_pause_menu.resume_button.pressed.emit()
		await physics_frame
		await process_frame
	player = world.player;director = world.get_node("SystemJourneyPreview");room = director.room
	_record("earned_stage6_reloads_open_silently",director.stage == 6 and room.service_open and room._gate_collider.disabled and not room._release_audio.playing and not director.service_cinematic.active and not player.control_locked)
	_record("no_precontract_power_on_reload",not player.combat_available and not player.contract_with_zero_sealed)

func _failed_save_case() -> void:
	director.checkpoint_path = case_path.path_join("missing-parent/denied.json")
	# Explicit save-failure injection using an actually earned stage5 state.
	director._checkpoint_here()
	await _frames(20)
	_record("failed_save_not_confirmed",not director.has_confirmed_room_checkpoint() and not director.save_succeeded)
	_record("actual_failed_save_attempt_at_safe_anchor",director._save_retry_after>0 and director._save_ready and not FileAccess.file_exists(director.checkpoint_path))
	var reached := await _go_to(room.service_floor_anchor)
	_record("failure_case_reached_wheel",reached)
	_record("failed_save_wheel_denied",not player.interact_with_nearest().get("data",{}).get("released",false) and not room.service_opening and not room.service_open)
	_record("failed_save_no_chapter_receipt",not world.get_node("NativeJourneyController").progress.completed.has("maintenance_completed"))
	director.checkpoint_path = case_path.path_join("maintenance.json")
	var returned := await _go_to(Route.anchor(5,3))
	await _frames(80)
	_record("save_retry_recovers_at_safe_anchor",returned and director.has_confirmed_room_checkpoint() and RoomSave.read(director.checkpoint_path).get("stage") == 5)

func _dispose_case() -> void:
	paused = false
	if is_instance_valid(world):world.queue_free()
	for i in 8:await process_frame
	world = null;player = null;room = null;director = null
