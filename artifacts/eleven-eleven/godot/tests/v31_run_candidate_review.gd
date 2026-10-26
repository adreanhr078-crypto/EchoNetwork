extends SceneTree

## Test-only candidate injection into the real current player. No story grant,
## source resource overwrite, gameplay teleport or production alias change.
var main: Node
var player: EchoPlayer
var checks:=0
var failures:=0
var folder:String
var contacts:Array=[]
var sources:Dictionary={}
var leg_index:=0
var walk_mode:=false
func _initialize() -> void: _run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok: failures+=1
	print("PASS " if ok else "FAIL ",label)
func frames(count:int) -> void:
	for i in count:
		if paused: main.native_pause_menu.resume_button.pressed.emit()
		await process_frame
func capture(label:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+label+".png")
func travel(target:Vector3) -> Dictionary:
	var distance:=0.0
	var samples:=0
	var speed_errors:Array=[]
	var previous:Vector3=player.global_position
	for frame in 600:
		if paused: main.native_pause_menu.resume_button.pressed.emit()
		var offset:=target-player.global_position;offset.y=0
		if offset.length()<.22: break
		var forward:Vector3=-player.player_camera.global_basis.z;forward.y=0
		var right:Vector3=player.player_camera.global_basis.x;right.y=0
		var movement:=Vector2(offset.dot(right.normalized()),-offset.dot(forward.normalized())).normalized()
		var magnitude:float=(.45 if offset.length()>1.0 else .3) if walk_mode else (1.0 if offset.length()>1.0 else .6)
		player.set_mobile_input_vector(movement*magnitude,true)
		await physics_frame
		distance+=player.global_position.distance_to(previous);previous=player.global_position;samples+=1
		if player.current_anim==("WALK" if walk_mode else "RUN") and Vector2(player.velocity.x,player.velocity.z).length()>(.8 if walk_mode else 4.4):
			var ground_speed:float=(0.6715578558998432 if walk_mode else 1.8332634866237643)*1.83
			speed_errors.append(absf(player.animation_player.speed_scale*ground_speed-Vector2(player.velocity.x,player.velocity.z).length()))
		if frame in [17,33,49,65]: await capture("public-run-%d-%d"%[leg_index,frame])
	player.set_mobile_input_vector(Vector2.ZERO,false)
	leg_index+=1
	var remaining:=target-player.global_position;remaining.y=0
	return {"reached":remaining.length()<.25,"travel_m":distance,"physics_samples":samples,"speed_errors":speed_errors}
