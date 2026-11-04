extends "res://tests/stormworks_parkour_input_review.gd"

## Actual public motor/animation contacts beside existing cabinets and racks.
func _record(label:String,value:bool,detail:Variant=null)->void:
	report.checks.append({"check":label,"pass":value,"detail":detail});print("DEVICE_PLAYER ",label," ",value)
func _run()->void:
	var args:=OS.get_cmdline_user_args()
	if args.size()<2:quit(2);return
	var role:String=args[0];var folder:String=args[1]
	if role not in ["security","archive"] or DirAccess.dir_exists_absolute(folder):quit(2);return
	DirAccess.make_dir_recursive_absolute(folder);capture_directory=folder.path_join("frames");DirAccess.make_dir_recursive_absolute(capture_directory)
	create_timer(150).timeout.connect(func():push_error("Device public-contact watchdog");quit(1))
	root.size=Vector2i(1280,720);root.unfocusable=true
	world=Node3D.new();root.add_child(world)
	room=load("res://scenes/environment/"+("security_checkpoint_room" if role=="security" else "memory_archive_wing")+".tscn").instantiate();world.add_child(room)
	player=load("res://scenes/player/echo_player.tscn").instantiate();player.position=Vector3(-3.5,.1,-1.8) if role=="security" else Vector3(-2,.1,0);world.add_child(player)
	player.finish_opening_recovery();room.player=player
	var manager:Node=root.get_node("HyperAnimeWorldManager");manager.attach_scene(world,player);manager.set_quality("high")
	await _frames(20)
	var effect:Node=room.get_node("PhysicalDeviceAtmosphere")
	var before:Dictionary=effect.get_effect_evidence()
	var targets:=[Vector3(-3.5,0,-3.8),Vector3(-3.5,0,-5.8)] if role=="security" else [Vector3(-2,0,-4.9),Vector3(-4,0,-4.9),Vector3(-6,0,-4.9)]
	var walked:=true
	for target in targets:
		if not await _go_to(target):walked=false;break
	_aim(Vector3(-4.15,3.3,-8.6) if role=="security" else Vector3(-6,3.75,-5.94));await _frames(8);await _capture("actual-contact-"+role)
	_record("public_grounded_walk_"+role,walked and player.is_on_floor(),str(_pos()))
	_record("real_animation_contact_emitted_local_dust_"+role,effect.get_effect_evidence().dust_contacts>before.dust_contacts,effect.get_effect_evidence())
	_record("single_contact_connection_"+role,effect.get_effect_evidence().contact_connections==1)
	_record("no_gate_or_power_granted_"+role,not room.gate_open and not player.combat_available)
	var count:int=effect.get_effect_evidence().dust_contacts
	room.reduced_motion=true;await _frames(3)
	player.set_mobile_input_vector(Vector2(.2,0),true);await _frames(18);player.set_mobile_input_vector(Vector2.ZERO,false)
	_record("reduced_motion_walk_suppresses_dust_"+role,effect.get_effect_evidence().dust_contacts==count)
	var hashes:={}
	for path in ["res://scripts/environment/room_device_atmosphere.gd","res://shaders/physical_air.gdshader"]:hashes[path]=FileAccess.get_sha256(path)
	report.status="PASS_SCOPED_NATIVE" if report.checks.all(func(row:Dictionary):return row.pass) else "FAIL"
	report.source_hashes=hashes;report.renderer=RenderingServer.get_current_rendering_method();report.device=RenderingServer.get_video_adapter_name();report.scope="Isolated actual motor and animation contact near native cabinets/racks;not complete puzzle/campaign,art,performance or fun acceptance"
	var file:=FileAccess.open(folder.path_join("review.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	manager.detach_scene();world.queue_free();for i in 6:await process_frame
	quit(0 if report.status!="FAIL" else 1)
