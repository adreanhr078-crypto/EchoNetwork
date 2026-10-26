extends SceneTree

## Actual shared Hyper environment/scene leases with an explicit context
## fixture. No game progression is simulated or accepted by this test.
class Body extends CharacterBody3D:
	var reduced_motion:=false
	var combat_available:=false
	var control_locked:=false
	var opening_recovery_active:=false
class Context extends Node:
	var active:=true
	var current:=0
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
	var body:=Body.new();scene.add_child(body)
	var camera:=Camera3D.new();scene.add_child(camera);camera.make_current()
	var world:=WorldEnvironment.new();world.name="WorldEnvironment";world.environment=Environment.new();scene.add_child(world)
	var original:Environment=world.environment.duplicate(true)
	hyper.attach_scene(scene,body);hyper.set_reduced_motion(true)
	hyper.set_preset("crimson_overdrive",0)
	var before_time:float=Engine.time_scale
	context.current=1;hyper._sync_room_environment_context()
	_check(hyper.preset=="archive_memory_vault","Archive context did not select its shared Hyper profile")
	_check(is_equal_approx(world.environment.volumetric_fog_density,.0028) and is_equal_approx(world.environment.glow_intensity,.28),"Archive fog/bloom reference was not applied")
	_check(is_equal_approx(world.environment.tonemap_exposure,1.18) and is_equal_approx(world.environment.adjustment_saturation,1.38),"Archive style replaced the required shared HDR/chroma pipeline")
	# The existing renderer is allowed its normal initial camera lease. Capture
	# that baseline before testing the new room profile's ownership boundary.
	var private_env:=Environment.new();private_env.background_color=Color(.15,.21,.17)
	private_env.volumetric_fog_density=.071;private_env.glow_intensity=1.9
	hyper._lease_environment(private_env);camera.environment=private_env;hyper.environment=private_env
	var private_baseline:Environment=private_env.duplicate(true)
	context.current=2;hyper._sync_room_environment_context()
	_check(hyper.preset=="crimson_overdrive" and is_equal_approx(world.environment.volumetric_fog_density,.008),"Leaving archive did not restore the previous actual preset")
	_check(hyper.environment==private_env and private_env.background_color==private_baseline.background_color and is_equal_approx(private_env.volumetric_fog_density,private_baseline.volumetric_fog_density) and is_equal_approx(private_env.glow_intensity,private_baseline.glow_intensity),"Facility room profile overwrote a cinematic/ward camera environment")
	hyper.set_reduced_motion(false);context.current=1;hyper._sync_room_environment_context()
	paused=true;hyper.set_reduced_motion(true)
	_check(is_equal_approx(world.environment.volumetric_fog_density,.0028) and (hyper._preset_tween==null or not hyper._preset_tween.is_valid()),"Live Reduced Motion while paused stranded the archive colour tween")
	_check(is_equal_approx(Engine.time_scale,before_time) and not body.combat_available and not body.control_locked,"Room style changed time,control or power")
	paused=false;hyper.detach_scene()
	_check(hyper.preset=="crimson_overdrive" and not hyper._archive_context,"Scene detach leaked archive style into the next scene")
	_check(world.environment.background_color==original.background_color and is_equal_approx(world.environment.volumetric_fog_density,original.volumetric_fog_density),"Scene detach did not restore its original environment lease")
	var f:=FileAccess.open(out.path_join("hyper-palette-review.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"scope":"Actual shared Hyper context/camera lease/RM/pause/restore fixture;not rendered art or chapter acceptance"},"\t"));f.close()
	scene.queue_free();for i in 4:await process_frame
	if not failures.is_empty():quit(1);return
	print("PASS ARCHIVE_HYPER_PALETTE checks=",checks," private camera lease/RM/pause/preset restoration retained");quit(0)
