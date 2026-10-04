extends SceneTree

const Journey = preload("res://scripts/systems/native_journey_checkpoint.gd")
const Saves = preload("res://scripts/systems/save_manager.gd")
const Boot = preload("res://scripts/boot.gd")
const PATH := "user://native_journey_smoke.json"
const OPENING := "user://native_journey_smoke_opening.json"
const MAINTENANCE := "user://native_journey_smoke_maintenance.json"
const PREFS := "user://native_journey_smoke.cfg"
var main: Node

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	_clear()
	var progress := Journey.initial()
	if not _check(Journey.advance(progress, "security_entered").is_empty(), "out-of-order security accepted"): return
	progress = Journey.advance(progress, "opening_completed")
	if not _check(Journey.save_checkpoint(progress, PATH), "initial checkpoint failed"): return
	progress = Journey.advance(progress, "maintenance_completed")
	var prior_primary := FileAccess.get_file_as_string(PATH)
	DirAccess.make_dir_absolute(PATH + ".bak")
	if not _check(not Journey.save_checkpoint(progress, PATH) and FileAccess.get_file_as_string(PATH) == prior_primary, "failed backup promotion lost primary"): return
	DirAccess.remove_absolute(PATH + ".bak")
	if not _check(Journey.save_checkpoint(progress, PATH), "atomic replacement failed"): return
	_write(PATH, "broken json")
	if not _check(Journey.load_checkpoint(PATH).completed == ["opening_completed"], "corrupt primary did not recover backup"): return
	if not _check(Journey.save_checkpoint(progress, PATH) and Journey.read(PATH + ".bak").completed == ["opening_completed"], "corrupt primary replaced recovery copy"): return
	for forged in [
		{"schema": "foreign", "completed": []},
		{"schema": Journey.SCHEMA, "completed": ["maintenance_completed"]},
		{"schema": Journey.SCHEMA, "completed": ["opening_completed", "opening_completed"]},
		{"schema": Journey.SCHEMA, "completed": ["opening_completed", "maintenance_completed", "security_entered", "pact"]},
		{"schema": Journey.SCHEMA, "completed": "opening_completed"},
		{"schema": Journey.SCHEMA, "completed": [true]},
		{"schema": Journey.SCHEMA, "completed": [], "contract_with_zero_sealed": true},
		{"schema": Journey.SCHEMA, "completed": [], "wallet": 9999},
	]:
		if not _check(Journey.validate(forged).is_empty(), "invalid/future/account checkpoint accepted"): return
	if not _check(not Journey.save_checkpoint(progress, "user://missing-native-journey-directory/checkpoint.json"), "failed write reported success"): return
	_clear()
	# Instantiate the exact packed scene selected by default boot, with isolated files.
	var old_route := Journey.initial()
	for event in Journey.EVENTS.slice(0,3): old_route = Journey.advance(old_route, event)
	if not _check(Journey.save_checkpoint(old_route, PATH), "old-route fixture failed"): return
	main = _new_main()
	root.add_child(main)
	for i in range(12): await physics_frame
	var controller = main.get_node("NativeJourneyController")
	var maintenance = main.get_node("SystemJourneyPreview")
	if not _check(not maintenance.room and controller.progress.completed.is_empty(), "unfinished opening released maintenance"): return
	if not _check(not controller._commit("opening_completed"), "unfinished opening could commit route progress"): return
	if not _check(not main.has_node("KingaTortureSequence") and not main.has_node("WorldStreamer"), "default entry connected legacy future content"): return
	main.queue_free()
	for i in range(3): await process_frame
	_clear()
	# Real validated cold opening save + maintenance safe landing restore.
	# Opening and climb input are covered by the independent route/traversal tests.
	var opening := {"schema": Saves.OPENING_SCHEMA, "milestones": {"wake": true, "clock": true, "photo": true, "memory": true, "terminal": true, "conduit": true, "ending": true}, "terminal": {"frequency": 111.0, "phase": 45.0, "harmonic": 7.0}}
	if not _check(Saves.save_opening_checkpoint(opening, OPENING), "fixture opening save failed"): return
	_write(MAINTENANCE, JSON.stringify({"schema": "echo-maintenance-preview-v1", "stage": 6}))
	main = _new_main()
	root.add_child(main)
	for i in range(12): await physics_frame
	main.set_audio_muted(true)
	main.set_reduced_motion(true)
	controller = main.get_node("NativeJourneyController")
	maintenance = main.get_node("SystemJourneyPreview")
	if not _check(maintenance.room != null and maintenance.stage == 6 and controller.progress.completed == ["opening_completed"], "default continuation did not restore existing maintenance save"): return
	var gate = main.find_child("PrimaryBlastGate", true, false)
	if not _check(gate.get_collision_shape().disabled and maintenance.room.service_open, "authored ending did not release traversal boundary"): return
	if not _check(not controller._commit("security_entered"), "controller accepted out-of-order threshold"): return
	var signaled_security: Array = []
	controller.progress_changed.connect(func(completed: Array):
		if completed.size() == 3: signaled_security.append(controller.security_entered)
	)
	main.player.camera_boom.rotation.y = 0
	Input.action_press("move_forward")
	for i in range(180):
		await physics_frame
		if controller.security_entered: break
	Input.action_release("move_forward")
	for i in range(4): await physics_frame
	if not _check(controller.security_entered and maintenance.stage == 7 and controller.progress.completed == Journey.EVENTS.slice(0,3), "real grounded movement did not cross maintenance/security thresholds"): return
	if not _check(signaled_security == [true], "integration signal preceded consistent durable security state"): return
	if not _check(not main.player.combat_available and not main.player.contract_with_zero_sealed and not main.player.shadow_step_unlocked, "threshold granted early powers"): return
	var checkpoint_text := FileAccess.get_file_as_string(PATH)
	if not _check(controller._commit("security_entered") and FileAccess.get_file_as_string(PATH) == checkpoint_text, "duplicate transition rewrote checkpoint"): return
	if not _check(not controller._commit("zero_pact_sealed"), "later contract transition accepted"): return
	var terminal_order: Dictionary = Saves.load_opening_checkpoint(OPENING)
	if not _check(terminal_order.milestones.ending and maintenance._read(MAINTENANCE) == 7, "existing opening/maintenance saves not preserved"): return
	main.queue_free()
	for i in range(4): await process_frame
	main = _new_main()
	root.add_child(main)
	for i in range(12): await physics_frame
	controller = main.get_node("NativeJourneyController")
	if not _check(controller.security_entered and main.player.position.distance_to(controller.SECURITY_ANCHOR) < 0.2 and main.reduced_motion, "cold security restore lost safe anchor/preferences"): return
	main.queue_free()
	for i in range(4): await process_frame
	_write(PATH, "corrupt security checkpoint")
	main = _new_main()
	root.add_child(main)
	for i in range(12): await physics_frame
	controller = main.get_node("NativeJourneyController")
	if not _check(controller.progress.completed == ["opening_completed", "maintenance_completed"] and not controller.security_entered, "corrupt security save did not recover ordered prior progress"): return
	if not _check(not main.player.combat_available and not main.player.contract_with_zero_sealed, "backup restore enabled combat"): return
	controller.checkpoint_path = "user://missing-native-journey-directory/checkpoint.json"
	var prior: Dictionary = controller.progress.duplicate(true)
	if not _check(not controller._commit("security_entered") and controller.progress == prior and not controller.save_succeeded, "failed runtime save advanced progress"): return
	main.queue_free()
	for i in range(4): await process_frame
	_clear()
	print("PASS native default entry: opening prerequisite, existing maintenance restore, real movement through maintenance/security thresholds, cold reload, corrupt backup, duplicate/out-of-order/future rejection, failed write, no early powers")
	quit(0)

func _new_main() -> Node:
	var scene = load(Boot.NATIVE_SCENE).instantiate()
	scene.native_checkpoint_path = OPENING
	scene.native_preferences_path = PREFS
	scene.get_node("SystemJourneyPreview").checkpoint_path = MAINTENANCE
	scene.get_node("NativeJourneyController").checkpoint_path = PATH
	return scene

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _check(condition: bool, detail: String) -> bool:
	if condition: return true
	Input.action_release("move_forward")
	push_error(detail)
	quit(1)
	return false

func _clear() -> void:
	for base in [PATH, OPENING, MAINTENANCE, PREFS]:
		for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
			if FileAccess.file_exists(base + suffix): DirAccess.remove_absolute(base + suffix)
