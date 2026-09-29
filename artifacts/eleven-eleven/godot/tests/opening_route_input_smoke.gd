extends SceneTree

const SAVE = "user://route_input_smoke.json"
const PREFS = "user://route_input_smoke.cfg"
var main: Node
var player: CharacterBody3D
var dialogue: Control
var touch: Control
var maintenance := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	maintenance = "maintenance" in OS.get_cmdline_user_args()
	for terminal_first in [true, false]:
		_clear()
		main = load("res://scenes/system_journey_preview.tscn" if maintenance else "res://scenes/opening_native_room.tscn").instantiate()
		main.native_checkpoint_path = SAVE
		main.native_preferences_path = PREFS
		root.add_child(main)
		if maintenance: main.get_node("SystemJourneyPreview").checkpoint_path = "user://maintenance_route_smoke.json"
		await process_frame
		main.set_audio_muted(true)
		main.set_reduced_motion(true)
		player = main.player
		dialogue = main.hud.find_child("DialogueOverlay", true, false)
		touch = main.hud.find_child("MobileTouchControls", true, false)
		player.finish_opening_recovery()
		await process_frame
		if not _check(dialogue.is_active and player.control_locked, "wake dialogue does not lock movement"): return
		main.set_presentation_language("en")
		if not _check(dialogue.full_text == "Where... is this?" and dialogue.continue_button.text == "Continue", "current dialogue not translated"): return
		main.set_presentation_language("ar")
		if not _check(dialogue.full_text.contains("أنا") and dialogue.text_lbl.visible_characters == -1, "Arabic/reduced motion line incomplete"): return
		await _continue_dialogue()
		Input.action_press("attack_light")
		for i in range(3): await physics_frame
		Input.action_release("attack_light")
		for i in range(3): await physics_frame
		if not _check(not player.combat_available and not player.is_charging_iai and not player.find_child("KatanaBlade", true, false).visible, "mouse input enabled forbidden opening combat"): return
		# Drive the actual movement signal/controller and proximity registration;
		# never relocate the player or invoke progression/auto-solve helpers.
		player.camera_boom.rotation.y = 0
		if not await _walk(Vector3(-1.35, 0, 1.8)): return
		if not _interact("OpeningClock"): return
		if not _check(main.get_node("PrologueOrchestrator").clock_inspected, "clock not registered"): return
		if not await _walk(Vector3(0, 0, 1.8)): return
		if not await _walk(Vector3(2.7, 0, -1.5)): return
		if not _interact("OpeningPhotograph"): return
		var prologue = main.get_node("PrologueOrchestrator")
		if not _check(dialogue.is_active and not prologue.opening_memory_recovered, "memory granted before dialogue completion"): return
		var position := player.global_position
		touch.joystick_moved.emit(Vector2.ONE)
		for i in range(5): await physics_frame
		if not _check(player.global_position.distance_to(position) < 0.05, "dialogue permits gameplay movement"): return
		await _continue_dialogue()
		if not _check(prologue.opening_memory_recovered and not player.control_locked and player.mobile_input_vector == Vector2.ZERO, "dialogue completion did not reset held input"): return
		for task in (["terminal", "conduit"] if terminal_first else ["conduit", "terminal"]):
			if not await _walk(Vector3(0, 0, 0)): return
			if task == "terminal":
				if not await _walk(Vector3(1.75, 0, 2.4)): return
				if not _interact("SectorTerminal"): return
				var puzzle = main.hud.find_child("TerminalHackPuzzle", true, false)
				if not _check(puzzle.visible and player.control_locked, "terminal UI not reached via interaction"): return
				puzzle.freq_slider.value = 111
				puzzle.phase_slider.value = 45
				puzzle.harmonic_slider.value = 7
				if not _check(puzzle.is_solved and not prologue.wake_terminal_solved, "terminal advanced before UI acknowledgment"): return
				puzzle.proceed_btn.pressed.emit()
			else:
				if not await _walk(Vector3(0, 0, -4)): return
				if not await _walk(Vector3(-2.5, 0, -4)): return
				if not _interact("EnergyPowerConduit_A"): return
			if not _check(prologue.room_gate_open == (prologue.wake_terminal_solved and prologue.conduit_a_energized), "gate violated two-task prerequisite"): return
		if not await _walk(Vector3(0, 0, -4)): return
		if not await _walk(Vector3(0, 0, -15)): return
		if not _check(dialogue.is_active and prologue.gate_reveal_seen, "gate threshold missing ending dialogue"): return
		await _continue_dialogue()
		if not _check(main.opening_web_handoff.reported_milestones.has("memory_scene_completed") and not player.combat_available, "ending not completed or combat activated"): return
		if maintenance:
			if not await _maintenance_route(): return
		if terminal_first and not maintenance:
			if not await _walk(Vector3(0, 0, -7)): return
			if not await _walk(Vector3(-7.7, 0, -7)): return
			player.camera_boom.rotation.y = -PI / 2
			for i in range(8): await physics_frame
			if not _check(player.camera_boom.get_hit_length() < 2.0 and player.player_camera.global_position.x > -8.6, "camera penetrates west wall"): return
			player.camera_boom.rotation.y = 0
			player.camera_boom.rotation.x = 0.8
			for i in range(8): await physics_frame
			print("CAMERA floor player=", player.global_position, " camera=", player.player_camera.global_position, " hit=", player.camera_boom.get_hit_length())
			if not _check(player.player_camera.global_position.y > 0.1 and player.camera_boom.get_hit_length() < 3.0, "camera penetrates floor"): return
			print("CAMERA PASS wall/floor collision and player exclusion")
		main.queue_free()
		await process_frame
		print("ROUTE PASS terminal_first=", terminal_first)
	_clear()
	print("PASS opening route: controller movement, proximity, bilingual dialogue, modal input, both orders, threshold ending")
	quit(0)

