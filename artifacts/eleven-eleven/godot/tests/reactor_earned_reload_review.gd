extends SceneTree

## Cold native load of the actual five-file public-input earned profile.
## The old completed reactor is inactive but its instrument must be correct.
func _initialize()->void:_run.call_deferred()
func _run()->void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=2:push_error("Actual earned profile folder and output required");quit(2);return
	var source:String=args[0];var out:String=args[1];DirAccess.make_dir_recursive_absolute(out)
	var prefix:="user://reactor_earned_reload_%d_"%OS.get_process_id()
	var paths:={};var hashes:={}
	for name in ["opening.json","maintenance.json","route.json","campaign.json","preferences.cfg"]:
		if DirAccess.copy_absolute(source.path_join(name),prefix+name)!=OK:push_error("Actual earned file missing:"+name);quit(2);return
		paths[name]=prefix+name;hashes[name]=FileAccess.get_sha256(source.path_join(name))
	var expected:Dictionary=preload("res://scripts/systems/native_campaign_checkpoint.gd").load_checkpoint(paths["campaign.json"])
	if expected.completed!=["specimen","archive","reactor"]:push_error("Source is not the actual three-room earned profile");quit(2);return
	var main:Node3D=load("res://scenes/native_journey.tscn").instantiate()
	main.native_checkpoint_path=paths["opening.json"];main.native_preferences_path=paths["preferences.cfg"]
	main.get_node("SystemJourneyPreview").checkpoint_path=paths["maintenance.json"]
	main.get_node("NativeJourneyController").checkpoint_path=paths["route.json"]
	main.get_node("NativeCampaignController").checkpoint_path=paths["campaign.json"]
	root.unfocusable=true;root.add_child(main)
	for i in 40:await process_frame;await physics_frame
	var campaign:Node=main.get_node("NativeCampaignController");var reactor:Node3D=campaign.rooms[2]
	var exact:bool=campaign.progress==expected and campaign.current==3
	var restored:bool=reactor.breaker_a_done and reactor.breaker_b_done and reactor.bridge_extended and reactor.gate_open and reactor._gate_shape.disabled and is_equal_approx(reactor._hydraulic_bridge.position.y,0.0) and is_equal_approx(reactor._gate.position.y,4.8)
	var instruments:=true
	for console in [reactor._breaker_a_console,reactor._breaker_b_console]:
		var readout:MeshInstance3D=console.find_child("NativeReactorCircuitReadout",true,false)
		instruments=instruments and readout!=null and is_equal_approx(float(readout.material_override.get_shader_parameter("relay_a")),1) and is_equal_approx(float(readout.material_override.get_shader_parameter("relay_b")),1)
	var safe:bool=main.player.player_camera.current and not main.player.control_locked and not main.player.combat_available
	var silent:bool=not reactor._bridge_sound.playing and not reactor._breaker_sound.playing
	var unchanged:=true
	for name in hashes:unchanged=unchanged and FileAccess.get_sha256(source.path_join(name))==hashes[name]
	var passed:bool=exact and restored and instruments and safe and silent and unchanged
	var file:=FileAccess.open(out.path_join("earned-reload-review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"campaign_exact":exact,"reactor_restored":restored,"inactive_instruments_synchronous":instruments,"camera_control_no_power":safe,"silent_restore":silent,"source_unchanged":unchanged,"source_hashes":hashes,"scope":"Cold reload of actual public earned files;native state/ownership/readout proof only,not art/device/fun acceptance"},"\t"));file.close()
	main.queue_free();for i in 5:await process_frame
	for path in paths.values():
		for extra in ["",".bak",".tmp",".bak.tmp"]:
			if FileAccess.file_exists(path+extra):DirAccess.remove_absolute(path+extra)
	if not passed:push_error("Actual earned reactor reload/readout ownership failed");quit(1);return
	print("PASS REACTOR_ACTUAL_EARNED_RELOAD exactflags/inactiveinstruments/camera/noearlypower/silent");quit(0)
