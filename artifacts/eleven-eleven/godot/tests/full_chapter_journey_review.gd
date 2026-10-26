extends "res://tests/opening_player_journey_review.gd"

## One fresh local save and the same live scene from awakening through the ward.
## Inputs use existing inspection/puzzle controls and the public movement API.
## No room fixtures, checkpoint grants or position writes in this driver.
## This proves local connectivity, not the server cover handoff or actor quality.
var campaign: Node
var room: Node3D
var review_kind := "full-chapter"
var shot := 0
var focus_interruptions := 0
var _last_room: Node3D
var _room_trace: Array = []
var _route_retries := 0
var _mystery_records: Array = []

func _continue_review() -> bool:
	campaign = main.get_node("NativeCampaignController")
	await _frames(8)
	if not _check(campaign.active and campaign.current == 0 and campaign.progress.completed.is_empty(), "Fresh security exit failed to activate the first campaign room"): return false
	var personal_window:Node=main.hud.find_child("SystemWindow",true,false)
	main.toggle_personal_system()
	await _frames(8)
	if not _check(personal_window._status_view and not personal_window._status_snapshot.pact_confirmed and not player.combat_available,"Pre-pact personal status invented a pact or power"):return false
	await _capture("personal-status-pre-pact")
	main.toggle_personal_system()
	await _frames(8)
	player.set_gameplay_orbit(Vector3.ZERO)
	for wing in campaign.rooms:
		if wing.has_signal("retry_requested"): wing.retry_requested.connect(_observe_retry.bind(wing))
		if wing.has_signal("hazard_triggered"): wing.hazard_triggered.connect(func(id: String): print("ACTUAL_ROUTE_HAZARD ",id," position=",player.global_position))
	room=campaign.conduits[0]
	if not await _walk_local(Vector3(0,0,-14.8)): return false
	room=campaign.rooms[0]
	# Cover route follows the authored scanner's occluding plinths.
	for point in [Vector3(-2.5,0,2),Vector3(-2.5,0,3),Vector3(-13,0,3)]:
		if not await _walk_local(point): return false
	if not await _specimen_sweep_window(false): return false
	if not await _walk_local(Vector3(-24.65,0,-6)): return false
	if not await _specimen_sweep_window(true): return false
	if not await _walk_local(Vector3(-26,0,-10.4)): return false
	if not _check(player.get_nearest_interactable()==room,"Specimen terminal must be physically available"): return false
	if not _check(player.interact_with_nearest().get("accepted",false),"Specimen record rejected"): return false
	# The terminal is deliberately non-modal and surveillance stays live.
	# Move toward cover while the gate opens instead of waiting in its beam.
	await _frames(2)
	if not _check(campaign.current==0,"Opening a gate must not complete traversal"): return false
	for point in [Vector3(-28,0,-10.4),Vector3(-28,0,-12),Vector3(-30.8,0,-12)]:
		if not await _walk_local(point): return false
	if not _check(campaign.current==1,"Physical specimen threshold did not advance"): return false
	if not await _record_mystery_room("specimen"): return false
	room=campaign.conduits[1]
	if not await _walk_local(Vector3(-13.8,0,0)): return false
	room=campaign.rooms[1]
	for point in [Vector3(-1.7,0,-3.2),Vector3(-6,0,-3.2),Vector3(-6,0,4.1),Vector3(-6,0,2.5),Vector3(-16,0,2.5),Vector3(-16,0,-4.1),Vector3(-20,0,-3),Vector3(-20,0,9),Vector3(-3.8,0,9),Vector3(-3.8,3.6,0.5),Vector3(-11,3.6,0),Vector3(-3.8,3.6,0.5),Vector3(-3.8,0,9),Vector3(-1.7,0,9),Vector3(-1.7,0,-3.2),Vector3(-9.5,0,-3.2)]:
		if not await _walk_local(point): return false
	if not _check(player.get_nearest_interactable()==room,"Archive terminal must be physically available"): return false
	if not _check(player.interact_with_nearest().get("success",false),"Archive decode rejected"): return false
	for i in 55: await physics_frame
	for point in [Vector3(-1.7,0,-3.2),Vector3(-1.7,0,-12),Vector3(-11,0,-12),Vector3(-11,0,-14.8)]:
		if not await _walk_local(point): return false
	if not _check(campaign.current==2,"Physical archive threshold did not advance"): return false
	if not await _record_mystery_room("archive"): return false
	room=campaign.conduits[2]
	if not await _walk_local(Vector3(0,0,-14.8)): return false
	room=campaign.rooms[2]
	for point in [Vector3(0,-4,-5.5),Vector3(0,-4,-7),Vector3(-3,-3.45,-8.42)]:
		if not await _walk_local(point): return false
	await _safe_hazard(false)
	for point in [Vector3(-9.2,-2,-11),Vector3(-11,-2,-12.3),Vector3(-11,-2,-16)]:
		if not await _walk_local(point): return false
	if not _use_local("BreakerAConsole"): return false
	for point in [Vector3(-11,-2,-14.8),Vector3(-8.5,-2,-14.8)]:
		if not await _walk_local(point): return false
	await _safe_hazard(false)
	for point in [Vector3(0,-2,-14.8),Vector3(11,-2,-14.8),Vector3(11,-2,-17.5)]:
		if not await _walk_local(point): return false
	await _safe_hazard(true)
	for point in [Vector3(11,-2,-24.2),Vector3(11,-2,-28)]:
		if not await _walk_local(point): return false
	if not _use_local("BreakerBConsole"): return false
	for i in 65: await physics_frame
	for point in [Vector3(11,-2,-30.1),Vector3(11,0.2,-35.8),Vector3(0,0.2,-35.8),Vector3(0,0,-40),Vector3(0,0,-44.8)]:
		if not await _walk_local(point): return false
	if not _check(campaign.current==3,"Physical reactor threshold did not advance"): return false
	if not await _record_mystery_room("reactor"): return false
	room=campaign.conduits[3]
	if not await _walk_local(Vector3(0,0,-15.8)): return false
	room=campaign.rooms[3]
	if OS.get_cmdline_user_args().has("--uv-route"):
		if not await _walk_local(Vector3(0,0,-8.5)): return false
		if not _check(player.is_on_floor() and not room.override_done and not room.gate_open and not player.combat_available,"UV passage changed gate/override/ground/pre-pact authority"): return false
		print("PASS current public-input passage through both UV arches")
		if not await _walk_local(Vector3(-8.5,0,-8.5)): return false
		if not await _walk_local(Vector3(-8.5,0,-2)): return false
	for point in [Vector3(-8.5,0,-2),Vector3(-8.5,0,-9),Vector3(-8.5,3.2,-15.5),Vector3(-2,3.2,-16)]:
		if not await _walk_local(point): return false
	if not _use_local("QuarantineOverrideTerminal"): return false
	if not _check(player.get_nearest_interactable()!=room._terminal_body,"Completed quarantine terminal retained its interaction prompt"): return false
	for i in 55: await physics_frame
	for point in [Vector3(-8.5,3.2,-16),Vector3(-8.5,0,-9),Vector3(0,0,-9),Vector3(0,0,-32.8)]:
		if not await _walk_local(point): return false
	if not _check(campaign.current==4,"Physical quarantine threshold did not advance"): return false
	if not await _record_mystery_room("decon"): return false
	room=campaign.conduits[4]
	if not await _walk_local(Vector3(0,0,-15.8)): return false
	room=campaign.rooms[4]
	for point in [Vector3(7.2,0,-2),Vector3(7.2,0,-10)]:
		if not await _walk_local(point): return false
	if not _check(room.mirror_inspected and not room.override_done, "Physical mirror inspection must be separate from the lockdown override"): return false
	player.set_gameplay_orbit(Vector3(0, -PI * .5, 0))
	await _frames(6)
	await _capture("mirror-actual-inspection")
	player.set_gameplay_orbit(Vector3.ZERO)
	for point in [Vector3(7.2,0,-14),Vector3(8,0,-14),Vector3(8,0,-16.6),Vector3(3.5,2.4,-16.6),Vector3(1.5,2.4,-18)]:
		if not await _walk_local(point): return false
	if not _use_local("MasterSecurityTerminal"): return false
	for i in 55: await physics_frame
	for point in [Vector3(3.5,2.4,-16.6),Vector3(8,0,-16.6),Vector3(9,0,-20),Vector3(9,0,-30),Vector3(0,0,-30),Vector3(0,0,-36.8)]:
		if not await _walk_local(point): return false
	if not _check(campaign.current==5,"Physical surveillance threshold did not advance"): return false
	if not await _record_mystery_room("mirror"): return false
	if OS.get_cmdline_user_args().has("--mystery-only"):
		if not _check(campaign.progress.completed == ["specimen", "archive", "reactor", "decon", "mirror"] and _route_retries == 0 and not player.contract_with_zero_sealed and not player.combat_available, "Mystery slice bypassed progression, retried or granted an early power"): return false
		print("MYSTERY_STAGE08 PASS: five distinct rooms, earned checkpoint after each, actual public-input thresholds, no pact/lab execution")
		return true
	room=campaign.conduits[5]
	if not await _walk_local(Vector3(0,0,-15.8)): return false
	room=campaign.rooms[5]
	if not _check(not player.combat_available and not room.contract_done,"Early power authority before explicit pact"): return false
	if not _check(is_instance_valid(campaign.kinja) and campaign.kinja.get_parent()==room and not campaign.kinja.active,"Kinja must already be present in the laboratory before the pact"): return false
	campaign.kinja.take_damage(50,player.global_position)
	if not _check(campaign.kinja.contacts==0,"Pre-pact presence must not enable damage or advance revenge"): return false
	for point in [Vector3(0,0,-9),Vector3(0,1.2,-14),Vector3(2.5,1.2,-14),Vector3(2.5,1.2,-18.4)]:
		if not await _walk_local(point): return false
	if not _use_local("KinjaNeuralRigTerminal"): return false
	if not _snapshot_profile("before-trial"): return false
	if not _check(await preload("res://tests/lab_memory_trial_input.gd").play(self,main,room,_walk_local,_capture),"Connected father/memories/refusal/resistance segment failed"): return false
	if not _snapshot_profile("manifested"): return false
	for i in 100: await physics_frame
	if not _check(room.confrontation_done and not room.contract_done and not room.breach_open,"Memory presentation auto-accepted the pact or escape"): return false
	print("PASS connected actual native route: security exit, six separate rooms, five buffers, physical gates, reachable shards/breakers/terminals, no teleport after fixture spawn, no automatic pact or premature power")
	if not await _complete_campaign(): return false
	if not _snapshot_profile("complete"): return false
	if not _check(_route_retries == 0,"Full critical path required a recovery relocation"): return false
	var expected_notice_ids:=["chapter:specimen:record:1","chapter:archive:fragments:3","chapter:lab:pact:1","chapter:hospital:mark:1"]
	if not _check(expected_notice_ids.all(func(id:String):return personal_window._seen_notice_ids.has(id)),"Actual committed route did not emit its story notices"):return false
	var hashes := {}
	for path in ["res://scripts/systems/native_journey_controller.gd","res://scripts/systems/native_campaign_controller.gd","res://scripts/systems/native_campaign_checkpoint.gd","res://scripts/environment/dr_kinja_lab_room.gd","res://scripts/environment/kinja_rig_terminal.gd","res://scripts/cinematics/lab_memory_trial.gd","res://scripts/cinematics/pact_revenge_presentation.gd","res://scripts/characters/kinja_revenge_actor.gd","res://assets/characters/echo_v31_adopted_high.glb","res://assets/textures/lab-memory/yuki-pdf041.webp","res://assets/textures/lab-memory/shizuka-pdf041.webp","res://shaders/lab_memory_abyss.gdshader","res://tests/full_chapter_journey_review.gd","res://tests/opening_player_journey_review.gd","res://tests/lab_memory_trial_input.gd"]:
		hashes[path] = FileAccess.get_sha256(path)
	for path in ["res://scripts/ui/opening_memory_film.gd", "res://scripts/environment/memory_reflection_space.gd", "res://shaders/memory_water.gdshader", "res://assets/props/memory_stasis_frame_clean_v1.glb", "res://assets/cinematics/lab-memory-collapse-v1.ogv", "res://assets/cinematics/lab-memory-water-v1.ogg", "res://assets/cinematics/lab-memory-bottom-v1.webp"]:
		hashes[path] = FileAccess.get_sha256(path)
	for path in ["res://scripts/environment/clinical_lab_architecture.gd","res://engine_visuals/HyperAnimeWorldManager.gd","res://scripts/player/echo_skin_identifier.gd","res://shaders/clinical_architecture_surface.gdshader","res://shaders/clinical_porcelain_floor.gdshader","res://assets/environments/lab_clinical_cp45/clinical_wall_p2_4k.glb","res://assets/environments/lab_clinical_cp45/clinical_service_frame_clean.glb","res://scripts/environment/clinical_modular_perimeter.gd","res://assets/environments/lab_clinical_cp45/clinical_scanner_p2_4k.glb","res://assets/characters/echo_v31_short_jacket.glb"]:
		hashes[path]=FileAccess.get_sha256(path)
	var report := FileAccess.open(folder+"full-chapter.json",FileAccess.WRITE)
	for file in DirAccess.get_files_at("res://assets/characters"):
		if file.begins_with("zero_manifestation_idle_v1_") and file.ends_with(".import"):
			hashes["assets/characters/"+file]=FileAccess.get_sha256("res://assets/characters/"+file)
	for path in ["res://scripts/environment/hospital_bedside_room.gd","res://scripts/environment/hospital_room_dressing.gd","res://scripts/environment/planar_inspection_mirror.gd","res://shaders/ward_floor.gdshader","res://assets/props/ward_bed_original_v1.glb","res://assets/props/ward_visitor_chair_v1.glb","res://assets/props/ward_vanity_v1.glb"]:
		hashes[path] = FileAccess.get_sha256(path)
	for path in ["res://scripts/main.gd","res://scripts/ui/system_window.gd","res://scripts/ui/system_signal_glass.gd","res://scripts/ui/gameplay_hud.gd","res://scripts/ui/native_pause_menu.gd"]:
		hashes[path]=FileAccess.get_sha256(path)
	report.store_string(JSON.stringify({"scope":"Fresh local save, one live scene, public virtual movement and real puzzle/inspection/decision controls; no server cover receipt and no human playtest","display":DisplayServer.get_name(),"language":main.presentation_language,"checks":checks,"route_retries":_route_retries,"room_trace":_room_trace,"final_progress":campaign.progress,"source_hashes":hashes,"local_story_notice_ids":personal_window._seen_notice_ids.keys(),"actor_art":"OPEN","physical_devices":"UNVERIFIED","audio_listening":"UNVERIFIED"},"\t"))
	report.close()
	return true

