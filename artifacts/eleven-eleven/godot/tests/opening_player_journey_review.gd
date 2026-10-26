extends SceneTree

## Current Room 01: rendered four-view audit and actual public-input traversal.
var main: Node3D
var player: EchoPlayer
var folder: String
var checks := 0
var record_effects := false
var record_profile := false
var profile_phases := {}
const REVIEW_SAVES = ["user://room01_journey_review.json", "user://room01_journey_review.cfg", "user://room01_maintenance_review.json", "user://room01_route_review.json", "user://room01_campaign_review.json"]

func _clear_fixture_saves() -> void:
	for path in REVIEW_SAVES:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)

func _initialize() -> void: _run.call_deferred()

func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		push_error(message)
		quit(1)
	return ok

func _resume() -> void:
	if paused: main.native_pause_menu.resume_button.pressed.emit()

func _frames(count: int) -> void:
	for frame in count:
		_resume()
		await process_frame
		await physics_frame

func _drain_dialogue() -> void:
	var dialogue = main.hud.find_child("DialogueOverlay", true, false)
	while dialogue.is_active: dialogue.advance_dialogue()

func _capture(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder + id + ".png")

func _walk(target: Vector3) -> bool:
	print("ROOM01_WALK ", target)
	for frame in 900:
		_resume()
		if main._boundary_memory_pending:
			await _capture("boundary-memory")
			_drain_dialogue()
		var offset := target - player.global_position
		offset.y = 0
		if offset.length() < 0.22:
			player.set_mobile_input_vector(Vector2.ZERO, false)
			await _frames(8)
			if not player.is_on_floor(): await _capture("lost-ground-" + str(checks))
			return _check(player.is_on_floor(), "Lost ground support at " + str(target) + " position=" + str(player.global_position) + " velocity=" + str(player.velocity) + " climbing=" + str(player.traversal.is_climbing()) + " hanging=" + str(player.surface_motor.hanging))
		var forward := -player.player_camera.global_basis.z
		var right := player.player_camera.global_basis.x
		forward.y = 0
		right.y = 0
		var stick := Vector2(offset.dot(right.normalized()), -offset.dot(forward.normalized())).normalized()
		player.set_mobile_input_vector(stick * (1.0 if offset.length() > 1.0 else 0.65), true)
		await physics_frame
	return _check(false, "Blocked actual input route: " + str(target) + " at " + str(player.global_position))

func _use_evidence(id: String) -> bool:
	var evidence := main.find_child(id, true, false) as Node3D
	var approach := Vector3(1.0, 0, 0) if id == "OpeningClock" else Vector3(0, 0, 0.9)
	if not await _walk(evidence.global_position + approach): return false
	await _frames(4)
	if not _check(player.get_nearest_interactable() == evidence.get_node("InteractionArea"), "World inspection not available: " + id): return false
	player.interact_with_nearest()
	if main.opening_inspection and main.opening_inspection.is_active:
		var inspector = main.opening_inspection
		if not _check(not evidence.inspected, "Opening an inspection granted evidence before confirmation"): return false
		if id == "OpeningClock":
			inspector.cancel_button.pressed.emit()
			if not _check(not evidence.inspected and player.player_camera.current and not player.control_locked,"Cancelled inspection changed progress or failed to return the camera"): return false
			player.interact_with_nearest()
			if not _check(inspector.is_active,"Clue could not be reopened after cancellation"): return false
		inspector.left_button.pressed.emit()
		inspector.near_button.pressed.emit()
		await _frames(2)
		var screen: Rect2 = main.get_viewport().get_visible_rect()
		await _capture("inspection-"+evidence.evidence_id)
		if record_profile and id=="OpeningClock": await _sample_profile("room01-inspection")
		print("INSPECTION_LAYOUT ",screen," panel=",inspector.panel.get_global_rect())
		for button in [inspector.left_button,inspector.right_button,inspector.near_button,inspector.far_button,inspector.cancel_button,inspector.confirm_button]:
			print("INSPECTION_BUTTON ",button.text," ",button.get_global_rect())
			if not _check(screen.encloses(button.get_global_rect()),"Inspection control clipped outside the viewport: "+button.text): return false
		main.native_pause_menu.visible = false
		inspector.panel.hide()
		await _capture("inspection-reference-"+evidence.evidence_id)
		inspector.panel.show()
		main.native_pause_menu.visible = true
		inspector.confirm_button.pressed.emit()
		if not _check(not inspector.is_active and evidence.inspected and player.player_camera.current,"Confirmed clue did not commit once and return its camera"): return false
	_drain_dialogue()
	if record_effects and id == "OpeningClock":
		for frame in 24:
			await _frames(1)
			await _capture("discovery-%03d" % frame)
	return true

