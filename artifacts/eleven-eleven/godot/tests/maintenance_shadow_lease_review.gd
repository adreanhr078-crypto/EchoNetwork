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
	var actor:=Node3D.new();actor.name="EchoPlayer";scene.add_child(actor)
	var actor_mesh:=MeshInstance3D.new();actor_mesh.mesh=BoxMesh.new();actor_mesh.layers=5;actor.add_child(actor_mesh)
	var reserved_mesh:=MeshInstance3D.new();reserved_mesh.mesh=BoxMesh.new();reserved_mesh.layers=1|(1<<17);actor.add_child(reserved_mesh)
	var outside:=MeshInstance3D.new();outside.mesh=BoxMesh.new();outside.layers=1;scene.add_child(outside)
	var original_mask:int=key.shadow_caster_mask
	var room:Node3D=load("res://scenes/environment/maintenance_vertical.tscn").instantiate();scene.add_child(room)
	await _frames(4)
	_check(is_equal_approx(key.light_angular_distance,.35),"Softness leaked before native room presence")
	var room_mesh:GeometryInstance3D=room.find_children("*","GeometryInstance3D",true,false)[0]
	var original_layers:int=room_mesh.layers
	room.presentation.set_presence(true);await _frames(4)
	_check(key.shadow_caster_mask==(1<<17) and (room_mesh.layers&(1<<17))!=0 and actor_mesh.layers==(5|(1<<17)),"Room/actor caster scope failed")
	_check(outside.layers==1,"Room lease changed an outside opening caster")
	var late:=MeshInstance3D.new();late.mesh=BoxMesh.new();late.layers=4;room.add_child(late);await _frames(4)
	_check(late.layers==(4|(1<<17)),"Later room aperture/geometry missed caster ownership")
	late.layers|=1<<15
	_check(is_equal_approx(key.light_angular_distance,1.25),"Native room presence missed soft directional shadows")
	var before_time:float=Engine.time_scale;paused=true;room.set_reduced_motion(true);await _frames(4)
	_check(is_equal_approx(key.light_angular_distance,1.25) and is_equal_approx(Engine.time_scale,before_time),"Pause/ReducedMotion changed shadow lease/time")
	room.presentation.set_presence(false);await _frames(4)
	_check(is_equal_approx(key.light_angular_distance,.35),"Paused native departure failed actual prior-angle restore")
	_check(key.shadow_caster_mask==original_mask and room_mesh.layers==original_layers and actor_mesh.layers==5,"Paused departure leaked mask or room/actor layers")
	_check(late.layers==(4|(1<<15)) and reserved_mesh.layers==(1|(1<<17)),"Layer restore overwrote external or pre-existing flags")
	paused=false;room.presentation.set_presence(true);await _frames(4);key.light_angular_distance=1.7;key.shadow_caster_mask=2;room.presentation.set_presence(false);await _frames(4)
	_check(is_equal_approx(key.light_angular_distance,1.7),"Lease overwrote a newer external light owner")
	_check(key.shadow_caster_mask==2,"Lease overwrote a newer external caster owner")
	room.presentation.set_presence(true);await _frames(4)
	_check(key.shadow_caster_mask==2 and actor_mesh.layers==5,"Lease re-enabled a reserved layer excluded by a prior owner")
	room.presentation.set_presence(false);await _frames(4)
	key.shadow_caster_mask=original_mask
	key.light_angular_distance=.55;room.presentation.set_presence(true);await _frames(4);room.queue_free();await _frames(5)
	_check(is_equal_approx(key.light_angular_distance,.55),"Room teardown leaked its shadow style")
	_check(key.shadow_caster_mask==original_mask and actor_mesh.layers==5 and outside.layers==1,"Teardown leaked mask or actor/outside layers")
	_check(is_equal_approx(Engine.time_scale,before_time),"Static shadow style changed time authority")
	var f:=FileAccess.open(out.path_join("shadow-lease-review.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual key softness+caster-mask/room+actor layers,late geometry,prior restrictions,new external owners,pausedexit and teardown;not art/publicplay/device acceptance"},"\t"));f.close()
	scene.queue_free();await _frames(4)
	if not failures.is_empty():quit(1);return
	print("PASS MAINTENANCE_SHADOW_LEASE checks=",checks);quit(0)
