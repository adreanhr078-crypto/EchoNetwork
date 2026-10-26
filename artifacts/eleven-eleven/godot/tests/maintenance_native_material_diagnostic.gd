extends SceneTree

## Current native scene inventory. Maintenance/security use declared validated
## cold profiles. Ward reloads an actual earned completed profile. Fixed
## diagnostic cameras and one explicit actor anchor never prove public play.
const Saves=preload("res://scripts/systems/save_manager.gd")
const Journey=preload("res://scripts/systems/native_journey_checkpoint.gd")
const Campaign=preload("res://scripts/systems/native_campaign_checkpoint.gd")
var main:Node3D
var base:String
var out:String

func _initialize()->void:_run.call_deferred()
func _frames(count:int)->void:
	for i in count:
		if paused:main.native_pause_menu.resume_button.pressed.emit()
		await process_frame;await physics_frame

func _run()->void:
	var args:=OS.get_cmdline_user_args()
	if args.size()<2:push_error("room and absolute evidence folder required");quit(2);return
	var id:String=args[0];out=args[1];DirAccess.make_dir_recursive_absolute(out)
	if not id in ["maintenance","security","hospital"]:push_error("Unsupported inventory room");quit(2);return
	base="user://remaining_high_%d"%OS.get_process_id()
	var paths:={"opening.json":base+"_opening.json","maintenance.json":base+"_maintenance.json","route.json":base+"_route.json","campaign.json":base+"_campaign.json","preferences.cfg":base+"_preferences.cfg"}
	var profile_kind:="validated cold profile;one explicit actor anchor"
	var source_profile_hashes:={}
	if id=="hospital":
		if args.size()<3:push_error("Actual earned profile required for ward");quit(2);return
		profile_kind="actual earned completed profile reloaded;diagnostic camera only"
		for filename in paths:
			var source:String=String(args[2]).path_join(filename)
			if DirAccess.copy_absolute(source,paths[filename])!=OK:push_error("Earned profile copy failed");quit(2);return
			source_profile_hashes[filename]=FileAccess.get_sha256(source)
	else:
		Saves.save_opening_checkpoint({"schema":Saves.OPENING_SCHEMA,"milestones":{"wake":true,"clock":true,"photo":true,"memory":true,"terminal":true,"conduit":true,"ending":true},"terminal":{"frequency":111.0,"phase":45.0,"harmonic":7.0}},paths["opening.json"])
		_write(paths["maintenance.json"],{"schema":"echo-maintenance-preview-v1","stage":0 if id=="maintenance" else 7})
		var completed:Array=["opening_completed"] if id=="maintenance" else ["opening_completed","maintenance_completed","security_entered"]
		Journey.save_checkpoint({"schema":Journey.SCHEMA,"completed":completed,"security":Journey.SECURITY_INITIAL},paths["route.json"])
		Campaign.save_checkpoint(Campaign.initial(),paths["campaign.json"])
	main=load("res://scenes/native_journey.tscn").instantiate()
	main.native_checkpoint_path=paths["opening.json"];main.native_preferences_path=paths["preferences.cfg"]
	main.get_node("SystemJourneyPreview").checkpoint_path=paths["maintenance.json"]
	main.get_node("NativeJourneyController").checkpoint_path=paths["route.json"]
	main.get_node("NativeCampaignController").checkpoint_path=paths["campaign.json"]
	root.unfocusable=true;root.size=Vector2i(1280,720);root.add_child(main)
	await _frames(35);main.set_visual_quality("high");main.set_reduced_motion(false);main.set_audio_muted(true)
	var room:Node3D
	if id=="maintenance":room=main.get_node("SystemJourneyPreview").room
	elif id=="security":room=main.get_node("NativeJourneyController").security
	else:room=main.get_node("NativeCampaignController").hospital
	if not is_instance_valid(room):push_error("Native room did not activate");quit(2);return
	if id!="hospital":
		main.player.global_position=room.to_global(Vector3(-3,.1,-1.0) if id=="maintenance" else Vector3(-2.6,.1,-1.4))
		main.player.velocity=Vector3.ZERO
	main.player.set_mobile_input_vector(Vector2.ZERO,false)
	await _frames(12)
	var rows:=[]
	for visual in main.find_children("*","MeshInstance3D",true,false):
		if visual.global_position.z> -18 or visual.global_position.z< -33:continue
		var materials:=[]
		for surface in visual.mesh.get_surface_count():
			var mat:Material=visual.get_active_material(surface)
			var row:={"name":mat.resource_name,"type":mat.get_class()}
			if mat is ShaderMaterial:
				row.shader=mat.shader.resource_path;row.tint=str(mat.get_shader_parameter("tint"));row.albedo=str(mat.get_shader_parameter("albedo_color"));row.source_saturation=str(mat.get_shader_parameter("source_saturation"));row.replacement_count=str(mat.get_shader_parameter("replacement_count"))
			materials.append(row)
		rows.append({"node":str(visual.get_path()),"visible":visual.is_visible_in_tree(),"global_position":str(visual.global_position),"bounds":str(visual.global_transform*visual.mesh.get_aabb()),"materials":materials})
	_write(out.path_join("native-material-diagnostics.json"),{"finishes":room.presentation._finishes.size(),"rows":rows})
	main.queue_free();for i in 5:await process_frame
	for path in paths.values():
		for suffix in ["",".bak",".tmp",".bak.tmp"]:
			if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
	quit(0)

func _write(path:String,data:Dictionary)->void:
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(data,"\t"));file.close()
