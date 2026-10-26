extends "res://tests/opening_player_journey_review.gd"

## A declared completed-opening fixture,then public02 climb/gap/wheel/input.
## Never claim a fresh chapter or final animation acceptance from this pilot.
const Saves=preload("res://scripts/systems/save_manager.gd")
const Journey=preload("res://scripts/systems/native_journey_checkpoint.gd")
const Campaign=preload("res://scripts/systems/native_campaign_checkpoint.gd")
var paths:={}
var samples:=[]
var capture_start:=0
var starting_retry_count:=0
var input_resets:=[]
var prior_preset:=""
var prior_fog:=Color.WHITE
var actual_capsule_width:=0.0
var prior_key_angle:=0.0

func _walk(target:Vector3)->bool:
	# The legacy helper's second-wall approach is30cm beyond the original
	# GapLanding's north edge(-26.2world). Stop on its real support and jump.
	if target.is_equal_approx(Vector3(4,3.4,-26.5)):target=Vector3(4,3.4,-26.0)
	return await super._walk(target)

func _check(ok:bool,message:String)->bool:
	if not ok and not folder.is_empty():
		_write(folder.path_join("failed-route-review.json"),{"failure":message,"samples":samples,"input_resets":input_resets,"scope":"Failed diagnostic retained;not route acceptance"})
	return super._check(ok,message)

func _run()->void:
	if DisplayServer.get_name()=="headless":push_error("Actual rendered player review required");quit(2);return
	folder=OS.get_cmdline_user_args()[0]+"/";DirAccess.make_dir_recursive_absolute(folder)
	var prefix:="user://maintenance_mechanical_public_%d_"%OS.get_process_id()
	for filename in ["opening.json","maintenance.json","route.json","campaign.json","preferences.cfg"]:paths[filename]=prefix+filename
	Saves.save_opening_checkpoint({"schema":Saves.OPENING_SCHEMA,"milestones":{"wake":true,"clock":true,"photo":true,"memory":true,"terminal":true,"conduit":true,"ending":true},"terminal":{"frequency":111.0,"phase":45.0,"harmonic":7.0}},paths["opening.json"])
	_write(paths["maintenance.json"],{"schema":"echo-maintenance-preview-v1","stage":0})
	Journey.save_checkpoint({"schema":Journey.SCHEMA,"completed":["opening_completed"],"security":Journey.SECURITY_INITIAL},paths["route.json"])
	Campaign.save_checkpoint(Campaign.initial(),paths["campaign.json"])
	main=load("res://scenes/native_journey.tscn").instantiate()
	main.native_checkpoint_path=paths["opening.json"];main.native_preferences_path=paths["preferences.cfg"]
	main.get_node("SystemJourneyPreview").checkpoint_path=paths["maintenance.json"]
	main.get_node("NativeJourneyController").checkpoint_path=paths["route.json"]
	main.get_node("NativeCampaignController").checkpoint_path=paths["campaign.json"]
	root.size=Vector2i(1280,720);root.unfocusable=true;root.add_child(main)
	player=main.player;player.set_process_unhandled_input(false)
	main.hud.find_child("MobileTouchControls",true,false).input_reset.connect(func():
		if input_resets.size()<100:input_resets.append({"physics_frame":Engine.get_physics_frames(),"position":str(player.global_position),"owned":player.mobile_move_owned,"input":str(player.resolve_movement_input()),"paused":paused,"stack":get_stack()}))
	await _frames(40);_drain_dialogue();player.finish_opening_recovery()
	main.set_visual_quality("high");main.set_reduced_motion(false);main.set_audio_muted(true)
	var director:Node=main.get_node("SystemJourneyPreview")
	if not _check(is_instance_valid(director.room) and director.stage==0,"Validated initial maintenance fixture unavailable"):return
	var hyper:Node=main.get_node("/root/HyperAnimeWorldManager")
	prior_key_angle=main.get_node("DirectionalLight3D").light_angular_distance
	prior_preset=hyper._preset_before_facility if not hyper._facility_preset_context.is_empty() else hyper.preset
	prior_fog=hyper._height_fog_before_facility if not hyper._facility_preset_context.is_empty() else hyper.height_fog.material.albedo
	actual_capsule_width=player.get_node("CollisionShape3D").shape.radius*2
	var gasket:Node3D=director.room.get_node("MaintenanceMechanicalDressing/PrecisionFixedDoorGasketAdapters")
	if not _check(actual_capsule_width>float(gasket.get_meta("old_side_gap_width")),"Fixed visual gasket occupies a traversable native side gap"):return
	# The ONLY explicit actor anchor. No transforms/grants after traversal begins.
	player.global_position=director.room.to_global(Vector3(0,.1,-1));player.velocity=Vector3.ZERO
	player.set_gameplay_orbit(Vector3.ZERO);await _frames(12)
	if not _check(hyper.preset=="maintenance_pressure_bay" and hyper._facility_preset_context=="maintenance_pressure_bay","Actual room entry missed the maintenance profile"):return
	if not _check(main.get_node("DirectionalLight3D").light_angular_distance>=1.25,"Actual maintenance entry missed its soft-shadow lease"):return
	capture_start=Time.get_ticks_usec();await _capture("entry")
	if not await _maintenance_route():return
	await _frames(48)
	if not _check(hyper._facility_preset_context.is_empty() and hyper.preset==prior_preset and hyper.height_fog.material.albedo.is_equal_approx(prior_fog),"Actual security handoff leaked maintenance lighting context"):return
	if not _check(is_equal_approx(main.get_node("DirectionalLight3D").light_angular_distance,prior_key_angle),"Actual security handoff leaked maintenance shadow softness"):return
	if not _check(player.player_camera.current and not player.control_locked and player.is_on_floor() and not player.combat_available,"Security handoff lost camera/control/floor/noearlypower"):return
	if not _check(director.room.service_open and director.room._gate_collider.disabled,"Actual wheel/gate state missing"):return
	var portal:Node3D=director.room.get_node("MaintenanceMechanicalDressing/MeasuredActualSecurityPortalBackSkins")
	if not _check(portal.get_meta("native_portal_volumes").size()==4,"Connected portal skins lack four actual native portal/ceiling support volumes"):return
	var earned:=folder.path_join("earned");DirAccess.make_dir_recursive_absolute(earned)
	var hashes:={}
	for filename in paths:
		if DirAccess.copy_absolute(paths[filename],earned.path_join(filename))!=OK:push_error("Earned native profile copy failed");quit(1);return
		hashes[filename]=FileAccess.get_sha256(earned.path_join(filename))
	_write(folder.path_join("public-route-review.json"),{"checks":checks,"samples":samples,"earned_profile_hashes":hashes,"actual_profile_restored":hyper.preset==prior_preset,"prior_preset":prior_preset,"actual_capsule_width":actual_capsule_width,"actual_key_angle_restored":is_equal_approx(main.get_node("DirectionalLight3D").light_angular_distance,prior_key_angle),"gasket_clearance_already_untraversable":actual_capsule_width>.625,"renderer":RenderingServer.get_current_rendering_method(),"tier":main.get_node("/root/HyperAnimeWorldManager").quality,"reduced_motion":main.reduced_motion,"camera_current":player.player_camera.current,"control_locked":player.control_locked,"no_pre_pact_power":not player.combat_available,"solid_floor":player.is_on_floor(),"stage":director.stage,"scope":"Declared completed-opening cold fixture+singleinitialspawn,then public02 two climbs/gap/pressurewheel/physicalsecurityhandoff;actual images/moving samples,not finalhandart/audio/fun/fullchapter/deviceacceptance"})
	# Correct the older inherited helper's broad label for this declared fixture.
	var inherited_report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"maintenance.json"))
	inherited_report.route="Declared completed-opening fixture,then actual public02 input;not from waking"
	_write(folder+"maintenance.json",inherited_report)
	main.queue_free();for i in 5:await process_frame
	for path in paths.values():
		for suffix in ["",".bak",".tmp",".bak.tmp"]:
			if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
	print("PASS MAINTENANCE_PUBLIC_HIGH checks=",checks," images=",samples.size());quit(0)

