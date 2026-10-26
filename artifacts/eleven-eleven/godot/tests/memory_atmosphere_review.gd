extends SceneTree
var main:Node3D
var director:Node
var checks:=0
var folder:="res://../audits/evidence/memory-atmosphere-cp42-20261020/"
var profile:Dictionary={}
func _initialize() -> void:_run.call_deferred()
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:push_error(message);quit(1);assert(ok,message)
func wait_real(seconds:float) -> void:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:await process_frame
func capture(id:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+id+".png")
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence="):folder=arg.trim_prefix("--evidence=")+"/"
	folder=ProjectSettings.globalize_path(folder)
	DirAccess.make_dir_recursive_absolute(folder)
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	main=load("res://scenes/native_journey.tscn").instantiate()
	main.native_checkpoint_path="user://memory42-opening.json"
	main.native_preferences_path="user://memory42.cfg"
	main.get_node("SystemJourneyPreview").checkpoint_path="user://memory42-maintenance.json"
	main.get_node("NativeJourneyController").checkpoint_path="user://memory42-route.json"
	main.get_node("NativeCampaignController").checkpoint_path="user://memory42-campaign.json"
	root.add_child(main)
	await wait_real(0.4)
	main.player.finish_opening_recovery()
	var dialogue=main.hud.find_child("DialogueOverlay",true,false)
	while dialogue.is_active:dialogue.advance_dialogue()
	main.native_pause_menu.resume_button.pressed.emit()
	main.player.set_process_unhandled_input(false)
	director=main.get_node_or_null("MemoryAtmosphereDirector")
	check(director!=null,"Native journey missing memory integration")
	main.set_reduced_motion(false)
	main.set_visual_quality("high")
	main.set_audio_muted(true)
	await wait_real(1.0)
	check(director.active_room=="opening","Opening atmosphere not selected")
	check(director.decoder_count()==1,"Opening must share one city decoder")
	check(director.rooms.opening.screens.size()==1,"Unexpected opening screen count")
	var surface:MeshInstance3D=director.rooms.opening.screens[0].get_meta("surface")
	check(surface.mesh is QuadMesh and director.rooms.opening.screens[0].get_child_count()==1,"Memory must be one complete frameless moving image")
	await capture("room01-entry")
	if OS.get_cmdline_user_args().has("--profile"): await _profile_atmosphere()
	await _continue_review()