func _run() -> void:
	_clear_fixture_saves()
	root.unfocusable = true
	root.size = Vector2i(1280, 720)
	var args := OS.get_cmdline_user_args()
	if args.has("--compact"): root.size = Vector2i(960,540)
	var standard := args.has("--standard")
	record_effects = args.has("--effects") and DisplayServer.get_name() != "headless"
	record_profile = args.has("--profile") and DisplayServer.get_name() != "headless"
	var version := args[0] if not args.is_empty() else "baseline"
	folder = ProjectSettings.globalize_path("res://../audits/evidence/"+("room01-20261014" if args.has("--review-20261014") else "room01-20261012")+"/" + version + "/")
	if args.has("--full-chapter"):
		folder = ProjectSettings.globalize_path("res://../audits/evidence/pre-tripo-20261018/cp37/route/"+version+"/")
	if args.has("--mystery-only"):
		folder = ProjectSettings.globalize_path("res://../audits/evidence/chapter-cp45-20261020/stage08/route/" + version + "/")
	DirAccess.make_dir_recursive_absolute(folder)
	main = load("res://scenes/native_journey.tscn").instantiate()
	print("ROOM01_LOADED")
	main.native_checkpoint_path = "user://room01_journey_review.json"
	main.native_preferences_path = "user://room01_journey_review.cfg"
	main.get_node("SystemJourneyPreview").checkpoint_path = "user://room01_maintenance_review.json"
	main.get_node("NativeJourneyController").checkpoint_path = "user://room01_route_review.json"
	main.get_node("NativeCampaignController").checkpoint_path = "user://room01_campaign_review.json"
	root.add_child(main)
	# Explicit fixture tier for repeatable native device evidence. All writes
	# still target this driver's dedicated review preferences, never the owner.
	for argument in args:
		if argument.begins_with("--quality="):
			var tier:=argument.trim_prefix("--quality=")
			if not _check(tier in ["low","medium","high","ultra"],"Unsupported native journey review tier"):return
			main.set_visual_quality(tier)
	if args.has("--en"): main.set_presentation_language("en")
	print("ROOM01_READY")
	player = main.player
	# This virtual-input fixture owns its orbit; desktop pointer motion must not
	# contaminate the recorded effect sequence. Product input remains unchanged.
	player.set_process_unhandled_input(false)
	main.set_audio_muted(true)
	for frame in 90:
		_resume()
		await physics_frame
	await _capture("00-arrival")
	print("ROOM01_ARRIVAL")
	player.finish_opening_recovery()
	_drain_dialogue()
	await _frames(10)
	if not _check(player.find_child("ReviewedHighSource", true, false) != null, "Current V31 missing"): return
	var camera := Camera3D.new()
	camera.fov = 65
	main.add_child(camera)
	camera.make_current()
	if args.has("--references"):
		main.hud.visible = false
		main.native_pause_menu.visible = false
		player.visible = false
	var views := [
		[Vector3(0, 2.4, 6.3), Vector3(0, 1.5, -6)],
		[Vector3(0, 3.1, -16.4), Vector3(0, 1.4, 2.4)],
		[Vector3(-7.6, 2.2, -3), Vector3(2, 1.3, 0)],
		[Vector3(-0.6, 1.65, 2.9), Vector3(-1.85, 1.1, 1.8)]
	]
	for index in views.size():
		camera.position = views[index][0]
		camera.look_at(views[index][1])
		await _frames(8)
		await _capture("view-%02d" % index)
	player.player_camera.make_current()
	camera.queue_free()
	main.hud.visible = true
	main.native_pause_menu.visible = true
	player.visible = true
	print("ROOM01_VIEWS")
	var atmosphere = main.get_node("OpeningAtmosphere")
	if not _check(not atmosphere._vent.playing and atmosphere._vent_stream == null, "Muted arrival allocated or played ambience"): return
	main.set_audio_muted(false)
	print("ROOM01_UNMUTE")
	await _frames(4)
	if not _check(atmosphere._vent.playing and atmosphere._vent_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Vent loop did not start on unmute"): return
	atmosphere._vent_stream.save_to_wav(folder + "vent-air.wav")
	main.set_reduced_motion(true)
	var frozen: float = atmosphere.elapsed
	var playhead: float = atmosphere._vent.get_playback_position()
	paused = true
	for frame in 4: await process_frame
	if not _check(is_equal_approx(atmosphere.elapsed, frozen) and absf(atmosphere._vent.get_playback_position() - playhead) < 0.12, "Paused room audio or presentation advanced"): return
	paused = false
	print("ROOM01_PAUSE_VERIFIED")
	main.set_audio_muted(true)
	await _frames(2)
	if not _check(not atmosphere._vent.playing, "Mute did not stop room ambience"): return
	if standard:
		main.set_reduced_motion(false)
		main.set_audio_muted(false)
		player.set_gameplay_orbit(Vector3(-0.35, 0, 0))
	if not await _use_evidence("OpeningClock"): return
	print("ROOM01_CLOCK")
	await _frames(6)
	await _capture("01-clock")
	if not await _use_evidence("OpeningPhotograph"): return
	print("ROOM01_MEMORY")
	await _capture("02-memory")
	if not _check(main.get_node("PrologueOrchestrator").opening_memory_recovered, "Dialogue failed to unlock signal objective"): return
	if standard:
		main.set_reduced_motion(false)
		main.set_audio_muted(false)
	var terminal := main.find_child("SectorTerminal", true, false) as Node3D
	if not await _walk(terminal.global_position + Vector3(0, 0, -1.0)): return
	if not _check(player.get_nearest_interactable() == terminal.get_node("InteractionArea"), "Terminal not physically reachable"): return
	player.interact_with_nearest()
	var puzzle = main.hud.find_child("TerminalHackPuzzle", true, false)
	if not _check(puzzle.is_open and player.control_locked, "Actual terminal failed to open puzzle"): return
	puzzle.freq_slider.value = 96.0
	puzzle.close_puzzle()
	if not _check(not player.control_locked, "Cancelled terminal retained input ownership"): return
	player.interact_with_nearest()
	if not _check(is_equal_approx(puzzle.freq_slider.value, 96.0), "Retry discarded tuning progress"): return
	puzzle.freq_slider.value = 111.0
	puzzle.phase_slider.value = 45.0
	puzzle.harmonic_slider.value = 7.0
	await _frames(12)
	await _capture("03-signal-aligned")
	if not _check(puzzle.is_solved and not main.get_node("PrologueOrchestrator").room_gate_open, "Puzzle bypassed closure or missing power"): return
	puzzle.proceed_btn.pressed.emit()
	await _frames(4)
	var conduit := main.find_child("EnergyPowerConduit_A", true, false) as Node3D
	if not await _walk(Vector3(0, 0, -3.0)): return
	if not await _walk(conduit.global_position + Vector3(1.0, 0, 0)): return
	if not _check(player.get_nearest_interactable() == conduit.get_node("InteractionArea"), "Power conduit not physically reachable"): return
	player.interact_with_nearest()
	var breach = main.find_child("BlastGateBreachCinematic", true, false)
	if standard:
		for frame in 230:
			_resume()
			if frame in [15, 70, 140]: await _capture("gate-cinematic-%03d" % frame)
			await physics_frame
			if not breach._is_playing: break
		if not _check(not breach._is_playing and not player._camera_suspended, "Gate cinematic did not return camera ownership"): return
	await _frames(8)
	if not _check(main.get_node("PrologueOrchestrator").room_gate_open, "Both circuit interactions failed to open exit"): return
	if not standard and not _check(conduit.reduced_motion and conduit._surge_tween == null and not conduit.spark_particles.emitting, "Reduced Motion conduit failed static release"): return
	var expected_relay := 1 if standard else 0
	if not _check(atmosphere.relay_count == expected_relay, "Gate release sound count incorrect"): return
	main.set_audio_muted(false)
	await _frames(4)
	if not _check(atmosphere.relay_count == expected_relay, "Unmute replayed an old gate release"): return
	if record_effects:
		for frame in 24:
			await _frames(1)
			await _capture("circuit-%03d" % frame)
	if not await _walk(Vector3(0, 0, -12.0)): return
	if not await _walk(Vector3(0, 0, -15.2)): return
	_drain_dialogue()
	await _frames(6)
	if not _check(main.opening_web_handoff.reported_milestones.has("memory_scene_completed") and main.get_node("SystemJourneyPreview").room != null, "Boundary memory failed to load next connected room"): return
	main.get_node("PrologueOrchestrator").refresh_opening_objective()
	if not _check(not main.hud.current_directive_desc.contains("يتبع") and not main.hud.current_directive_desc.contains("continued"), "Connected room exit still advertises an unfinished opening"): return
	await _capture("04-threshold")
	var checkpoint: Dictionary = main.capture_native_checkpoint()
	# A continuous fresh-save review must never re-anchor between rooms.
	if not args.has("--full-chapter") and not args.has("--mystery-only") and not _check(main.restore_native_checkpoint(checkpoint), "Completed room checkpoint rejected restore"): return
	await _frames(4)
	if not _check(atmosphere.relay_count == expected_relay and not player.combat_available and not player.contract_with_zero_sealed, "Restore replayed sound or granted early combat/pact"): return
	if not await _walk(Vector3(0, 0, -18.7)): return
	await _frames(4)
	if not _check(not atmosphere._vent.playing and is_equal_approx(atmosphere._face_fill.light_energy, atmosphere._face_energy), "Room sound or local character light leaked beyond exit"): return
	await _capture("05-maintenance-entry")
	if (args.has("--maintenance") or args.has("--security") or args.has("--full-chapter") or args.has("--mystery-only")) and not await _maintenance_route(): return
	if (args.has("--security") or args.has("--full-chapter") or args.has("--mystery-only")) and not await _security_route(): return
	if not await _continue_review(): return
	if record_profile:
		var profile := FileAccess.open(folder+"profile.json",FileAccess.WRITE)
		profile.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_video_adapter_api_version(),"viewport":str(root.size),"max_fps":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode(),"method":"240 real process frame wall intervals at each actual connected route stop; screenshots outside samples; engine counters are not GPU duration or resident VRAM","phases":profile_phases},"\t"))
	var report := FileAccess.open(folder + "journey.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"language":main.presentation_language,"viewport":str(root.size),"display":DisplayServer.get_name(),"engine":Engine.get_version_info().string,"physical_room_route":true,"visual_acceptance":"REQUIRES_INSPECTION","audio_listening":"UNVERIFIED","diagnostics":atmosphere.diagnostics(),"source_hashes":{
		"native_journey.tscn":FileAccess.get_sha256("res://scenes/native_journey.tscn"),
		"opening_web_room.tscn":FileAccess.get_sha256("res://scenes/opening_web_room.tscn"),
		"opening_web_facility.tscn":FileAccess.get_sha256("res://scenes/environment/opening_web_facility.tscn"),
		"opening_evidence.tscn":FileAccess.get_sha256("res://scenes/environment/opening_evidence.tscn"),
		"opening_atmosphere.gd":FileAccess.get_sha256("res://scripts/environment/opening_atmosphere.gd"),
		"opening_inspection.gd":FileAccess.get_sha256("res://scripts/cinematics/opening_inspection.gd"),
		"opening_evidence.gd":FileAccess.get_sha256("res://scripts/environment/opening_evidence.gd"),
		"photochemical-emulsion.jpg":FileAccess.get_sha256("res://assets/textures/opening/photochemical-emulsion.jpg"),
		"room01_clock_hero.glb":FileAccess.get_sha256("res://assets/props/room01_clock_hero.glb"),
		"room01_trace_frame.glb":FileAccess.get_sha256("res://assets/props/room01_trace_frame.glb"),
		"native_pause_menu.gd":FileAccess.get_sha256("res://scripts/ui/native_pause_menu.gd"),
		"main.gd":FileAccess.get_sha256("res://scripts/main.gd"),
		"energy_power_conduit.gd":FileAccess.get_sha256("res://scripts/props/energy_power_conduit.gd"),
		"opening_deck.gdshader":FileAccess.get_sha256("res://shaders/opening_deck.gdshader"),
		"opening_frosted_glass.gdshader":FileAccess.get_sha256("res://shaders/opening_frosted_glass.gdshader"),
		"opening_dust.gdshader":FileAccess.get_sha256("res://shaders/opening_dust.gdshader"),
		"echo_v31_motion_adapter.gd":FileAccess.get_sha256("res://scripts/player/echo_v31_motion_adapter.gd"),
		"opening_energy_fx.gd":FileAccess.get_sha256("res://scripts/environment/opening_energy_fx.gd"),
		"opening_energy_field.gdshader":FileAccess.get_sha256("res://shaders/opening_energy_field.gdshader"),
		"opening_circuit_particles.gdshader":FileAccess.get_sha256("res://shaders/opening_circuit_particles.gdshader"),
		"opening_discovery_rings.gdshader":FileAccess.get_sha256("res://shaders/opening_discovery_rings.gdshader"),
		"prologue_orchestrator.gd":FileAccess.get_sha256("res://scripts/cinematics/prologue_orchestrator.gd"),
		"echo_v31_adopted_high.glb":FileAccess.get_sha256("res://assets/characters/echo_v31_adopted_high.glb")}}, "\t"))
	report.close()
	main.queue_free()
	for frame in 4: await process_frame
	_clear_fixture_saves()
	print("PASS current Room 01 evidence input journey: ", checks)
	quit(0)

