extends "res://tests/stormworks_parkour_input_review.gd"

## Current player-camera UV review from an actual historical earned checkpoint.
## Presentation diagnosis only;no new hazard,grant,teleport or room-state injection.
var evidence: String
func _walk_decon_leg(target:Vector3)->bool:
	# The inherited three-second walk was sized for short parkour approaches.
	# Continue actual input only while a long room leg makes real progress.
	var distance:=Vector2(_pos().x-target.x,_pos().z-target.z).length()
	var attempts:=ceili(distance/2.0)+3
	for i in attempts:
		if await _go_to(target):return true
		var remaining:=Vector2(_pos().x-target.x,_pos().z-target.z).length()
		if remaining>=distance-.1:return false
		distance=remaining
	return false
func _record(label: String, passed: bool, detail: Variant = null) -> void:
	report.checks.append({"check":label,"pass":passed,"detail":detail})
	print("DECON_PLAYER ",label," ",passed)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()<2:quit(2);return
	var earned: String = args[0]
	evidence = args[1]
	if DirAccess.dir_exists_absolute(evidence):quit(2);return
	DirAccess.make_dir_recursive_absolute(evidence)
	capture_directory = evidence.path_join("frames")
	DirAccess.make_dir_recursive_absolute(capture_directory)
	var profile := evidence.path_join("profile")
	DirAccess.make_dir_recursive_absolute(profile)
	var source_hashes := {}
	for name in ["opening.json","maintenance.json","route.json","campaign.json","preferences.cfg"]:
		var source := earned.path_join(name)
		if not FileAccess.file_exists(source) or DirAccess.copy_absolute(source,profile.path_join(name)) != OK:quit(2);return
		source_hashes[name] = FileAccess.get_sha256(source)
	var state: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile.path_join("campaign.json")))
	if state.get("completed") != ["specimen","archive","reactor"]:quit(2);return
	root.size = Vector2i(1280,720)
	root.unfocusable = true
	world = load("res://scenes/native_journey.tscn").instantiate()
	world.native_checkpoint_path = profile.path_join("opening.json")
	world.native_preferences_path = profile.path_join("preferences.cfg")
	world.get_node("SystemJourneyPreview").checkpoint_path = profile.path_join("maintenance.json")
	world.get_node("NativeJourneyController").checkpoint_path = profile.path_join("route.json")
	world.get_node("NativeCampaignController").checkpoint_path = profile.path_join("campaign.json")
	root.add_child(world)
	for i in 45:
		if paused and world.native_pause_menu:world.native_pause_menu.resume_button.pressed.emit()
		await physics_frame
		await process_frame
	player = world.player
	var campaign = world.get_node("NativeCampaignController")
	room = campaign.rooms[3]
	if args.has("--decon-tripo-candidate") or args.has("--review-default-decon"):
		_record("generated_candidate_actually_installed",room.has_node("DeconTripoArchitecture/ClinicalInstrumentDetail"))
	if args.has("--decon-whole-v2-candidate") or args.has("--review-default-decon"):
		_record("whole_v2_measured_candidate_installed",room.get_node("DeconTripoArchitecture").get_meta("source_revision","")=="whole-v2-refined-20261029")
	world.set_visual_quality("high")
	world.set_reduced_motion(false)
	world.set_audio_muted(true)
	var dialogue = world.hud.find_child("DialogueOverlay",true,false)
	for i in 8:
		if dialogue.is_active:dialogue.continue_button.pressed.emit()
		await process_frame
	_record("actual_earned_decon_restore",campaign.current == 3 and campaign.progress.completed == state.completed and not room.override_done and not room.gate_open)
	_record("safe_grounded_player_camera",player.is_on_floor() and root.get_camera_3d() == player.player_camera and not player.control_locked,str(_pos()))
	var reached := await _go_to(Vector3(0,.1,-2))
	_record("entry_reached_by_input",reached,str(_pos()))
	_aim(Vector3(0,2,-15))
	await _frames(20)
	var pulse_samples := []
	var progress_before: Dictionary = campaign.progress.duplicate(true)
	for frame in 36:
		if _pos().z> -9:_steer(Vector3(0,.1,-9.5),false,1.0)
		else:player.set_mobile_input_vector(Vector2.ZERO,true)
		await _frames(6)
		if DisplayServer.get_name()!="headless":await _capture("uv-%03d"%frame)
		pulse_samples.append({"frame":frame,"uv_time":room._uv_timer,"energy":room._uv_pulse_light.light_energy,"position":str(_pos()),"camera":str(player.player_camera.global_transform)})
	player.set_mobile_input_vector(Vector2.ZERO,true)
	await _frames(10)
	_record("public_walk_crossed_arches",player.is_on_floor() and _pos().z < -6.5,str(_pos()))
	_record("presentation_did_not_complete_quarantine",campaign.progress.completed == progress_before.completed and not room.override_done and not room.gate_open and not player.combat_available)
	var low := 10.0
	var high := 0.0
	for row in pulse_samples:low = minf(low,row.energy);high = maxf(high,row.energy)
	_record("complete_actual_light_cycle_sampled",pulse_samples.back().uv_time-pulse_samples.front().uv_time>PI and high-low>.3,{"minimum":low,"maximum":high})
	world.set_reduced_motion(true)
	await _frames(2)
	var stopped: float = room._uv_timer
	await _frames(15)
	_record("reduced_motion_freezes_uv_phase",is_equal_approx(room._uv_timer,stopped))
	if args.has("--complete-quarantine"):
		world.set_reduced_motion(false)
		var walked:=true
		if args.has("--decon-tripo-candidate") or args.has("--review-default-decon"):
			var reached_outside:=await _walk_decon_leg(Vector3(-11,0,-8.5))
			var ray:=PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP,room.to_global(Vector3(-11,1,-8.5)))
			var wall:Dictionary=room.get_world_3d().direct_space_state.intersect_ray(ray)
			_record("generated_wall_blocks_actual_player",not reached_outside and _pos().x> -10.05 and wall.get("collider")!=null and String(wall.collider.name)=="GeneratedWallWest",str(_pos()))
		for point in [Vector3(-8.5,0,-8.5),Vector3(-8.5,0,-9),Vector3(-8.5,3.2,-15.5),Vector3(-2,3.2,-16)]:
			if not await _walk_decon_leg(point):walked=false;break
		_record("public_input_reached_catwalk_terminal",walked and player.get_nearest_interactable()==room._terminal_body,str(_pos()))
		var used:Dictionary=player.interact_with_nearest() if walked else {}
		_record("actual_override_interaction_succeeded",used.get("success",false) and used.get("cleared",false),used)
		await _frames(65)
		_record("override_opened_physical_gate",room.override_done and room.gate_open and room._gate_shape.disabled)
		for point in [Vector3(-8.5,3.2,-16),Vector3(-8.5,0,-9),Vector3(0,0,-9),Vector3(0,0,-32.8)]:
			if not await _walk_decon_leg(point):walked=false;break
		_record("public_input_exit_advanced_saved_campaign",walked and campaign.current==4 and campaign.progress.completed==["specimen","archive","reactor","decon"] and not player.combat_available,str(_pos()))
	report.scope = "Actual earned after-reactor restore and public player walk through current UV presentation;muted visual review;UV is currently a light pulse,not a timed damaging hazard"
	if args.has("--complete-quarantine"):report.scope+=";public-input stair ascent,actual terminal interaction,gate opening,descent and saved exit to mirror conduit"
	report.source_earned = earned
	report.source_earned_hashes = source_hashes
	report.room_source_sha256 = FileAccess.get_sha256("res://scripts/environment/decontamination_quarantine_wing.gd")
	if args.has("--decon-whole-v2-candidate") or args.has("--review-default-decon"):
		report.candidate_source_hashes={}
		for p in preload("res://scripts/environment/decon_precision_refinement.gd").evidence_paths():
			report.candidate_source_hashes[p]=FileAccess.get_sha256(p)
		for p in ["res://scripts/environment/decon_whole_v2_architecture.gd","res://assets/environments/decon_clinical/decon_whole_v2_static.glb","res://assets/environments/decon_clinical/decon_whole_v2_gate.glb","res://assets/environments/decon_clinical/decon_whole_v2_terminal.glb","res://assets/environments/decon_clinical/decon_whole_v2_basecolor.png","res://assets/environments/decon_clinical/decon_whole_v2_normal.png","res://assets/environments/decon_clinical/decon_whole_v2_orm.png"]:
			report.candidate_source_hashes[p]=FileAccess.get_sha256(p)
	report.pulse_samples = pulse_samples
	report.renderer = RenderingServer.get_current_rendering_method()
	report.device = RenderingServer.get_video_adapter_name()
	report.status = "PASS_FUNCTIONAL_VISUAL_REVIEW_PENDING" if report.checks.all(func(row: Dictionary):return row.pass) else "FAIL"
	var file := FileAccess.open(evidence.path_join("review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	world.queue_free()
	for i in 6:await process_frame
	quit(0 if report.status != "FAIL" else 1)

