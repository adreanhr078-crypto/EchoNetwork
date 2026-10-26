extends SceneTree
var checks:=0
var failures:=[]
func _initialize()->void:_run.call_deferred()
func _check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _frames(count:int)->void:
	for i in count:await process_frame
func _run()->void:
	var out:String=OS.get_cmdline_user_args()[0];DirAccess.make_dir_recursive_absolute(out)
	var scene:=Node3D.new();root.add_child(scene)
	var key:=DirectionalLight3D.new();key.name="DirectionalLight3D";key.light_angular_distance=.35;scene.add_child(key)
	var room:Node3D=load("res://scenes/environment/maintenance_vertical.tscn").instantiate();scene.add_child(room)
	await _frames(4)
	_check(is_equal_approx(key.light_angular_distance,.35),"Softness leaked before native room presence")
	room.presentation.set_presence(true);await _frames(4)
	_check(is_equal_approx(key.light_angular_distance,1.25),"Native room presence missed soft directional shadows")
	var before_time:float=Engine.time_scale;paused=true;room.set_reduced_motion(true);await _frames(4)
	_check(is_equal_approx(key.light_angular_distance,1.25) and is_equal_approx(Engine.time_scale,before_time),"Pause/ReducedMotion changed shadow lease/time")
	room.presentation.set_presence(false);await _frames(4)
	_check(is_equal_approx(key.light_angular_distance,.35),"Paused native departure failed actual prior-angle restore")
	paused=false;room.presentation.set_presence(true);await _frames(4);key.light_angular_distance=1.7;room.presentation.set_presence(false);await _frames(4)
	_check(is_equal_approx(key.light_angular_distance,1.7),"Lease overwrote a newer external light owner")
	key.light_angular_distance=.55;room.presentation.set_presence(true);await _frames(4);room.queue_free();await _frames(5)
	_check(is_equal_approx(key.light_angular_distance,.55),"Room teardown leaked its shadow style")
	_check(is_equal_approx(Engine.time_scale,before_time),"Static shadow style changed time authority")
	var f:=FileAccess.open(out.path_join("shadow-lease-review.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual DirectionalLight3D property lease/restoration,external-owner,pausedexit and teardown;not art/publicplay/device acceptance"},"\t"));f.close()
	scene.queue_free();await _frames(4)
	if not failures.is_empty():quit(1);return
	print("PASS MAINTENANCE_SHADOW_LEASE checks=",checks);quit(0)
