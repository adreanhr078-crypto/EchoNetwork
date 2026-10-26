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
	if DisplayServer.get_name()=="headless":push_error("Actual display required");quit(2);return
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
	var before:=_progress()
	var hyper:Node=main.get_node("/root/HyperAnimeWorldManager")
	var diagnostics:={"preset":hyper.preset,"context":hyper._facility_preset_context,"player":str(main.player.global_position),"world_environment":_environment_info(hyper.world_node.environment),"player_camera_environment":_environment_info(main.player.player_camera.environment),"room_omni":[]}
	for light in room.find_children("*","OmniLight3D",true,false):diagnostics.room_omni.append({"position":str(light.position),"color":str(light.light_color),"energy":light.light_energy})
	_write(out.path_join("native-environment-diagnostics.json"),diagnostics)
	var sets:={
		"maintenance":[["entry",Vector3(-3,2.1,-1),Vector3(1,4,-8)],["reverse",Vector3(-.8,7,-12.1),Vector3(1,3,-5)],["lateral",Vector3(-3.6,5.5,-8),Vector3(4,4,-8)],["hero",Vector3(-.4,7.1,-8.4),Vector3(.6,6.55,-12.8)]],
		"security":[["entry",Vector3(-2.6,1.9,-1.3),Vector3(0,2,-12)],["reverse",Vector3(2.8,2.6,-15),Vector3(-.5,1.9,-4)],["lateral",Vector3(-3.4,3.4,-9),Vector3(1,1.5,-9)],["hero",Vector3(1.8,2.1,-12.8),Vector3(0,1.5,-15.9)]],
		"hospital":[["entry",Vector3(2.6,1.65,2.2),Vector3(-1,1,-.6)],["reverse",Vector3(1.3,1.6,1.65),Vector3(-1.5,.9,-.8)],["lateral",Vector3(2.6,1.7,-2.3),Vector3(-1.5,1.2,0)],["hero",Vector3(1.6,1.65,-.7),Vector3(3,1.45,-1.0)]]}
	var camera:=Camera3D.new();camera.fov=65 if id!="hospital" else 58;camera.near=.05
	room.add_child(camera);camera.environment=main.player.player_camera.environment;camera.attributes=main.player.player_camera.attributes;camera.make_current();main.hud.hide()
	var rows:=[]
	for view in sets[id]:
		camera.position=view[1];camera.look_at(room.to_global(view[2]));await _frames(12)
		var query:=PhysicsPointQueryParameters3D.new();query.position=camera.global_position;query.collide_with_areas=false
		var overlaps:=room.get_world_3d().direct_space_state.intersect_point(query)
		await RenderingServer.frame_pre_draw
		for button in root.find_children("*","Button",true,false):
			if button.text.contains("الحالة") or button.text.contains("توقف") or button.text in ["Pause","Status [I]"]:button.hide()
		await RenderingServer.frame_post_draw
		var filename:String=String(view[0])+".png";root.get_texture().get_image().save_png(out.path_join(filename))
		var overlap_nodes:=[]
		for hit in overlaps:overlap_nodes.append(String(hit.collider.get_path()))
		rows.append({"view":view[0],"file":filename,"sha256":FileAccess.get_sha256(out.path_join(filename)),"local_camera":str(camera.position),"local_target":str(view[2]),"solid_overlap_count":overlaps.size(),"overlap_nodes":overlap_nodes})
	if args.has("--diagnose-reflection") and id=="maintenance":
		camera.position=sets[id][0][1];camera.look_at(room.to_global(sets[id][0][2]));await _frames(8)
		var environment:Environment=main.get_node("/root/HyperAnimeWorldManager").world_node.environment
		var ssr_before:bool=environment.ssr_enabled
		var key:DirectionalLight3D=main.get_node("DirectionalLight3D")
		var shadows_before:bool=key.shadow_enabled
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out.path_join("diagnostic-ssr-on.png"))
		environment.ssr_enabled=false;await _frames(4);await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out.path_join("diagnostic-ssr-off.png"))
		environment.ssr_enabled=ssr_before;key.shadow_enabled=false;await _frames(4);await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out.path_join("diagnostic-directional-shadow-off.png"))
		key.shadow_enabled=shadows_before;await _frames(4)
		_write(out.path_join("lighting-diagnostic.json"),{"production_ssr_restored":environment.ssr_enabled==ssr_before,"production_shadows_restored":key.shadow_enabled==shadows_before,"scope":"Three separate diagnostic images only;SSR/shadow-off images are NOT High acceptance. Four normal High views above and production settings remain intact."})
	var hashes:={}
	for source in ["res://tests/remaining_rooms_high_inventory.gd","res://scenes/native_journey.tscn","res://scripts/main.gd","res://engine_visuals/HyperAnimeWorldManager.gd","res://scripts/systems/native_journey_controller.gd","res://scripts/systems/native_campaign_controller.gd"]:hashes[source]=FileAccess.get_sha256(source)
	hashes[room.get_script().resource_path]=FileAccess.get_sha256(room.get_script().resource_path)
	_write(out.path_join("four-high-views.json"),{"room":id,"renderer":RenderingServer.get_current_rendering_method(),"tier":main.get_node("/root/HyperAnimeWorldManager").quality,"framebuffer":[root.size.x,root.size.y],"render_scale":root.scaling_3d_scale,"profile_kind":profile_kind,"source_profile_hashes":source_profile_hashes,"views":rows,"progress_unchanged":before==_progress(),"source_hashes":hashes,"scope":"Actual current native High fixed-camera inventory only. No moving acting,audio,fun,device performance or room/chapter acceptance."})
	main.queue_free();for i in 5:await process_frame
	for path in paths.values():
		for suffix in ["",".bak",".tmp",".bak.tmp"]:
			if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
	print("REMAINING_HIGH_INVENTORY ",id," four actual views")
	quit(0)

func _progress()->String:
	return JSON.stringify({"maintenance":main.get_node("SystemJourneyPreview").stage,"route":main.get_node("NativeJourneyController").progress,"campaign":main.get_node("NativeCampaignController").progress})

func _write(path:String,data:Dictionary)->void:
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(data,"\t"));file.close()

func _environment_info(value:Environment)->Dictionary:
	if value==null:return {"present":false}
	return {"present":true,"ambient_source":value.ambient_light_source,"ambient_color":str(value.ambient_light_color),"ambient_energy":value.ambient_light_energy,"ambient_sky":value.ambient_light_sky_contribution,"background":str(value.background_color),"sky_present":value.sky!=null,"fog":value.volumetric_fog_density,"exposure":value.tonemap_exposure,"saturation":value.adjustment_saturation}