func _complete_campaign() -> bool:
	var window=main.hud.find_child("SystemWindow",true,false)
	if not await preload("res://tests/zero_encounter_route_input.gd").play(self,main,room,_capture):return false
	if not _check(room.contract_done and player.combat_available and not room.wish_done,"Explicit pact did not unlock the controlled confrontation"): return false
	for point in [Vector3(3,0,-35),Vector3(3,0,-28.8),Vector3(0,0,-28.8)]:
		if not await _walk_local(point): return false
	for contact in 3:
		player.face_world_direction(campaign.kinja.global_position-player.global_position)
		player.perform_attack()
		if not await preload("res://tests/zero_encounter_route_input.gd").wait_melee_recovery(self,player,_capture.bind("native-melee-%d"%contact)):return false
		if not _check(campaign.kinja.contacts==contact+1,"Actual melee did not contact Kinja exactly once"): return false
	if not _check(not room.revenge_done and not room.wish_done,"Three attacks cannot automatically finish revenge or accept the wish"): return false
	var approach:Vector3=room.to_local(campaign.kinja.global_position)+Vector3.FORWARD*1.5
	approach.y=0.0
	if not await _walk_local(approach): return false
	if not _check(player.get_nearest_interactable()==campaign.kinja,"Kinja must be physically reachable after approach; player="+str(room.to_local(player.global_position))+" actor="+str(room.to_local(campaign.kinja.global_position))+" nearby="+str(player.nearby_interactables)): return false
	if not _check(player.interact_with_nearest().get("collar_requested",false),"Confrontation interaction rejected"): return false
	if not _check(window.visible and window.stats_box.get_child_count()==1,"Confrontation must require explicit continuation"): return false
	window.stats_box.get_child(0).pressed.emit()
	# The tracker is updated in _process. Several catch-up physics ticks can
	# occur before a single rendered/process frame on a loaded workstation.
	for i in 5:
		await process_frame
		_resume()
		await physics_frame
	if not _check(room.revenge_done and not room.wish_done and not room.breach_open,"Revenge auto-accepted the wish"): return false
	if not _check(main.hud.current_directive_desc.contains("أمنيتك") or main.hud.current_directive_desc.contains("wish to leave"),"Completed confrontation tracker: "+main.hud.current_directive_desc): return false
	window.stats_box.get_child(0).pressed.emit()
	for i in 15: await physics_frame
	if not _check(room.wish_done and room.breach_open and campaign.hospital==null,"Accepted wish must open a physical breach before transfer"): return false
	if not _snapshot_profile("wish"): return false
	var film:bool=OS.get_cmdline_user_args().has("--film") and DisplayServer.get_name()!="headless"
	if film: main.set_reduced_motion(false)
	for point in [Vector3(3,0,-28.8),Vector3(3,0,-35),Vector3(0,0,-35),Vector3(0,0,-39.0)]:
		if not await _walk_local(point): return false
	player.set_mobile_input_vector(Vector2(0,-1),true)
	for i in 35: await physics_frame
	player.set_mobile_input_vector(Vector2.ZERO,false)
	if not _check(campaign.hospital!=null and campaign.progress.completed.size()==6,"Physical breach did not transfer to the ward"): return false
	if not _check(player.control_locked and not player.combat_available,"Hospital awakening must own input and remove combat"): return false
	if not _check(not main.companion.visible and main.companion.follow_target==null and main.companion.process_mode==Node.PROCESS_MODE_DISABLED,"Facility guide followed or scanned inside the real ward"): return false
	var touch: Node=main.hud.find_child("MobileTouchControls",true,false)
	if not _check(not touch.scan_tapped.is_connected(main.companion.trigger_scan) and not touch.get_node("ActionCluster/ScanBtn").visible,"Ward retained its facility scan action"): return false
	for weapon in ["KatanaBlade","ShadowKatana"]:
		if not _check(not player.find_child(weapon,true,false).visible,"Hospital retained an active blade: "+weapon): return false
	if player._hip_weapon_mesh and not _check(not player._hip_weapon_mesh.visible,"Hospital retained its sheathed blade mesh"): return false
	if film:
		if not _check(campaign._movie!=null,"Actual ward transfer did not play its native film"): return false
		for i in 60: await physics_frame
		var film_player=campaign._movie.get_node("FilmFrame/AwakeningFilm")
		var film_size:Vector2=film_player.size
		if not _check(absf(film_size.x/film_size.y-864.0/496.0)<0.002,"Film must retain its authored aspect ratio"): return false
		await _campaign_capture()
		# Exercise the real skip button, then the finished/skip race.
		campaign._movie.get_child(campaign._movie.get_child_count()-1).pressed.emit()
		var generation:int=window._window_generation
		campaign._finish_hospital_movie()
		if not _check(window._window_generation==generation,"Duplicate film completion replaced the explicit wake decision"): return false
	window.stats_box.get_child(0).pressed.emit()
	for i in 15: await physics_frame
	room=campaign.hospital
	if not _check(room.bed_awakened_done and not player.control_locked,"Explicit awakening must release bedside exploration"): return false
	for point in [Vector3(1.6,0,1.18),Vector3(1.6,0,-1.0)]:
		if not await _walk_local(point): return false
	if not _use_local("VanityMirrorStation"): return false
	for i in 10: await physics_frame
	if not _check(room.mark_revealed_done and campaign.progress.completed.size()==7,"Physical mirror interaction did not persist the final chapter event"): return false
	if not _check(room.chapter_completed_done and (main.hud.current_directive_desc.contains("اكتمل هذا الفصل") or main.hud.current_directive_desc.contains("chapter is complete")),"Confirmed ward mirror left the completed chapter asking for another inspection"): return false
	if not _check(campaign._mark_inspection!=null and player.control_locked,"Skin inspection must own camera and input until explicit dismissal"): return false
	await _campaign_capture()
	window.close_window()
	for i in 3: await physics_frame
	if not _check(not player.control_locked and player.player_camera.current,"Inspection dismissal must restore the actual exploration camera and input"): return false
	print("PASS functional pact, controlled melee, explicit revenge continuation, sole Canon wish, physical breach, hospital input ownership and actual mirror interaction; skeletal staging acceptance remains OPEN")
	print("CAPTURE scope: virtual public input, rendered actual runtime; focus interruptions resumed via actual Pause UI=",focus_interruptions)
	return true

