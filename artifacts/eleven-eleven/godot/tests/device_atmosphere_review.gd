extends SceneTree

## Native isolated effects and invariant review; no campaign progress is granted.
var checks:=[]
func _initialize()->void:_run.call_deferred()
func _frames(count:int)->void:
	for i in count:await process_frame;await physics_frame
func _check(label:String,value:bool)->void:
	checks.append({"check":label,"pass":value});print("DEVICE_ATMOSPHERE ",label," ",value)
func _run()->void:
	var args:=OS.get_cmdline_user_args()
	if args.size()<2:quit(2);return
	create_timer(120).timeout.connect(func():push_error("Device review watchdog");quit(1))
	var role:String=args[0];var folder:String=args[1];DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,720);root.unfocusable=true
	var files:={"security":"security_checkpoint_room","specimen":"specimen_containment_wing","archive":"memory_archive_wing","reactor":"core_reactor_room"}
	var room:Node3D=load("res://scenes/environment/"+files[role]+".tscn").instantiate();root.add_child(room)
	room.set_physics_process(false)
	var reference:=CharacterBody3D.new();room.add_child(reference)
	var camera:=Camera3D.new();camera.fov=65;camera.near=.08;room.add_child(camera);camera.make_current()
	var manager:Node=root.get_node("HyperAnimeWorldManager");manager.attach_scene(room,reference);manager.set_quality("high")
	var effect:Node=room.get_node("PhysicalDeviceAtmosphere")
	var collision_count:int=room.find_children("*","CollisionShape3D",true,false).size()
	var state:Dictionary=room.get_state().duplicate(true)
	await _frames(12)
	var start:Dictionary=effect.get_effect_evidence();await _frames(6)
	_check("visible_room_advances_local_air_"+role,effect.elapsed>start.clock and effect.get_effect_evidence().motion)
	_check("physical_air_has_no_gameplay_solids_"+role,effect.find_children("*","CollisionObject3D",true,false).is_empty())
	_check("bounded_transparent_air_"+role,start.particle_budget<=60 and start.transparent_tail)
	paused=true;start=effect.get_effect_evidence();await _frames(3)
	_check("pause_holds_air_and_rotor_"+role,effect.elapsed==start.clock and effect.get_effect_evidence().rotor_angles==start.rotor_angles and effect.get_effect_evidence().air_stopped)
	room.reduced_motion=true;paused=false;await _frames(4);start=effect.get_effect_evidence();await _frames(4)
	_check("reduced_motion_holds_local_air_"+role,effect.elapsed==start.clock and start.air_stopped)
	room.reduced_motion=false;await _frames(4)
	manager.set_quality("low");await _frames(3)
	_check("low_tier_reduces_particle_count_"+role,is_equal_approx(effect.get_effect_evidence().air_ratio,.25))
	manager.set_quality("high");await _frames(3)
	if role=="reactor":
		room.breaker_a_done=true;room.breaker_b_done=true;await _frames(3)
		_check("native_isolation_reduces_cooling",is_equal_approx(effect.get_effect_evidence().air_ratio,.4))
		room.breaker_a_done=false;room.breaker_b_done=false
	room.visible=false;await _frames(3);start=effect.get_effect_evidence();await _frames(3)
	_check("hidden_room_holds_air_"+role,start.air_stopped and effect.elapsed==start.clock)
	room.visible=true;await _frames(4)
	_check("original_state_and_colliders_retained_"+role,room.get_state()==state and room.find_children("*","CollisionShape3D",true,false).size()==collision_count)
	var views:={
		"security":[["entry",Vector3(0,1.8,-1),Vector3(0,2,-11)],["vent",Vector3(-1.8,2.3,-6.9),Vector3(-4.16,3.3,-8.6)]],
		"specimen":[["entry",Vector3(-2.5,1.8,2),Vector3(-15,2,-6)],["condensation",Vector3(-5.8,3.4,2.8),Vector3(-8,4.3,-.8)]],
		"archive":[["entry",Vector3(-2,1.8,0),Vector3(-12,2.6,0)],["extraction",Vector3(-3,3.2,-2.6),Vector3(-6,3.75,-5.94)]],
		"reactor":[["entry",Vector3(0,-2.1,-2.5),Vector3(0,-.5,-22)],["cooling",Vector3(-8,2.6,-17),Vector3(-4.52,1.8,-22)]]}
	for view in views[role]:
		camera.position=view[1];camera.look_at(view[2]);await _frames(10)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder.path_join(view[0]+".png"))
	var hashes:={}
	for path in ["res://scripts/environment/room_device_atmosphere.gd","res://shaders/physical_air.gdshader","res://scripts/environment/"+files[role]+".gd"]:hashes[path]=FileAccess.get_sha256(path)
	var report:={"checks":checks,"effects":effect.get_effect_evidence(),"source_hashes":hashes,"renderer":RenderingServer.get_current_rendering_method(),"tier":manager.quality,"device":RenderingServer.get_video_adapter_name(),"scope":"Isolated native room/effect lifecycle and two views;real public contacts and campaign reviewed separately"}
	var file:=FileAccess.open(folder.path_join("review.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	var passed:bool=checks.all(func(row:Dictionary):return row.pass)
	manager.detach_scene();room.queue_free();for i in 5:await process_frame
	quit(0 if passed else 1)
