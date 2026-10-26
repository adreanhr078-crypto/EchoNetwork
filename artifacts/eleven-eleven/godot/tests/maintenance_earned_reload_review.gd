extends SceneTree

## Cold native reload of the actual five public-input earned files.
## No direct progression writes;only PID-specific disposable copies.
func _initialize()->void:_run.call_deferred()
func _run()->void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=2:push_error("Actual earned profile folder and output required");quit(2);return
	var source:String=args[0];var out:String=args[1];DirAccess.make_dir_recursive_absolute(out)
	var prefix:="user://maintenance_earned_reload_%d_"%OS.get_process_id()
	var paths:={};var hashes:={}
	for name in ["opening.json","maintenance.json","route.json","campaign.json","preferences.cfg"]:
		if DirAccess.copy_absolute(source.path_join(name),prefix+name)!=OK:push_error("Actual earned file missing:"+name);quit(2);return
		paths[name]=prefix+name;hashes[name]=FileAccess.get_sha256(source.path_join(name))
	var expected:Dictionary=preload("res://scripts/systems/native_journey_checkpoint.gd").load_checkpoint(paths["route.json"])
	var expected_campaign:Dictionary=preload("res://scripts/systems/native_campaign_checkpoint.gd").load_checkpoint(paths["campaign.json"])
	if expected.completed!=["opening_completed","maintenance_completed","security_entered"]:push_error("Source is not the actual public-earned maintenance handoff");quit(2);return
	var main:Node3D=load("res://scenes/native_journey.tscn").instantiate()
	main.native_checkpoint_path=paths["opening.json"];main.native_preferences_path=paths["preferences.cfg"]
	main.get_node("SystemJourneyPreview").checkpoint_path=paths["maintenance.json"]
	main.get_node("NativeJourneyController").checkpoint_path=paths["route.json"]
	main.get_node("NativeCampaignController").checkpoint_path=paths["campaign.json"]
	root.unfocusable=true;root.add_child(main)
	for i in 40:
		if paused:main.native_pause_menu.resume_button.pressed.emit()
		await process_frame;await physics_frame
	var journey:Node=main.get_node("NativeJourneyController");var director:Node=main.get_node("SystemJourneyPreview");var room:Node3D=director.room
	var exact:bool=journey.progress==expected and journey.security_entered and director.stage==7 and director._read(paths["maintenance.json"])==7 and main.get_node("NativeCampaignController").progress==expected_campaign
	var restored:bool=room.service_open and not room.service_opening and room._gate_collider.disabled and is_equal_approx(room._gate.position.y,room._closed_gate.y+2.1) and room._valve.rotation.is_equal_approx(room._closed_valve)
	var safe:bool=main.player.player_camera.current and not main.player.control_locked and not main.player.combat_available and not main.player.contract_with_zero_sealed and not main.player._camera_suspended and not director.service_cinematic.active and main.player.is_on_floor()
	var silent:bool=not room._release_audio.playing and not room.presentation._vent.emitting and not room.presentation._inside_room
	var aperture:bool=room.presentation._aperture_open and room.get_node("COLL_FarBoundary").get_child(0).disabled and room.presentation.find_children("CampaignAperture*","MeshInstance3D",false,false).size()==3
	var unchanged:=true
	for name in hashes:unchanged=unchanged and FileAccess.get_sha256(source.path_join(name))==hashes[name]
	var passed:bool=exact and restored and safe and silent and aperture and unchanged
	var file:=FileAccess.open(out.path_join("earned-reload-review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"route_campaign_exact":exact,"native_gate_valve_restored":restored,"camera_control_floor_no_power":safe,"silent_restore":silent,"single_native_campaign_aperture":aperture,"source_unchanged":unchanged,"source_hashes":hashes,"native_player_position":str(main.player.global_position),"hyper_preset":root.get_node("HyperAnimeWorldManager").preset,"scope":"Cold reload of actual public-earned files;native truth and ownership only,not art/device/fun acceptance"},"\t"));file.close()
	main.queue_free();for i in 5:await process_frame
	for path in paths.values():
		for extra in ["",".bak",".tmp",".bak.tmp"]:
			if FileAccess.file_exists(path+extra):DirAccess.remove_absolute(path+extra)
	if not passed:push_error("Actual earned maintenance reload/ownership failed");quit(1);return
	print("PASS MAINTENANCE_ACTUAL_EARNED_RELOAD exactflags/gate/valve/camera/floor/noearlypower/silent/aperture");quit(0)
