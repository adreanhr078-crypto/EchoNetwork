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
	if not hud.directive_active or player.combat_available:
		_fail("recovery did not hand off to the unarmed room objective")
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
	var start_position: Vector3 = player.global_position
	Input.action_press("move_forward")
	for i in range(30):
		await physics_frame
	Input.action_release("move_forward")
	if player.global_position.distance_to(start_position) < 0.1:
		_fail("keyboard movement did not move Echo after recovery")
		return
	var terminal = main.find_child("SectorTerminal", true, false)
	var puzzle = hud.find_child("TerminalHackPuzzle", true, false)
	main._on_terminal_accessed(terminal)
	if not puzzle.visible:
		_fail("room terminal did not open the interaction puzzle")
		return
	puzzle.auto_align_solution()
	await process_frame
	if not prologue.room_gate_open or prologue.current_step != prologue.Step.STAGE_0_AWAKENING:
		_fail("terminal completion did not stop at the room gate")
		return
	if player.combat_available or katana.visible or (scabbard and scabbard.visible):
		_fail("weapon appeared after solving the room puzzle")
		return
	print("PASS opening slice: unarmed recovery, delayed mission, keyboard and touch camera, terminal, room gate")
	quit(0)

func _fail(message: String) -> void:
	printerr("FAIL opening slice: ", message)
	quit(1)
