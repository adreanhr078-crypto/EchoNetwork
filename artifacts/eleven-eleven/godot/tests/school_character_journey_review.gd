extends "res://tests/stormworks_full_chapter_review.gd"
## Fresh opening/public journey, with current Room02 support and held-input driver.
var character_trace: Array = []

func _check(ok: bool,message: String) -> bool:
	if not ok and not folder.is_empty():
		var room=main.get_node("SystemJourneyPreview").room
		var rows:=[]
		if is_instance_valid(room):
			for child in room.get_children():
				rows.append({"name":child.name,"class":child.get_class(),"groups":child.get_groups(),"position":str(child.global_position) if child is Node3D else ""})
			print("SCHOOL_ROOM_DIAGNOSTIC ",JSON.stringify({"scene":room.scene_file_path,"inside_tree":room.is_inside_tree(),"position":str(room.global_position),"child_count":rows.size()}))
		var file:=FileAccess.open(folder.path_join("school-failed-trace.json"),FileAccess.WRITE)
		if file: file.store_string(JSON.stringify({"failure":message,"trace":character_trace,"current_course":parkour.report if parkour else {}},"\t"));file.close()
	return super._check(ok,message)

func _continue_review() -> bool:
	var stage5:=folder.path_join("earned/room02-stage5")
	DirAccess.copy_absolute(REVIEW_SAVES[0],stage5.path_join("opening.json"))
	var earned:=folder.path_join("earned-profile")
	DirAccess.make_dir_recursive_absolute(earned)
	var names:=["opening.json","preferences.cfg","maintenance.json","route.json","campaign.json"]
	var hashes:={}
	for i in REVIEW_SAVES.size():
		if names[i]=="campaign.json" and not FileAccess.file_exists(REVIEW_SAVES[i]):
			var initial_campaign=preload("res://scripts/systems/native_campaign_checkpoint.gd").initial()
			if not _check(main.get_node("NativeCampaignController").progress==initial_campaign,"Missing campaign file was not its valid initial state"): return false
			hashes[names[i]]="ABSENT_VALID_INITIAL_STATE"
			continue
		if not _check(DirAccess.copy_absolute(REVIEW_SAVES[i],earned.path_join(names[i]))==OK,"Actual earned file unavailable: "+names[i]): return false
		hashes[names[i]]=FileAccess.get_sha256(earned.path_join(names[i]))
	var data:={"status":"PASS_PUBLIC_INPUT_ROUTE","physics_hz":Engine.physics_ticks_per_second,"checks":checks,"avatar":"School65 candidate","trace":character_trace,"current_course":parkour.report if parkour else {},"earned_profile":earned,"earned_hashes":hashes,"source_hashes":{}}
	for path in ["scripts/player/echo_player.gd","scripts/player/echo_school_motion_adapter.gd","scripts/player/echo_rig_profile.gd","scripts/player/surface_traversal_motor.gd","assets/characters/echo_school65_candidate.glb","tests/school_character_journey_review.gd","tests/opening_player_journey_review.gd","tests/stormworks_full_chapter_review.gd","tests/stormworks_course_pilot.gd","scenes/native_journey.tscn","scenes/characters/echo_school_candidate.tscn","scenes/environment/maintenance_stormworks.tscn","scripts/environment/maintenance_stormworks.gd","scripts/systems/stormworks_journey_preview.gd","scripts/systems/stormworks_route.gd"]:
		data.source_hashes[path]=FileAccess.get_sha256("res://"+path)
	for motion in ["idle","walk","run","jump","hang","mantle","stand","roll","wake"]:
		var path: String = "assets/animations/school65/"+motion+"_qualified.res"
		data.source_hashes[path]=FileAccess.get_sha256("res://"+path)
	for path in ["engine_visuals/MemoryAtmosphereDirector.gd","engine_visuals/shaders/memory_monitor.gdshader","engine_visuals/camera/DynamicActionCameraRig.gd"]:
		data.source_hashes[path]=FileAccess.get_sha256("res://"+path)
	data.opening_recovery_scope="Qualified native24Hz Wake with measured skin grounding" if OS.get_cmdline_user_args().has("--full-recovery") else "Recovery may be skipped by fixture"
	var file:=FileAccess.open(folder.path_join("school-journey.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"\t"));file.close()
	return true