func _maintenance_route() -> bool:
	var director = main.get_node("SystemJourneyPreview")
	if not _check(director.room != null and player.surface_traversal_enabled,"Opening did not connect to maintenance"): return false
	player.set_gameplay_orbit(Vector3.ZERO)
	if not await _walk(Vector3(0,0,-23.1)): return false
	if not _check(director.stage == 1,"Maintenance entry objective missing"): return false
	await _capture("room02-01-first-climb")
	if record_profile: await _sample_profile("room02-entry")
	if not await _climb_and_mantle("first"): return false
	if not _check(director.stage == 2,"First mantle did not advance mission"): return false
	if not await _walk(Vector3(2.1,3.4,-25)): return false
	player.request_jump()
	if not await _walk(Vector3(4,3.4,-25)): return false
	if not _check(director.stage == 3,"Actual gap crossing did not advance mission"): return false
	await _capture("room02-02-gap-crossed")
	if not await _walk(Vector3(4,3.4,-26.5)): return false
	if not await _climb_and_mantle("second"): return false
	if not _check(director.stage == 4,"Second mantle did not advance mission"): return false
	if not await _walk(Vector3(3.25,5.4,-29.5)): return false
	player.request_jump()
	if not await _walk(Vector3(2.3,5.4,-30.25)): return false
	if not _check(director.stage == 5 and not player.contract_with_zero_sealed,"Upper access missing or early pact granted"): return false
	if not _check(director._read(director.checkpoint_path) == 5,"Upper safe landing did not persist"): return false
	if not await _walk(Vector3(1.25,5.4,-30.1)): return false
	if not _check(player.get_nearest_interactable() == director.room.service_interaction,"Pressure wheel unreachable"): return false
	await _capture("room02-03-wheel-ready")
	if record_profile: await _sample_profile("room02-pressure-wheel")
	player.interact_with_nearest()
	if not _check(director.room.service_opening and director.stage == 5,"Pressure interaction advanced before clearance"): return false
	for frame in 230:
		_resume()
		if frame in [15,65,125]: await _capture("room02-release-%03d" % frame)
		await physics_frame
	if not _check(director.stage == 6 and director.room.service_open and not player._camera_suspended,"Pressure release did not return the camera and open passage"): return false
	if not await _walk(Vector3(0,5.4,-30.1)): return false
	if not await _walk(Vector3(0,5.4,-31.6)): return false
	if not _check(director.stage == 7 and director._read(director.checkpoint_path) == 7,"Vestibule crossing did not persist"): return false
	await _capture("room02-04-service-exit")
	if not await _walk(Vector3(0,5.4,-33.3)): return false
	if not _check(main.get_node("NativeJourneyController").security_entered and not player.combat_available,"Grounded security handoff failed or enabled early combat"): return false
	await _capture("room03-security-entry")
	if record_profile: await _sample_profile("room03-entry")
	var report := FileAccess.open(folder+"maintenance.json",FileAccess.WRITE)
	var hashes := {}
	for path in ["res://scenes/environment/maintenance_vertical.tscn","res://scripts/environment/maintenance_vertical.gd","res://scripts/environment/maintenance_room_presentation.gd","res://scripts/systems/system_journey_preview.gd","res://scripts/cinematics/maintenance_service_cinematic.gd","res://assets/environments/maintenance_jutsu_v1.glb","res://scripts/player/surface_traversal_motor.gd","res://assets/characters/echo_v31_adopted_high.glb"]:
		if not _check(FileAccess.file_exists(path),"Room02 source missing: "+path): return false
		hashes[path] = FileAccess.get_sha256(path)
	report.store_string(JSON.stringify({"checks":checks,"language":main.presentation_language,"viewport":str(root.size),"route":"actual public input from waking through two climbs, gap, pressure wheel and grounded security entry","visual_acceptance":"REQUIRES_INSPECTION","source_hashes":hashes},"\t"))
	print("PASS connected Room02 actual input route; checks=",checks)
	return true