func _capture(label:String)->void:
	await RenderingServer.frame_post_draw
	var filename:="public-%03d.png"%samples.size()
	root.get_texture().get_image().save_png(folder+filename)
	samples.append({"file":filename,"label":label,"wall_seconds":float(Time.get_ticks_usec()-capture_start)/1000000.0,"physics_frame":Engine.get_physics_frames(),"position":str(player.global_position),"camera":str(player.player_camera.global_transform),"stage":main.get_node("SystemJourneyPreview").stage,"hanging":player.surface_motor.hanging,"climbing":player.traversal.is_climbing(),"floor":player.is_on_floor(),"stamina":player.stamina,"camera_current":player.player_camera.current,"control_locked":player.control_locked,"resolved_input":str(player.resolve_movement_input()),"mobile_owned":player.mobile_move_owned,"velocity":str(player.velocity),"wall_normal":str(player.traversal.wall_normal),"contact_body":str(player.surface_motor._contact_body.get_path()) if is_instance_valid(player.surface_motor._contact_body) else "","catch_correction":player.surface_motor.last_catch_correction,"hyper_preset":main.get_node("/root/HyperAnimeWorldManager").preset})
	_write(folder.path_join("capture-trace.json"),{"samples":samples,"input_resets":input_resets})

func _climb_and_mantle(id:String)->bool:
	player.set_mobile_input_vector(Vector2.ZERO,false)
	for frame in 240:
		_resume()
		if player.stamina>=60:break
		await physics_frame
	player.set_mobile_input_vector(Vector2(0,-1),true);player.request_jump()
	for frame in 180:
		_resume();player.set_mobile_input_vector(Vector2(0,-1),true);await physics_frame
		if frame%6==0:await _capture(id+"-climb-%03d"%frame)
		if player.surface_motor.hanging:break
	if not _check(player.surface_motor.hanging,"Actual climb failed to reach ledge:"+id):return false
	await _capture(id+"-hang");player.request_jump()
	for frame in 140:
		_resume();player.set_mobile_input_vector(Vector2(0,-1),true);await physics_frame
		if frame%6==0:await _capture(id+"-mantle-%03d"%frame)
		if not player.traversal.is_climbing():break
	player.set_mobile_input_vector(Vector2.ZERO,false);await _frames(16);await _capture(id+"-landed")
	return _check(player.is_on_floor(),"Actual mantle failed to land:"+id)

func _write(path:String,data:Dictionary)->void:
	var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(data,"\t"));f.close()