func _continue_review() -> void:
	main.player.set_process(false)
	main.player.set_physics_process(false)
	var monitor:Node3D=director.rooms.opening.screens[0]
	var camera:=Camera3D.new()
	main.add_child(camera)
	camera.fov=65
	camera.make_current()
	_frame_monitor(camera,monitor)
	await wait_real(0.4)
	await capture("room01-moving-memory-and-water")
	if OS.get_cmdline_user_args().has("--record-memory"):
		main.set_visual_quality("low")
		await wait_real(0.3)
		var frame_folder:=folder+"preview-frames/"
		DirAccess.make_dir_recursive_absolute(frame_folder)
		var timings:Array[float]=[]
		var started:=Time.get_ticks_usec()
		for i in 120:
			await RenderingServer.frame_post_draw
			timings.append(float(Time.get_ticks_usec()-started)/1000000.0)
			root.get_texture().get_image().save_jpg(frame_folder+"%04d.jpg"%i,0.85)
		FileAccess.open(frame_folder+"timings.json",FileAccess.WRITE).store_string(JSON.stringify(timings))
		main.set_visual_quality("high")
		await wait_real(0.3)
	var video:VideoStreamPlayer=director.sources.city.video
	var before:float=video.stream_position
	var first_hash:=""
	if DisplayServer.get_name()!="headless":first_hash=video.get_video_texture().get_image().get_data().hex_encode().sha256_text()
	await wait_real(0.65)
	check(video.stream_position>before+0.3,"Shared off-screen player stopped decoding")
	if DisplayServer.get_name()!="headless":check(first_hash!=video.get_video_texture().get_image().get_data().hex_encode().sha256_text(),"Video texture is a still image")
	var puddle:MeshInstance3D=director.rooms.opening.puddles[0]
	check(director.contains_water(puddle.global_position),"Shallow water has no wet footstep recognition")
	check(not director.contains_water(puddle.global_position+Vector3.UP),"Water affected elevated traversal")
	check(not director.contains_water(Vector3.ZERO),"Wetness leaked into the dry central route")
	var footsteps=main.player.find_child("EchoFootstepSystem",true,false)
	check(footsteps._detect_surface(puddle.global_position)=="water","Footstep foley ignored the visible water")
	var cursor:int=director._ripple_cursor
	footsteps.footstep_triggered.emit(true,"water",false,puddle.global_position)
	check(director._ripple_cursor==(cursor+1)%4,"Real contact signal failed to feed water ripples")
	main.player.global_position=Vector3(monitor.global_position.x,0,monitor.global_position.z)+monitor.global_basis.z*2.0
	main.player.control_locked=false
	main.set_audio_muted(false)
	await wait_real(0.8)
	check(director.audible_gain>0.1 and director.screen_audio.playing,"Nearby moving memory remained silent")
	check(director.screen_audio.global_position.is_equal_approx(monitor.global_position) and is_equal_approx(director.screen_audio.max_distance,5.0),"Memory audio lost its physical source/radius")
	main.player.global_position=Vector3(0,0,3)
	await wait_real(0.8)
	check(is_zero_approx(director.audible_gain) and not director.screen_audio.playing,"Memory sound leaked beyond proximity")
	main.set_audio_muted(true)
	main.set_reduced_motion(true)
	await wait_real(0.2)
	var world=root.get_node("HyperAnimeWorldManager")
	var frozen_world:float=world.visual_time
	var frozen:float=video.stream_position
	await wait_real(0.3)
	check(absf(video.stream_position-frozen)<0.02,"Reduced Motion continued video animation")
	check(is_equal_approx(world.visual_time,frozen_world),"Reduced Motion retained drifting panes/water animation")
	check(not director.rooms.opening.drops[0].visible,"Reduced Motion retained falling droplets")
	await capture("room01-reduced-motion")
	paused=true
	await wait_real(0.3)
	check(video.paused and not director.screen_audio.playing,"Pause retained moving or audible memory")
	var paused_world:float=world.visual_time
	await wait_real(0.15)
	check(is_equal_approx(world.visual_time,paused_world),"Paused water/pane clocks continued")
	paused=false
	main.set_reduced_motion(false)
	await wait_real(0.2)
	check(not video.paused,"Memory did not resume after pause")
	main.set_audio_muted(false)
	main.player.global_position=Vector3(monitor.global_position.x,0,monitor.global_position.z)+monitor.global_basis.z*2.0
	await wait_real(0.65)
	check(director.screen_audio.playing,"Memory sound did not return on reapproach")
	main.set_audio_muted(true)
	await process_frame
	check(not director.screen_audio.playing and not director.drip_audio.playing,"Live mute left an environmental source playing")
	# The following are clearly staged render fixtures on the actual room scenes;
	# the separate full_chapter_journey_review proves earned public-input progression.
	var maintenance=main.get_node("SystemJourneyPreview")
	var route=main.get_node("NativeJourneyController")
	var campaign=main.get_node("NativeCampaignController")
	for controller in [maintenance,route,campaign]:
		controller.set_process(false)
		controller.set_physics_process(false)
	var room02:Node3D=load("res://scenes/environment/maintenance_vertical.tscn").instantiate()
	room02.position=Vector3(0,0,-18)
	main.add_child(room02)
	maintenance.room=room02
	director._register_room("maintenance",room02)
	main.player.global_position=Vector3(0,0,-20)
	await wait_real(0.2)
	check(director.active_room=="maintenance" and not director.rooms.opening.holder.visible,"Opening bled into maintenance")
	_frame_monitor(camera,director.rooms.maintenance.screens[0])
	await capture("room02-moving-memory-and-leak")
	if OS.get_cmdline_user_args().has("--profile"): await _profile_atmosphere("room02")
	var room03:Node3D=load("res://scenes/environment/security_checkpoint_room.tscn").instantiate()
	room03.position=Vector3(0,5.4,-32)
	main.add_child(room03)
	route.security=room03
	route.security_entered=true
	director._register_room("security",room03)
	main.player.global_position=Vector3(0,5.4,-34)
	await wait_real(0.25)
	_frame_monitor(camera,director.rooms.security.screens[0])
	await capture("room03-moving-memory-and-leak")
	if OS.get_cmdline_user_args().has("--profile"): await _profile_atmosphere("room03")
	var ids=["specimen","archive","reactor","decon","mirror"]
	var paths=["specimen_containment_wing","memory_archive_wing","core_reactor_room","decontamination_quarantine_wing","mirror_chamber_room"]
	for i in ids.size():
		var room:Node3D=load("res://scenes/environment/"+paths[i]+".tscn").instantiate()
		room.position=campaign.ORIGINS[i]
		main.add_child(room)
		room.set_process(false)
		room.set_physics_process(false)
		campaign.rooms.append(room)
		director._register_room(ids[i],room)
		campaign.active=true
		campaign.current=i
		main.player.global_position=room.to_global(campaign.ANCHORS[i])
		await wait_real(0.3)
		check(director.active_room==ids[i],"Wrong active campaign memory room: "+ids[i])
		_frame_monitor(camera,director.rooms[ids[i]].screens[0])
		await capture("room%02d-memory"%(i+4))
	check(director.decoder_count()==2,"Mirror pair failed bounded two-memory playback")
	for data in director.rooms.values():
		for pane in data.screens:
			var intact:MeshInstance3D=pane.get_meta("surface")
			check(intact.mesh is QuadMesh and pane.get_child_count()==1,"A room reintroduced cut-up images or monitor hardware")
	main.set_visual_quality("low")
	await wait_real(0.4)
	check(director.decoder_count()==1 and director.sources.reel.video.stream.resource_path.ends_with("reel-low.ogv"),"Low tier did not preserve both scenes in one decoder")
	check(director.sources.city.video.is_playing()==false and director.sources.friends.video.is_playing()==false,"Low retained unused High decoders")
	await capture("room08-low-memory")
	campaign.current=5
	await wait_real(0.2)
	check(director.decoder_count()==0,"Inactive memories kept decoding in laboratory/hospital")
	check(not director.contains_water(puddle.global_position),"An inactive room retained wetness")
	var own_viewports:int=director.find_children("*","SubViewport",true,false).size()
	for data in director.rooms.values():own_viewports+=data.holder.find_children("*","SubViewport",true,false).size()
	check(own_viewports==0,"Environmental monitors allocated per-screen render viewports")
	check(is_equal_approx(director.proximity_gain(5.0),0) and is_equal_approx(director.proximity_gain(0.5),1),"Proximity envelope lost its near/far bounds")
	check(director._screen_count==10 and director.rooms.size()==8,"Unexpected unbounded monitor growth")
	var report={"status":"PASS","checks":checks,"renderer":RenderingServer.get_current_rendering_method(),"scope":"Actual runtime integration fixture; progression and independent art acceptance tested separately","profile":profile}
	FileAccess.open(folder+"memory-review.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("MEMORY_ATMOSPHERE_REVIEW ",JSON.stringify(report))
	main.queue_free()
	await process_frame
	quit()

func _profile_atmosphere(room_id: String="room01") -> void:
	# Interleave OFF/ON samples at one unchanged viewpoint and tier. This isolates
	# atmosphere overhead, not GPU timing or target-device/chapter acceptance.
	var samples:Dictionary={}
	for tier in ["high","low"]:
		main.set_visual_quality(tier)
		for enabled in [false,true]:
			director.set_process(enabled)
			if not enabled:
				for data in director.rooms.values(): data.holder.hide()
				for source in director.sources.values(): source.video.paused=true
			for i in 20: await process_frame
			var durations:Array[float]=[]
			var last:=Time.get_ticks_usec()
			for i in 90:
				await process_frame
				var now:=Time.get_ticks_usec()
				durations.append(float(now-last)/1000.0)
				last=now
			durations.sort()
			samples[tier+("_on" if enabled else "_off")]={"p50_ms":durations[45],"p95_ms":durations[85],"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"engine_texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"decoders":director.decoder_count(),"sample_count":90}
	profile[room_id]=samples
	main.set_visual_quality("high")
	director.set_process(true)
	await wait_real(0.2)
func _frame_monitor(camera:Camera3D,monitor:Node3D) -> void:
	camera.global_position=monitor.global_position+monitor.global_basis.z*4.5+monitor.global_basis.x*0.45+Vector3.UP*0.35
	camera.look_at(monitor.global_position-Vector3.UP*0.35)