func _run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()<2: push_error("Expected candidate library and evidence directory");quit(2);return
	walk_mode=args.size()>2 and args[2]=="walk"
	folder=args[1]
	DirAccess.make_dir_recursive_absolute(folder)
	root.unfocusable=true
	root.size=Vector2i(1280,720)
	root.content_scale_size=root.size
	var base:="user://run_candidate_%d/"%OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(base)
	main=load("res://scenes/native_journey.tscn").instantiate()
	main.opening_transfer_presented=true
	main.native_checkpoint_path=base+"opening.json";main.native_preferences_path=base+"prefs.cfg"
	main.get_node("SystemJourneyPreview").checkpoint_path=base+"maintenance.json"
	main.get_node("NativeJourneyController").checkpoint_path=base+"route.json"
	main.get_node("NativeCampaignController").checkpoint_path=base+"campaign.json"
	root.add_child(main);await frames(8)
	main.set_audio_muted(true);main.set_reduced_motion(false);main.set_visual_quality("low")
	player=main.player
	if player.opening_recovery_active: player.finish_opening_recovery()
	if main.opening_cinematic: main.opening_cinematic.finish()
	var dialogue=main.hud.find_child("DialogueOverlay",true,false)
	while dialogue.is_active: dialogue.advance_dialogue()
	await frames(4)
	var avatar:Node3D=player.get_node("ModelRoot/EchoOpeningUniform")
	var mixer:AnimationPlayer=player.animation_player
	var candidate:=load(args[0]) as AnimationLibrary
	if not candidate: push_error("Candidate library unavailable");quit(2);return
	var clip:Animation=candidate.get_animation("Walk_Source_Retarget" if walk_mode else "Run_Source_Retarget").duplicate()
	var animation_root:Node=mixer.get_node(mixer.root_node)
	for track in clip.get_track_count():
		if not animation_root.get_node_or_null(NodePath(clip.track_get_path(track).get_concatenated_names())):
			push_error("Candidate path cannot resolve on actual current V31: "+str(clip.track_get_path(track)));quit(2);return
	clip.loop_mode=Animation.LOOP_LINEAR
	mixer.stop()
	var library:AnimationLibrary=mixer.get_animation_library("")
	var alias:="WALK" if walk_mode else "RUN"
	library.remove_animation(alias);library.add_animation(alias,clip)
	check(clip.get_meta("source_take_id","")==("cca789212f4a334b9ec9309a:0:5173144e" if walk_mode else "c1ed64d6c975194967304af7:0:13373cc7"),"Actual alias retains exact qualified source identity")
	check(clip.get_track_count()==60,"Current rig resolves every candidate track")
	player.footstep_system.footstep_triggered.connect(func(left:bool,surface:String,is_run:bool,point:Vector3):
		if is_run!=walk_mode:
			contacts.append({"left":left,"surface":surface,"phase":fposmod(mixer.current_animation_position/mixer.current_animation_length,1.0),"point":[point.x,point.y,point.z]})
	)
	var start:Vector3=player.global_position
	var legs:Array=[]
	var distance:=3.0 if walk_mode else 6.0
	player.set_gameplay_orbit(Vector3(.06,0,0))
	legs.append(await travel(start+Vector3(0,0,-distance)))
	player.set_gameplay_orbit(Vector3(.06,PI*.5,0))
	legs.append(await travel(start))
	player.set_gameplay_orbit(Vector3(.06,PI,0))
	legs.append(await travel(start+Vector3(0,0,-distance)))
	check(legs[0].reached and legs[1].reached and legs[2].reached,"Real public input runs, turns and returns without teleport")
	check(legs[0].travel_m+legs[1].travel_m>(5.0 if walk_mode else 10.5),"Actual capsule travelled the intended route")
	var rate_samples:=0
	var largest_error:=0.0
	for leg in legs:
		for error in leg.speed_errors: rate_samples+=1;largest_error=maxf(largest_error,error)
	check(rate_samples>10 and largest_error<.12,"Source cadence follows measured world travel rather than the old Jog speed")
	check(contacts.size()>=4,"Real foot contacts drive sound/garment events")
	var max_phase_error:=0.0
	for contact in contacts:
		var expected:float=(.25 if contact.left else .75) if walk_mode else (16.0/26.0 if contact.left else 3.0/26.0)
		max_phase_error=maxf(max_phase_error,fposmod(contact.phase-expected,1.0))
	check(max_phase_error<.13,"Foot events follow this source's actual contact phases")
	player.request_jump()
	var airborne:=false
	var landed:=false
	for i in 180:
		await physics_frame
		if not player.is_on_floor(): airborne=true
		if airborne and player.is_on_floor(): landed=true;break
	check(airborne and landed,"Public jump returns to a grounded current player")
	await frames(3)
	check(not player.combat_available and not player.contract_with_zero_sealed and not main.companion.visible,"Locomotion grants no early power or follower")
	var saved:Dictionary=main.capture_native_checkpoint()
	check(main.save_native_checkpoint_now() and main.restore_native_checkpoint(saved),"Actual local save/restore remains valid with the candidate")
	await frames(3)
	check(not player.control_locked and player.player_camera.current,"Save/restore returns gameplay camera and control")
	var cape:Node=avatar.find_child("EchoCapeMotion",true,false)
	main.set_reduced_motion(true);await frames(3)
	check(cape._angles.count(0.0)==15,"Reduced Motion settles all dedicated cape chains")
	var file:=FileAccess.open(folder+"/review.json",FileAccess.WRITE)
	var report:Dictionary={"status":"PASS" if failures==0 else "FAIL","checks":checks,"failures":failures,"source_library_sha256":FileAccess.get_sha256(args[0]),"legs":legs,"contacts":contacts,"maximum_contact_phase_error":max_phase_error,"rate_samples":rate_samples,"maximum_speed_mapping_error_mps":largest_error,"renderer":RenderingServer.get_current_rendering_method(),"capture_scope":"Actual public-input motion, turn, jump and restoration; not complete chapter or performance acceptance","whole_character_accepted":false}
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("V31_LOCOMOTION_CANDIDATE ",report.status," checks=",checks," failures=",failures," contact_error=",max_phase_error," speed_error=",largest_error)
	main.queue_free();await frames(3)
	quit(1 if failures else 0)
