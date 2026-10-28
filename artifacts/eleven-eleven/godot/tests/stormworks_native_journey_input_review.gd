extends "res://tests/stormworks_parkour_input_review.gd"

const Saves = preload("res://scripts/systems/save_manager.gd")
const Route = preload("res://scripts/systems/stormworks_route.gd")
const RoomSave = preload("res://scripts/systems/stormworks_checkpoint.gd")
var director: Node
var native_owner: Node
var evidence: String
var paths := {}

func _source_hashes() -> Dictionary:
	var hashes := {}
	for path in ["scenes/native_journey.tscn","tests/scenes/stormworks_native_candidate.tscn","scripts/environment/maintenance_stormworks.gd","scripts/environment/maintenance_vertical.gd","scripts/environment/maintenance_stormworks_vfx.gd","scripts/environment/maintenance_stormworks_presentation.gd","scripts/systems/stormworks_route.gd","scripts/systems/stormworks_checkpoint.gd","scripts/systems/stormworks_journey_preview.gd","scripts/systems/native_journey_controller.gd","scripts/systems/native_campaign_controller.gd","scripts/player/surface_traversal_motor.gd","scripts/player/service_hand_contact.gd","scripts/cinematics/maintenance_service_cinematic.gd","engine_visuals/HyperAnimeWorldManager.gd","shaders/maintenance_stormworks_water.gdshader","shaders/maintenance_stormworks_wind.gdshader","tests/stormworks_parkour_input_review.gd","tests/stormworks_native_journey_input_review.gd","assets/environments/maintenance_stormworks/stormworks_collision_portal_v7.glb"]:
		hashes[path] = FileAccess.get_sha256("res://"+path)
	var directory := "res://assets/environments/maintenance_stormworks"
	for name in DirAccess.get_files_at(directory):
		if name.begins_with("stormworks_original_pbr_metric_v8") or name.begins_with("stormworks_precision_"):
			hashes[directory.trim_prefix("res://")+"/"+name] = FileAccess.get_sha256(directory.path_join(name))
	return hashes

