extends SceneTree

## Reload the actual five-file profile earned by public04→05 traversal.
## No synthetic completion flags,actor reposition or contract power grant.
func _initialize()->void:_run.call_deferred()
func _run()->void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=2:push_error("Actual earned folder and output folder required");quit(2);return
	var input:String=args[0];var out:String=args[1];DirAccess.make_dir_recursive_absolute(out)
	var prefix:="user://archive_earned_reload_%d"%OS.get_process_id()
	var paths:={};var hashes:={}
	for filename in ["opening.json","maintenance.json","route.json","campaign.json","preferences.cfg"]:
		var source:String=input.path_join(filename);var target:String=prefix+"_"+filename
		if DirAccess.copy_absolute(source,target)!=OK:push_error("Could not copy actual earned file:"+filename);quit(2);return
		paths[filename]=target;hashes[filename]=FileAccess.get_sha256(source)
	var expected:Dictionary=preload("res://scripts/systems/native_campaign_checkpoint.gd").load_checkpoint(paths["campaign.json"])
	if expected.get("completed",[])!=["specimen","archive"]:push_error("Source was not the actual two-room earned profile");quit(2);return
	var main:Node3D=load("res://scenes/native_journey.tscn").instantiate()
	main.native_checkpoint_path=paths["opening.json"];main.native_preferences_path=paths["preferences.cfg"]
	main.get_node("SystemJourneyPreview").checkpoint_path=paths["maintenance.json"]
	main.get_node("NativeJourneyController").checkpoint_path=paths["route.json"]
	main.get_node("NativeCampaignController").checkpoint_path=paths["campaign.json"]
	root.unfocusable=true;root.add_child(main)
	for i in 40:await process_frame;await physics_frame
	var campaign:Node=main.get_node("NativeCampaignController");var archive:Node3D=campaign.rooms[1]
	var same:bool=campaign.progress==expected
	var restored:bool=archive.collected_shards.size()==3 and archive.archive_decoded and archive.gate_open
	var safe:bool=main.player.player_camera.current and not main.player.control_locked and not main.player.combat_available
	var silent:bool=not archive._memory_sound.playing
	var source_unchanged:=true
	for filename in hashes:source_unchanged=source_unchanged and FileAccess.get_sha256(input.path_join(filename))==hashes[filename]
	var passed:bool=same and restored and safe and silent and source_unchanged and campaign.current==2
	var file:=FileAccess.open(out.path_join("earned-reload-review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"campaign_exact":same,"native_archive_restored":restored,"camera_control_no_power":safe,"silent_restore":silent,"current":campaign.current,"source_hashes":hashes,"source_unchanged":source_unchanged,"scope":"Actual earned profile copied then cold native headless reload;state/ownership proof only,no visual/performance/fun acceptance"},"\t"));file.close()
	main.queue_free();for i in 5:await process_frame
	for path in paths.values():
		for suffix in ["",".bak",".tmp",".bak.tmp"]:
			if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
	if not passed:push_error("Actual earned archive cold reload failed");quit(1);return
	print("PASS ARCHIVE_ACTUAL_EARNED_RELOAD exact flags,3memories,decoder/gate,camera/control,no power,silent restore");quit(0)