func _walk(target: Vector3) -> bool:
	for i in range(1000):
		if target.z <= -14.5 and dialogue.is_active and player.global_position.z <= -14.5:
			touch.joystick_moved.emit(Vector2.ZERO)
			return true
		var delta := target - player.global_position
		delta.y = 0
		if delta.length() < 0.18:
			touch.joystick_moved.emit(Vector2.ZERO)
			for settle in range(8): await physics_frame
			return true
		touch.joystick_moved.emit(Vector2(delta.x, delta.z).normalized())
		await physics_frame
	return _check(false, "movement blocked toward %s from %s" % [target, player.global_position])

func _interact(target_name: String) -> bool:
	var target = main.find_child(target_name, true, false)
	if not _check(player.get_nearest_interactable() == target.get_node("InteractionArea"), "wrong proximity target: " + target_name): return false
	player.interact_with_nearest()
	return true

func _continue_dialogue() -> void:
	for i in range(12):
		if not dialogue.is_active: break
		dialogue.continue_button.pressed.emit()
		await process_frame

func _clear() -> void:
	for path in [SAVE, SAVE + ".bak", SAVE + ".tmp", PREFS, "user://maintenance_route_smoke.json", "user://maintenance_route_smoke.json.bak", "user://maintenance_route_smoke.json.tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

func _maintenance_route() -> bool:
	for i in range(6): await physics_frame
	var director = main.get_node("SystemJourneyPreview")
	if not _check(director.room != null and player.surface_traversal_enabled, "opening did not connect to maintenance"): return false
	if not await _walk(Vector3(0, 0, -23.1)): return false
	if not _check(director.stage == 1, "maintenance entry mission not reached"): return false
	if not await _climb_and_mantle(): return false
	if not _check(director.stage == 2, "first mantle did not advance mission"): return false
	if not await _walk(Vector3(2.1, 3.4, -25)): return false
	touch.jump_tapped.emit()
	if not await _walk(Vector3(4, 3.4, -25)): return false
	if not _check(director.stage == 3, "physical gap crossing did not advance mission"): return false
	if not await _walk(Vector3(4, 3.4, -26.5)): return false
	if not await _climb_and_mantle(): return false
	if not _check(director.stage == 4, "second mantle did not advance mission"): return false
	if not await _walk(Vector3(3.25, 5.4, -29.5)): return false
	touch.jump_tapped.emit()
	if not await _walk(Vector3(2.3, 5.4, -30.25)): return false
	if not _check(director.stage == 5 and not player.contract_with_zero_sealed, "upper access failed or Zero leaked"): return false
	main.set_presentation_language("en")
	if not _check(main.hud.quest_title.text == "Service access reached", "journey language was overwritten by opening objective"): return false
	main.set_presentation_language("ar")
	if not _check(director._read(director.checkpoint_path) == 5, "journey checkpoint was not saved"): return false
	print("PASS connected maintenance route: opening -> two climbs/mantles -> gap -> upper exit, touch signals and independent save")
	return true

func _climb_and_mantle() -> bool:
	touch.joystick_moved.emit(Vector2(0,-1))
	touch.jump_tapped.emit()
	for i in range(180):
		await physics_frame
		if player.surface_motor.hanging: break
	if not _check(player.surface_motor.hanging, "route failed to hang at authored ledge"): return false
	touch.jump_tapped.emit()
	for i in range(140):
		await physics_frame
		if not player.traversal.is_climbing(): break
	touch.joystick_moved.emit(Vector2.ZERO)
	for i in range(16): await physics_frame
	return _check(player.is_on_floor(), "route mantle did not land")

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