func _record(label: String, passed: bool, detail: Variant = null) -> void:
	report.checks.append({"check":label,"pass":passed,"detail":detail})
	print("STORMWORKS_NATIVE ",label," ",passed)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():quit(2);return
	evidence = args[0]
	capture_directory = evidence.path_join("captures")
	DirAccess.make_dir_recursive_absolute(capture_directory)
	DirAccess.make_dir_recursive_absolute(evidence)
	for name in ["opening.json","maintenance.json","route.json","campaign.json","preferences.cfg"]:
		paths[name] = evidence.path_join(name)
	report.source_hashes = _source_hashes()
	if FileAccess.file_exists(paths["opening.json"]):
		push_error("Use a fresh evidence directory;earned profiles are preserved")
		quit(2)
		return
	var opening := {"schema":Saves.OPENING_SCHEMA,"milestones":{"wake":true,"clock":true,"photo":true,"memory":true,"terminal":true,"conduit":true,"ending":true},"terminal":{"frequency":111.0,"phase":45.0,"harmonic":7.0}}
	if not Saves.save_opening_checkpoint(opening,paths["opening.json"]):quit(2);return
	report.scope = "Native controller/parkour/service/handoff;validated opening-complete fixture and one declared entry anchor;not full chapter acceptance"
	world = load("res://tests/scenes/stormworks_native_candidate.tscn").instantiate()
	world.native_checkpoint_path = paths["opening.json"]
	world.native_preferences_path = paths["preferences.cfg"]
	world.get_node("SystemJourneyPreview").checkpoint_path = paths["maintenance.json"]
	world.get_node("NativeJourneyController").checkpoint_path = paths["route.json"]
	world.get_node("NativeCampaignController").checkpoint_path = paths["campaign.json"]
	root.unfocusable = true
	root.size = Vector2i(1280,720)
	root.add_child(world)
	for i in 40:
		if paused and world.native_pause_menu:world.native_pause_menu.resume_button.pressed.emit()
		await process_frame
		await physics_frame
	player = world.player
	director = world.get_node("SystemJourneyPreview")
	native_owner = world.get_node("NativeJourneyController")
	room = director.room
	if not is_instance_valid(room):
		push_error("Opening fixture did not activate the real room controller")
		quit(2)
		return
	print("STORMWORKS_NATIVE room_ready ",room.name)
	world.set_audio_muted(true)
	world.set_reduced_motion(false)
	world.set_visual_quality("high")
	var dialogue = world.hud.find_child("DialogueOverlay",true,false)
	for i in 8:
		if dialogue.is_active:dialogue.continue_button.pressed.emit()
		await process_frame
	# Sole declared actor anchor. Every subsequent transfer uses public inputs.
	player.global_position = room.to_global(Vector3(-1.15,.1,-3.4))
	player.velocity = Vector3.ZERO
	await _exercise_course()
	await _frames(12)
	_record("controller_earned_stage5",director.stage == 5 and director.course_step == 3,{"stage":director.stage,"course_step":director.course_step})
	_record("stage5_checkpoint_confirmed",director.has_confirmed_room_checkpoint() and RoomSave.read(paths["maintenance.json"]).get("stage") == 5)
	if director.has_confirmed_room_checkpoint() and director.stage == 5:
		var copied := DirAccess.copy_absolute(paths["maintenance.json"],evidence.path_join("earned-stage5.json"))
		_record("earned_stage5_profile_preserved",copied == OK and RoomSave.read(evidence.path_join("earned-stage5.json")).get("stage") == 5)
	if report.checks.all(func(row: Dictionary):return row.get("pass",false)):
		await _service_and_handoff()
	report.renderer = RenderingServer.get_current_rendering_method()
	report.device = RenderingServer.get_video_adapter_name()
	report.display_server = DisplayServer.get_name()
	_record("source_snapshot_unchanged",report.source_hashes == _source_hashes())
	if report.has("captures"):_record("captures_saved",report.captures.all(func(row: Dictionary):return row.saved))
	report.status = "PASS_SCOPED_NATIVE" if report.checks.all(func(row: Dictionary):return row.get("pass",false)) else "FAIL_SCOPED_NATIVE"
	report.transition_rejection = player.surface_motor.last_transition_rejection
	var file := FileAccess.open(evidence.path_join("review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("STORMWORKS_NATIVE_RESULT ",report.status)
	world.queue_free()
	for i in 6:await process_frame
	quit(0 if report.status == "PASS_SCOPED_NATIVE" else 1)

func _service_and_handoff() -> void:
	_record("remote_wheel_rejected",not room.request_service_release(player).get("released",false))
	var reached := await _go_to(room.service_floor_anchor)
	await _frames(12)
	_record("wheel_reached_by_input",reached and player.get_nearest_interactable() == room.service_interaction,str(_pos()))
	if not report.checks.back().get("pass",false):return
	var result := player.interact_with_nearest()
	_record("actual_service_interaction",result.get("data",{}).get("released",false))
	if not report.checks.back().get("pass",false):return
	_record("real_cinematic_owns_controls",director.service_cinematic.active and player.control_locked)
	_record("new_wheel_hand_contact",room.hand_contact.active,room.hand_contact.start_result)
	await _frames(60)
	await _capture("service-insert")
	await _frames(160)
	_record("gate_open_and_stage6_saved",room.service_open and director.stage == 6 and director.has_confirmed_room_checkpoint())
	_record("camera_control_returned",not player.control_locked and not director.service_cinematic.active and root.get_camera_3d() == player.player_camera)
	var centered := await _go_to(Vector3(0,5.6,-17.6))
	var exited := false
	if centered:exited = await _go_to(Vector3(0,5.6,-18.85))
	await _frames(12)
	await _capture("service-door-crossed")
	_record("open_door_crossed_by_input",exited and director.stage == 7 and director.has_confirmed_room_checkpoint(),str(_pos()))
	if not report.checks.back().get("pass",false):return
	var entered := await _go_to(Vector3(0,5.6,-19.4))
	await _frames(15)
	_record("security_handoff_by_input",entered and native_owner.security_entered and native_owner.progress.completed.size() == 3,str(_pos()))
	var expected: Vector3 = room.to_global(Route.SECURITY_LOCAL_ORIGIN)-native_owner.SECURITY_ORIGIN
	_record("security_offset_measured",native_owner.downstream_offset.distance_to(expected)<.0001,str(native_owner.downstream_offset))
	var campaign = world.get_node("NativeCampaignController")
	var aligned: bool = campaign.rooms.size() == 6 and campaign.conduits.size() == 6
	for index in campaign.rooms.size():
		aligned = aligned and campaign.rooms[index].position.distance_to(campaign.ORIGINS[index]+expected)<.0001
		var conduit: Vector3 = (Vector3(0,5.4,-50) if index == 0 else campaign.ORIGINS[index-1]+campaign.EXITS[index-1])+expected
		aligned = aligned and campaign.conduits[index].position.distance_to(conduit)<.0001
	_record("all_rooms_and_conduits_share_offset",aligned)
	_record("pre_contract_combat_remains_locked",not player.combat_available)
	await _capture("security-entry")
