extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void: _run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok: failures+=1
	print("PASS " if ok else "FAIL ",label)
func frames(count:int) -> void:
	for i in count: await process_frame
func _run() -> void:
	if not "--review-title" in OS.get_cmdline_user_args():
		push_error("This fixture requires --review-title to isolate owner preferences");quit(2);return
	root.unfocusable=true
	var folder:="user://title_review_%d/"%OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var path:=folder+"preferences.cfg"
	var config:=ConfigFile.new()
	config.set_value("presentation","language","en")
	config.set_value("presentation","reduced_motion",true)
	config.set_value("presentation","muted",true)
	check(config.save(path)==OK,"Isolated preference fixture saved")
	var boot=load("res://scripts/boot.gd").new()
	root.add_child(boot);await frames(3)
	check(boot._preferences_path==path,"Actual boot uses the isolated preferences path")
	check(AudioServer.is_bus_mute(0),"Saved mute applies before the first title/film audio")
	check(boot.get_child(0).language=="en" and boot.get_child(0).reduced_motion,"Actual boot restores language and Reduced Motion")
	boot._preferences.set_value("entry","opening_state",{"beat":"reply_safety","asked":["safety"]})
	check(boot._save_entry_preferences(),"Atomic entry cursor update")
	var backup:=ConfigFile.new()
	check(backup.load(path+".bak")==OK and backup.get_value("presentation","muted",false),"Prior valid preference recovery copy retained")
	boot.queue_free();await frames(3)
	config.set_value("presentation","language",7)
	config.set_value("presentation","reduced_motion","invalid")
	config.set_value("presentation","muted","invalid")
	check(config.save(path)==OK,"Malformed typed settings fixture saved")
	boot=load("res://scripts/boot.gd").new()
	root.add_child(boot);await frames(3)
	check(boot.get_child(0).language=="ar" and not boot.get_child(0).reduced_motion,"Malformed types safely fall back without a script error")
	check(AudioServer.is_bus_mute(0),"Malformed mute cannot unexpectedly unmute the user")
	boot.queue_free();await frames(3)
	print("ENTRY_PREFERENCES_REVIEW ",JSON.stringify({"checks":checks,"failures":failures,"status":"PASS" if failures==0 else "FAIL"}))
	quit(1 if failures else 0)