func _walk_local(point: Vector3) -> bool:
	var reached := await _walk(room.to_global(point))
	if reached and room != _last_room:
		_last_room = room
		_room_trace.append({"room":room.name,"position":str(player.global_position),"completed":campaign.progress.completed.duplicate(),"pre_pact":not player.contract_with_zero_sealed})
		await _capture("entry-"+room.name)
	if not room == campaign.hospital and campaign.current < 5:
		if not _check(not player.combat_available and not player.contract_with_zero_sealed and not player.shadow_step_unlocked,"A pre-pact room granted supernatural authority"): return false
	return reached

func _observe_retry(anchor: Vector3, wing: Node3D) -> void:
	_route_retries += 1
	print("ACTUAL_ROUTE_RETRY room=",wing.name," anchor=",anchor," phase=",wing.get("hazard_phase_timer")," position=",wing.to_local(player.global_position)," count=",_route_retries)

func _record_mystery_room(id: String) -> bool:
	if not OS.get_cmdline_user_args().has("--mystery-only"): return true
	if not _snapshot_profile("after-" + id): return false
	await _capture("mystery-after-" + id)
	_mystery_records.append({"room": id, "completed": campaign.progress.completed.duplicate(), "position": player.global_position, "earned_snapshot": "earned/after-" + id})
	var source_hashes := {}
	for stem in campaign.FILES:
		for path in ["scenes/environment/" + stem + ".tscn", "scripts/environment/" + stem + ".gd"]: source_hashes[path] = FileAccess.get_sha256("res://" + path)
	for path in ["scripts/systems/native_campaign_controller.gd", "scripts/systems/native_campaign_checkpoint.gd", "tests/full_chapter_journey_review.gd"]: source_hashes[path] = FileAccess.get_sha256("res://" + path)
	var file := FileAccess.open(folder + "mystery-rooms.json", FileAccess.WRITE)
	var status := "IN_PROGRESS" if id != "mirror" else ("PASS_FUNCTIONAL_STAGE08" if _route_retries == 0 else "FAIL_ROUTE_RETRY")
	file.store_string(JSON.stringify({"scope": "Stage08 physical mystery rooms only; final chapter/fun/art/device approval separate", "status": status, "records": _mystery_records, "checks": checks, "retries": _route_retries, "pact_confirmed": player.contract_with_zero_sealed, "source_hashes": source_hashes}, "\t"))
	file.close()
	print("MYSTERY_ROOM_VERIFIED ", id, " earned checkpoints=", _mystery_records.size())
	return true

