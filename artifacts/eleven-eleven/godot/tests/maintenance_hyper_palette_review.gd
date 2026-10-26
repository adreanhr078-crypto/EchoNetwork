extends SceneTree

## Measured room-boundary fixture for the shared environment lease.
## Actual player input and native images are checked separately.
class Body extends CharacterBody3D:
	var reduced_motion:=false
	var combat_available:=false
	var control_locked:=false
	var opening_recovery_active:=false
class Context extends Node:
	var active:=false
	var current:=0
class Maintenance extends Node:
	var room:Node3D
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
	var maintenance:=Maintenance.new();maintenance.name="SystemJourneyPreview";scene.add_child(maintenance)
	maintenance.room=Node3D.new();maintenance.room.position=Vector3(0,0,-18);scene.add_child(maintenance.room)
	var body:=Body.new();scene.add_child(body)
	var camera:=Camera3D.new();scene.add_child(camera);camera.make_current()
	var world:=WorldEnvironment.new();world.name="WorldEnvironment";world.environment=Environment.new();scene.add_child(world)
	var original:Environment=world.environment.duplicate(true)
	hyper.attach_scene(scene,body);hyper.set_reduced_motion(true);hyper.set_preset("crimson_overdrive",0)
	var before_time:float=Engine.time_scale
	body.global_position=maintenance.room.to_global(Vector3(0,.1,1));hyper._sync_room_environment_context()
	_check(hyper.preset=="crimson_overdrive","Maintenance profile leaked into opening")
	body.global_position=maintenance.room.to_global(Vector3(0,.1,-1));hyper._sync_room_environment_context()
	_check(hyper.preset=="maintenance_pressure_bay","Physical maintenance boundary missed its profile")
	_check(is_equal_approx(world.environment.volumetric_fog_density,.0018) and is_equal_approx(world.environment.glow_intensity,.18),"Maintenance fog/bloom changed")
	_check(is_equal_approx(world.environment.tonemap_exposure,1.18) and is_equal_approx(world.environment.adjustment_saturation,1.38),"Maintenance replaced mandatory HDR/chroma")
	body.global_position=maintenance.room.to_global(Vector3(5.5,.1,-1));hyper._sync_room_environment_context()
	_check(hyper.preset=="crimson_overdrive","Maintenance profile leaked across side boundary")
	body.global_position=maintenance.room.to_global(Vector3(0,5.4,-12));hyper._sync_room_environment_context()
	var private_env:=Environment.new();private_env.background_color=Color(.15,.21,.17)
	hyper._lease_environment(private_env);camera.environment=private_env;hyper.environment=private_env
	var private_baseline:Environment=private_env.duplicate(true)
	body.global_position=maintenance.room.to_global(Vector3(0,5.4,-14.8));hyper._sync_room_environment_context()
	_check(hyper.preset=="crimson_overdrive","Maintenance exit failed actual prior-preset restore")
	_check(hyper.environment==private_env and is_equal_approx(private_env.volumetric_fog_density,private_baseline.volumetric_fog_density) and private_env.background_color==private_baseline.background_color,"Maintenance overwrote private camera environment")
	body.global_position=maintenance.room.to_global(Vector3(0,.1,-1));context.active=true;context.current=1;hyper._sync_room_environment_context()
	_check(hyper.preset=="archive_memory_vault","Active archive was overridden by dormant maintenance room")
	context.active=false;hyper._sync_room_environment_context()
	_check(hyper.preset=="maintenance_pressure_bay" and hyper._preset_before_facility=="crimson_overdrive","Direct facility transition lost actual restoration baseline")
	hyper.set_reduced_motion(false);body.global_position=maintenance.room.to_global(Vector3(0,5.4,-15));hyper._sync_room_environment_context()
	paused=true;hyper.set_reduced_motion(true)
	_check(hyper.preset=="crimson_overdrive" and (hyper._preset_tween==null or not hyper._preset_tween.is_valid()),"Live Reduced Motion left exit tween active")
	_check(is_equal_approx(Engine.time_scale,before_time) and not body.combat_available and not body.control_locked,"Maintenance profile changed time/control/power")
	paused=false;body.global_position=maintenance.room.to_global(Vector3(0,.1,-1));hyper._sync_room_environment_context();hyper.detach_scene()
	_check(hyper.preset=="crimson_overdrive" and hyper._facility_preset_context.is_empty(),"Scene detach leaked maintenance context")
	_check(world.environment.background_color==original.background_color and is_equal_approx(world.environment.volumetric_fog_density,original.volumetric_fog_density),"Scene detach lost environment lease")
	var f:=FileAccess.open(out.path_join("maintenance-hyper-review.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"scope":"Shared Hyper environment lease and explicit room boundaries;not public play/art acceptance"},"\t"));f.close()
	scene.queue_free();for i in 4:await process_frame
	if not failures.is_empty():quit(1);return
	print("PASS MAINTENANCE_HYPER_PALETTE checks=",checks);quit(0)
