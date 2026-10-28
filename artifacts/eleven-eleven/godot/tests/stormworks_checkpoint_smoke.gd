extends SceneTree
const Checkpoint = preload("res://scripts/systems/stormworks_checkpoint.gd")
const Route = preload("res://scripts/systems/stormworks_route.gd")
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	var path := "user://stormworks_checkpoint_probe_%d.json" % OS.get_process_id()
	var checks := []
	var initial := Checkpoint.initial()
	checks.append(Checkpoint.decode({"schema":"echo-maintenance-preview-v1","stage":5}) == initial)
	checks.append(Checkpoint.decode({"schema":"echo-maintenance-preview-v1","stage":7}).get("stage") == 7)
	for changes in [{"stage":1.5},{"stage":NAN},{"stage":true},{"stage":8},{"stage":2,"course_step":3},{"stage":4,"course_step":1},{"layout_revision":"future"},{"schema":"unknown"}]:
		var bad := initial.duplicate()
		bad.merge(changes,true)
		checks.append(Checkpoint.decode(bad).is_empty())
	checks.append(Checkpoint.save_checkpoint(initial,path))
	var earned := {"schema":Checkpoint.SCHEMA,"layout_revision":Route.REVISION,"stage":2,"course_step":1}
	checks.append(Checkpoint.save_checkpoint(earned,path))
	checks.append(Checkpoint.load_checkpoint(path) == earned)
	var corrupt := FileAccess.open(path,FileAccess.WRITE)
	corrupt.store_string("{broken");corrupt.close()
	checks.append(Checkpoint.load_checkpoint(path) == initial)
	checks.append(not Checkpoint.save_checkpoint(earned,"user://missing_stormworks_%d/state.json"%OS.get_process_id()))
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
	print("STORMWORKS_CHECKPOINT ","PASS" if checks.all(func(value: bool):return value) else "FAIL"," ",checks.size()," checks")
	quit(0 if checks.all(func(value: bool):return value) else 1)
