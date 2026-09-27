extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if not scene:
		_fail("main scene failed to load")
		return
	var main: Node3D = scene.instantiate()
	root.add_child(main)
	for i in range(4):
		await process_frame
	var player = main.get_node("EchoPlayer")
	var hud = main.get_node("GameplayHUD")
	var prologue = main.get_node("PrologueOrchestrator")
	var handoff = main.get_node("OpeningWebHandoff")
	if handoff.report_milestone("not_a_world_event") or not handoff.reported_milestones.is_empty():
		_fail("web presentation bridge accepted an invented milestone")
		return
	main.set_audio_muted(true)
	if not AudioServer.is_bus_mute(0) or main.audio_muted != true:
		_fail("opening mute control did not silence the master bus")
		return
	main.set_audio_muted(false)
	if AudioServer.is_bus_mute(0):
		_fail("opening mute control did not restore audio")
		return
	var katana = player.find_child("KatanaBlade", true, false)
	var scabbard = player.find_child("KatanaHipScabbard", true, false)
	if player.combat_available or katana.visible or (scabbard and scabbard.visible):
		_fail("weapon or combat is available during recovery")
		return
	if hud.directive_active or hud.get_node("QuestContainer").visible:
		_fail("first mission is visible before recovery")
		return
	player.finish_opening_recovery()
	await process_frame
	if handoff.reported_milestones != ["wake_completed", "room_entered"]:
		_fail("recovery did not record the played wake event")
		return
	if not hud.directive_active or player.combat_available:
		_fail("recovery did not hand off to the unarmed room objective")
		return
	if not hud.compass_bar.tracked_markers.has("opening_clock"):
		_fail("first mission has no tracked clock destination")
		return
	var dialogue = hud.find_child("DialogueOverlay", true, false)
	while dialogue.is_active:
		dialogue.advance_dialogue()
	var clock = main.find_child("OpeningClock", true, false)
	var photo = main.find_child("OpeningPhotograph", true, false)
	if photo.get_node("InteractionArea").is_enabled:
		_fail("photograph became available before the clock was inspected")
		return
	clock.get_node("InteractionArea").trigger_interaction(player)
	if not hud.compass_bar.tracked_markers.has("opening_photo") or not photo.get_node("InteractionArea").is_enabled:
		_fail("clock inspection did not reveal the next evidence mission")
		return
	photo.get_node("InteractionArea").trigger_interaction(player)
	if prologue.opening_memory_recovered:
		_fail("memory was credited before its short scene finished")
		return
	while dialogue.is_active:
		dialogue.advance_dialogue()
	if not prologue.opening_memory_recovered or not hud.compass_bar.tracked_markers.has("wake_terminal"):
		_fail("played memory did not unlock the terminal mission")
		return
	var touch = hud.find_child("MobileTouchControls", true, false)
	if touch.attack_btn.visible or touch.dodge_btn.visible or touch.lock_on_btn.visible or not touch.use_btn.visible:
		_fail("touch actions expose combat before its story unlock")
		return
	var camera_boom = player.find_child("CameraBoom", true, false)
	var yaw_before: float = camera_boom.rotation.y
	touch.camera_swiped.emit(Vector2(60.0, 0.0))
	if is_equal_approx(camera_boom.rotation.y, yaw_before):
		_fail("touch camera drag is not connected to the player")
		return
	touch.sprint_changed.emit(true)
	if not player.mobile_sprint_active:
		_fail("touch sprint is not connected to the player")
		return
	touch.sprint_changed.emit(false)
	if player.mobile_sprint_active:
		_fail("touch sprint did not release")
		return
	var start_position: Vector3 = player.global_position
	Input.action_press("move_forward")
	for i in range(30):
		await physics_frame
	Input.action_release("move_forward")
	if player.global_position.distance_to(start_position) < 0.1:
		_fail("keyboard movement did not move Echo after recovery")
		return
	var terminal = main.find_child("SectorTerminal", true, false)
	var terminal_range = terminal.get_node("InteractionArea/CollisionShape3D").shape
	if terminal_range.radius > 1.6:
		_fail("wake terminal is reachable without approaching")
		return
	var puzzle = hud.find_child("TerminalHackPuzzle", true, false)
	main._on_terminal_accessed(terminal)
	if not puzzle.visible or not player.control_locked:
		_fail("room terminal did not open a modal interaction")
		return
	puzzle.freq_slider.value = 96.0
	puzzle.close_puzzle()
	if player.control_locked or puzzle.visible:
		_fail("closing the terminal did not restore control")
		return
	main._on_terminal_accessed(terminal)
	if not is_equal_approx(puzzle.freq_slider.value, 96.0):
		_fail("returning to the terminal lost partial progress")
		return
	puzzle.freq_slider.value = 111.0
	puzzle.phase_slider.value = 45.0
	puzzle.harmonic_slider.value = 7.0
	await process_frame
	if not puzzle.is_solved or prologue.room_gate_open or prologue.wake_terminal_solved:
		_fail("terminal solve advanced the world while the overlay was open")
		return
	puzzle.close_puzzle()
	await process_frame
	if not prologue.wake_terminal_solved or not hud.compass_bar.tracked_markers.has("power_conduit"):
		_fail("terminal mission did not point to the power conduit")
		return
	var conduit = main.find_child("EnergyPowerConduit_A", true, false)
	conduit.energize()
	await process_frame
	if not prologue.room_gate_open or prologue.current_step != prologue.Step.STAGE_0_AWAKENING:
		_fail("both interactions did not open the room gate in terminal-first order")
		return
	if handoff.reported_milestones != ["wake_completed", "room_entered", "clock_inspected", "photo_inspected", "memory_recovered", "terminal_aligned", "conduit_energized", "puzzle_solved", "door_unlocked", "gate_revealed"]:
		_fail("terminal-first presentation milestones differ from played actions")
		return
	if handoff.report_milestone("gate_revealed"):
		_fail("presentation milestone was emitted twice")
		return
	if not hud.compass_bar.tracked_markers.has("room_gate"):
		_fail("completed room mission did not track the revealed gate")
		return
	player.global_position.z = -15.0
	prologue._physics_process(0.0)
	if not prologue.gate_reveal_seen:
		_fail("approaching the chapter boundary did not reveal the ending")
		return
	if handoff.reported_milestones[-1] != "chapter_boundary_seen":
		_fail("chapter boundary did not record its played reveal: " + str(handoff.reported_milestones))
		return
	while dialogue.is_active:
		dialogue.advance_dialogue()
	if handoff.reported_milestones[-1] != "memory_scene_completed":
		_fail("ending memory scene was credited before player finished it")
		return
	var corridor = main.find_child("Corridor1_Decontamination", true, false)
	var gate = main.find_child("PrimaryBlastGate", true, false)
	if corridor.process_mode != Node.PROCESS_MODE_DISABLED or not gate.keep_collision_when_open:
		_fail("future stage is active or the room threshold is unprotected")
		return
	await create_timer(3.5).timeout
	if gate.get_collision_shape().disabled or gate.state != gate.GateState.OPENED:
		_fail("opened gate lost the chapter boundary collider")
		return
	if player.combat_available or katana.visible or (scabbard and scabbard.visible):
		_fail("weapon appeared after solving the room puzzle")
		return
	main.queue_free()
	await process_frame
	var second: Node3D = scene.instantiate()
	root.add_child(second)
	for i in range(4):
		await process_frame
	var second_player = second.get_node("EchoPlayer")
	second_player.finish_opening_recovery()
	var second_dialogue = second.find_child("DialogueOverlay", true, false)
	while second_dialogue.is_active:
		second_dialogue.advance_dialogue()
	second.find_child("OpeningClock", true, false).get_node("InteractionArea").trigger_interaction(second_player)
	second.find_child("OpeningPhotograph", true, false).get_node("InteractionArea").trigger_interaction(second_player)
	while second_dialogue.is_active:
		second_dialogue.advance_dialogue()
	second.set_reduced_motion(true)
	var motion_button = second.find_child("MotionBtn", true, false) as Button
	if not second.reduced_motion or not motion_button or motion_button.text != "STILL":
		_fail("reduced motion could not be enabled")
		return
	var second_prologue = second.get_node("PrologueOrchestrator")
	second.find_child("EnergyPowerConduit_A", true, false).energize()
	await process_frame
	var second_hud = second.get_node("GameplayHUD")
	if second_prologue.room_gate_open or not second_hud.compass_bar.tracked_markers.has("wake_terminal"):
		_fail("conduit-first objective did not redirect Echo to the terminal")
		return
	second._on_terminal_accessed(second.find_child("SectorTerminal", true, false))
	var second_puzzle = second_hud.find_child("TerminalHackPuzzle", true, false)
	second_puzzle.freq_slider.value = 111.0
	second_puzzle.phase_slider.value = 45.0
	second_puzzle.harmonic_slider.value = 7.0
	if second_prologue.room_gate_open:
		_fail("gate opened behind the terminal overlay")
		return
	second_puzzle.close_puzzle()
	await process_frame
	if not second_prologue.room_gate_open:
		_fail("both interactions did not open the room gate in conduit-first order")
		return
	var second_handoff = second.get_node("OpeningWebHandoff")
	if second_handoff.reported_milestones != ["wake_completed", "room_entered", "clock_inspected", "photo_inspected", "memory_recovered", "conduit_energized", "terminal_aligned", "puzzle_solved", "door_unlocked", "gate_revealed"]:
		_fail("conduit-first presentation milestones differ from played actions: " + str(second_handoff.reported_milestones))
		return
	var second_breach = second.find_child("BlastGateBreachCinematic", true, false)
	if second_breach._is_playing:
		_fail("reduced motion started the gate camera sweep")
		return
	second.queue_free()
	await process_frame
	await create_timer(1.0).timeout
	print("PASS opening slice: recovery, input, both gate orders, stage isolation")
	quit(0)

func _fail(message: String) -> void:
	printerr("FAIL opening slice: ", message)
	quit(1)