func _climb_and_mantle(id: String) -> bool:
	player.set_mobile_input_vector(Vector2.ZERO,false)
	for frame in 240:
		_resume()
		if player.stamina >= 60: break
		await physics_frame
	player.set_mobile_input_vector(Vector2(0,-1),true)
	player.request_jump()
	for frame in 180:
		_resume()
		await physics_frame
		if player.surface_motor.hanging: break
	if not _check(player.surface_motor.hanging,"Actual climb failed to reach ledge: "+id): return false
	await _capture("room02-hang-"+id)
	player.request_jump()
	for frame in 140:
		_resume()
		await physics_frame
		if not player.traversal.is_climbing(): break
	player.set_mobile_input_vector(Vector2.ZERO,false)
	await _frames(16)
	await _capture("room02-mantle-"+id)
	return _check(player.is_on_floor(),"Actual mantle failed to land: "+id)

func _security_route() -> bool:
	var controller = main.get_node("NativeJourneyController")
	var room = controller.security
	if not await _walk(Vector3(-3.5,5.4,-33.8)): return false
	if not _check(player.get_nearest_interactable()==room.get_node("DivertStation/InteractionArea"),"Diversion console unreachable from Room02"): return false
	player.interact_with_nearest()
	await _frames(4)
	if not _check(controller.progress.security.scanner_trace and not room.gate_open,"Diversion failed to persist independently"): return false
	await _capture("room03-01-diversion")
	if not await _walk(Vector3(-3.5,5.4,-40.5)): return false
	await _capture("room03-02-cover-route")
	if not await _walk(Vector3(-3.5,5.4,-46.8)): return false
	if not await _walk(Vector3(-1.3,5.4,-47.2)): return false
	if not _check(player.get_nearest_interactable()==room.get_node("GateStation/InteractionArea"),"Manual security latch unreachable"): return false
	player.interact_with_nearest()
	await _frames(65)
	if not _check(room.gate_open and controller.progress.security.gate_open,"Manual latch failed or did not persist"): return false
	await _capture("room03-03-latch-open")
	if not await _walk(Vector3(0,5.4,-47.4)): return false
	if not await _walk(Vector3(0,5.4,-49.45)): return false
	await _frames(8)
	if not _check(controller.progress.completed.has("security_completed") and not player.combat_available,"Physical security exit missing or premature combat granted"): return false
	await _capture("room03-04-experiment-entry")
	var report := FileAccess.open(folder+"security.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"route":"actual connected input from waking through maintenance, diversion, cover, latch and grounded security exit","source_hashes":{"native_journey_controller.gd":FileAccess.get_sha256("res://scripts/systems/native_journey_controller.gd"),"security_checkpoint_room.gd":FileAccess.get_sha256("res://scripts/environment/security_checkpoint_room.gd"),"maintenance_room_presentation.gd":FileAccess.get_sha256("res://scripts/environment/maintenance_room_presentation.gd"),"maintenance_surface_finish.gdshader":FileAccess.get_sha256("res://shaders/maintenance_surface_finish.gdshader")}},"\t"))
	print("PASS connected Room03 actual input route; checks=",checks)
	return true

func _sample_profile(label: String) -> void:
	await _frames(30)
	var wall: Array[float] = []
	var draws: Array[float] = []
	var primitives: Array[float] = []
	var textures: Array[float] = []
	var last := Time.get_ticks_usec()
	for frame in 240:
		_resume()
		await process_frame
		var now := Time.get_ticks_usec()
		wall.append((now-last)/1000.0)
		last = now
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		textures.append(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	profile_phases[label] = {"samples":240,"wall_frame_ms":_profile_stats(wall),"draw_calls":_profile_stats(draws),"primitives":_profile_stats(primitives),"engine_texture_bytes":_profile_stats(textures)}
	print("PROFILE_ROUTE ",label," ",JSON.stringify(profile_phases[label]))

func _profile_stats(values: Array[float]) -> Dictionary:
	values.sort()
	return {"p50":values[int((values.size()-1)*0.50)],"p95":values[int((values.size()-1)*0.95)],"p99":values[int((values.size()-1)*0.99)],"max":values[-1]}

func _continue_review() -> bool:
	return true
