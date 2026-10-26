extends SceneTree

## Exercise the real shared environment lease with an explicit room-boundary
## fixture. Native public input proves the real campaign separately.
class Body extends CharacterBody3D:
	var reduced_motion:=false
	var combat_available:=false
	var control_locked:=false
	var opening_recovery_active:=false
class Context extends Node:
	var active:=true
	var current:=2
	var rooms:Array[Node3D]=[]
var checks:=0
var failures:=[]
func _initialize()->void:_run.call_deferred()
func _check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _run()->void:
	var out:String=OS.get_cmdline_user_args()[0];DirAccess.make_dir_recursive_absolute(out)
	var hyper:Node=root.get_node("HyperAnimeWorldManager")
	var scene:=Node3D.new();root.add_child(scene)
	var context:=Context.new();context.name="NativeCampaignController";scene.add_child(context)
	for i in 3:
		var room:=Node3D.new();room.position=Vector3(30,0,-100);scene.add_child(room);context.rooms.append(room)
	var body:=Body.new();scene.add_child(body)
	var camera:=Camera3D.new();scene.add_child(camera);camera.make_current()
	var world:=WorldEnvironment.new();world.name="WorldEnvironment";world.environment=Environment.new();scene.add_child(world)
	var original:Environment=world.environment.duplicate(true)
	hyper.attach_scene(scene,body);hyper.set_reduced_motion(true);hyper.set_preset("crimson_overdrive",0)
	var before_time:float=Engine.time_scale
	body.global_position=context.rooms[2].to_global(Vector3(0,-3.9,1))
	hyper._sync_room_environment_context()
	_check(hyper.preset=="crimson_overdrive","Reactor profile leaked into the preceding conduit")
	body.global_position=context.rooms[2].to_global(Vector3(0,-3.9,-2.5));hyper._sync_room_environment_context()
	_check(hyper.preset=="reactor_containment","Physical reactor boundary did not select its shared profile")
	_check(is_equal_approx(world.environment.volumetric_fog_density,.0022) and is_equal_approx(world.environment.glow_intensity,.22),"Reactor profile lost measured fog/bloom")
	_check(is_equal_approx(world.environment.tonemap_exposure,1.18) and is_equal_approx(world.environment.adjustment_saturation,1.38),"Reactor profile replaced the mandatory HDR/chroma pipeline")
	var private_env:=Environment.new();private_env.background_color=Color(.15,.21,.17)
	hyper._lease_environment(private_env);camera.environment=private_env;hyper.environment=private_env
	var private_baseline:Environment=private_env.duplicate(true)
	body.global_position=context.rooms[2].to_global(Vector3(0,.1,-44.5));hyper._sync_room_environment_context()
	_check(hyper.preset=="crimson_overdrive","Reactor exit did not restore the actual prior profile")
	_check(hyper.environment==private_env and is_equal_approx(private_env.volumetric_fog_density,private_baseline.volumetric_fog_density) and private_env.background_color==private_baseline.background_color,"Reactor room context overwrote a private camera environment")
	context.current=1;hyper._sync_room_environment_context()
	_check(hyper.preset=="archive_memory_vault","Archive identity regressed")
	context.current=2;body.global_position=context.rooms[2].to_global(Vector3(0,-3.9,-2.5));hyper._sync_room_environment_context()
	_check(hyper.preset=="reactor_containment" and hyper._preset_before_facility=="crimson_overdrive","Direct archive to reactor replaced the actual restoration baseline")
	hyper.set_reduced_motion(false);body.global_position=context.rooms[2].to_global(Vector3(0,-3.9,1));hyper._sync_room_environment_context()
	paused=true;hyper.set_reduced_motion(true)
	_check(hyper.preset=="crimson_overdrive" and (hyper._preset_tween==null or not hyper._preset_tween.is_valid()),"Live Reduced Motion during exit left its profile tween active")
	_check(is_equal_approx(Engine.time_scale,before_time) and not body.combat_available and not body.control_locked,"Room profile changed time/control/power")
	paused=false;body.global_position=context.rooms[2].to_global(Vector3(0,-3.9,-2.5));hyper._sync_room_environment_context();hyper.detach_scene()
	_check(hyper.preset=="crimson_overdrive" and hyper._facility_preset_context.is_empty(),"Scene detach leaked reactor context")
	_check(world.environment.background_color==original.background_color and is_equal_approx(world.environment.volumetric_fog_density,original.volumetric_fog_density),"Scene detach lost the environment lease")
	var f:=FileAccess.open(out.path_join("reactor-hyper-review.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"scope":"Actual shared Hyper lease with explicit boundary fixture;not art or public campaign acceptance"},"\t"));f.close()
	scene.queue_free();for i in 4:await process_frame
	if not failures.is_empty():quit(1);return
	print("PASS REACTOR_HYPER_PALETTE checks=",checks);quit(0)