func _snapshot_profile(label: String) -> bool:
	if not _check(main.save_native_checkpoint_now(),"Cannot flush the earned "+label+" checkpoint"): return false
	var snapshot_dir := folder+"earned/"+label+"/"
	DirAccess.make_dir_recursive_absolute(snapshot_dir)
	var paths := {"opening.json":main.native_checkpoint_path,"maintenance.json":main.get_node("SystemJourneyPreview").checkpoint_path,"route.json":main.get_node("NativeJourneyController").checkpoint_path,"campaign.json":campaign.checkpoint_path,"preferences.cfg":main.native_preferences_path}
	for file: String in paths:
		if FileAccess.file_exists(paths[file]):
			if not _check(DirAccess.copy_absolute(paths[file],snapshot_dir+file)==OK,"Failed to preserve earned save: "+file): return false
	return true

func _use_local(id: String) -> bool:
	if not _check(player.get_nearest_interactable() == room.get_node(id), "Physical interaction missing: "+id): return false
	var result := player.interact_with_nearest()
	return _check(result.get("success",result.get("accepted",false)), "Physical interaction rejected: "+id)

func _campaign_capture() -> void:
	await _capture("chapter-%03d" % shot)
	shot += 1

func _safe_hazard(second: bool) -> void:
	for i in 300:
		_resume()
		var phase: float = fmod(room.hazard_phase_timer + (room.CYCLE_TIME * .5 if second else 0.0), room.CYCLE_TIME)
		if phase > room.TELEGRAPH_TIME + room.DISCHARGE_TIME + .08 and phase < room.TELEGRAPH_TIME + room.DISCHARGE_TIME + .3: return
		await physics_frame

func _specimen_sweep_window(toward_north: bool) -> bool:
	# Wait behind the actual tank/plinth, then move on the visible opposite sweep.
	# This reads the detector clock; it never freezes or alters surveillance.
	var begin := .6 if toward_north else 1.1
	for i in 380:
		_resume()
		var angle: float = fposmod(room._scanner_sweep_angle,TAU)
		if angle > begin and angle < begin + .06: return true
		await physics_frame
	return _check(false, "No live specimen sweep window within one complete cycle")
