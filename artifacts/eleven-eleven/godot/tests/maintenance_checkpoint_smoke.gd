extends SceneTree

const PATH := "user://maintenance_checkpoint_smoke.json"

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var main = load("res://scenes/system_journey_preview.tscn").instantiate()
	main.native_checkpoint_path = "user://maintenance_checkpoint_opening.json"
	main.native_preferences_path = "user://maintenance_checkpoint_prefs.cfg"
	root.add_child(main)
	var director = main.get_node("SystemJourneyPreview")
	director.checkpoint_path = PATH
	await process_frame
	main.set_audio_muted(true)
	main.set_reduced_motion(true)
	main.player.finish_opening_recovery()
	# Checkpoint fixture; progression is independently tested through actual input.
	main.opening_web_handoff.reported_milestones.append("memory_scene_completed")
	for i in range(4): await physics_frame
	director.stage = 2
	if not _check(director._save(), "first atomic checkpoint failed"): return
	director.stage = 3
	if not _check(director._save(), "replacement checkpoint failed"): return
	_write(PATH,"broken json")
	director.stage = 0
	director._restore()
	if not _check(director.stage == 2 and main.player.position.distance_to(Vector3(0,3.5,-24.5)) < 0.01, "validated backup did not restore its authored anchor"): return
	for forged in ['{"schema":"foreign","stage":5}', '{"schema":"echo-maintenance-preview-v1","stage":99}', '{"schema":"echo-maintenance-preview-v1","stage":2.5}', '{"schema":"echo-maintenance-preview-v1","stage":"5"}']:
		_write(PATH,forged)
		if not _check(director._read(PATH) == -1, "invalid checkpoint accepted"): return
	director.checkpoint_path = "user://missing-maintenance-directory/checkpoint.json"
	if not _check(not director._save(), "failed storage reported a successful save"): return
	if not _check(not main.player.contract_with_zero_sealed and not main.player.combat_available, "restore granted premature powers"): return
	main.queue_free()
	for i in range(3): await process_frame
	for path in [PATH,PATH+".bak",PATH+".tmp","user://maintenance_checkpoint_opening.json","user://maintenance_checkpoint_opening.json.bak","user://maintenance_checkpoint_prefs.cfg"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("PASS maintenance checkpoint: atomic replacement, corrupt-primary recovery, schema/range/type rejection, failed write and no premature powers")
	quit()

func _write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()

func _check(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		quit(1)
	return condition
