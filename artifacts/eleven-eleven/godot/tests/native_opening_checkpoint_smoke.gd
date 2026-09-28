extends SceneTree

const Saves = preload("res://scripts/systems/save_manager.gd")
const PATH = "user://native_checkpoint_smoke.json"
const PREFS = "user://native_checkpoint_smoke.cfg"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_clear_files()
	var checkpoint := {
		"schema": Saves.OPENING_SCHEMA,
		"milestones": {"wake": true, "clock": true, "photo": true, "memory": true, "terminal": true, "conduit": false, "ending": false},
		"terminal": {"frequency": 93.0, "phase": 85.0, "harmonic": 3.0},
		"wallet": {"credits": 999999},
	}
	if not _check(not Saves.validate_opening_checkpoint(checkpoint).has("wallet"), "checkpoint retained account data"): return
	var invalid := checkpoint.duplicate(true)
	invalid.milestones.memory = false
	if not _check(Saves.validate_opening_checkpoint(invalid).is_empty(), "impossible chronology accepted"): return
	if not _check(Saves.save_opening_checkpoint(checkpoint, PATH), "initial save failed"): return
	checkpoint.milestones.terminal = false
	checkpoint.milestones.conduit = true
	if not _check(Saves.save_opening_checkpoint(checkpoint, PATH), "atomic replacement failed"): return
	if not _check(Saves.load_opening_checkpoint(PATH).milestones.conduit, "latest checkpoint missing"): return
	var damaged := FileAccess.open(PATH, FileAccess.WRITE)
	damaged.store_string("{invalid")
	damaged.close()
	if not _check(Saves.load_opening_checkpoint(PATH).milestones.terminal, "corrupt primary did not recover backup"): return
	if not _check(Saves.save_opening_checkpoint(checkpoint, PATH), "save after recovery failed"): return
	if not _check(Saves.load_opening_checkpoint(PATH + ".bak").milestones.terminal, "corrupt primary replaced valid backup"): return
	_clear_files()
	var scene: PackedScene = load("res://scenes/opening_native_room.tscn")
	var main = scene.instantiate()
	main.native_checkpoint_path = PATH
	main.native_preferences_path = PREFS
	root.add_child(main)
	await process_frame
	var prologue = main.get_node("PrologueOrchestrator")
	var player = main.get_node("EchoPlayer")
	for terminal_first in [true, false]:
		checkpoint.milestones.terminal = terminal_first
		checkpoint.milestones.conduit = not terminal_first
		if not _check(main.restore_native_checkpoint(checkpoint), "restore failed"): return
		if not _check(not prologue.room_gate_open and not player.combat_available and not player.control_locked, "partial restore opened gate or enabled combat/locked controls"): return
	# Exercise the player's real proximity/E interaction path, rather than energize().
	checkpoint.milestones.terminal = false
	checkpoint.milestones.conduit = false
	main.restore_native_checkpoint(checkpoint)
	var conduit = main.find_child("EnergyPowerConduit_A", true, false)
	player.global_position = conduit.global_position + Vector3(1.0, 0, 0)
	for i in range(4):
		await physics_frame
	if not _check(player.get_nearest_interactable() == conduit.get_node("InteractionArea"), "player cannot find conduit in proximity"): return
	player.interact_with_nearest()
	if not _check(prologue.conduit_a_energized, "player interaction did not power conduit"): return
	checkpoint.milestones.terminal = true
	checkpoint.milestones.conduit = true
	checkpoint.milestones.ending = true
	if not _check(main.restore_native_checkpoint(checkpoint), "ending restore failed"): return
	var corridor = main.find_child("Corridor1_Decontamination", true, false)
	if not _check(prologue.room_gate_open and prologue.gate_reveal_seen and (not corridor or corridor.process_mode == Node.PROCESS_MODE_DISABLED), "restored ending activated future corridor"): return
	main.set_audio_muted(true)
	main.set_reduced_motion(true)
	main.set_audio_muted(false)
	main._load_native_preferences()
	if not _check(main.reduced_motion and not main.audio_muted, "preferences did not persist"): return
	# Let the played conduit cue finish before disposing the test scene.
	await create_timer(0.8).timeout
	main.queue_free()
	await process_frame
	Saves.save_opening_checkpoint(checkpoint, PATH)
	var resumed = scene.instantiate()
	resumed.native_checkpoint_path = PATH
	resumed.native_preferences_path = PREFS
	root.add_child(resumed)
	await process_frame
	if not _check(resumed.get_node("PrologueOrchestrator").gate_reveal_seen and resumed.reduced_motion and not resumed.get_node("EchoPlayer").opening_recovery_active, "cold scene launch failed to restore checkpoint/preferences"): return
	resumed.queue_free()
	await process_frame
	_clear_files()
	print("PASS native opening: atomic save, backup recovery, whitelist, both orders, ending isolation, preferences")
	quit(0)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition

func _clear_files() -> void:
	for path in [PATH, PATH + ".bak", PATH + ".tmp", PREFS]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
