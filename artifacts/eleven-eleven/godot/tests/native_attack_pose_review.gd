extends "res://tests/echo_short_jacket_review.gd"

## Opt-in source qualification on the actual avatar and built weapon socket.
## The candidate library is supplied explicitly; production aliases are untouched.
func _run() -> void:
	var args:=OS.get_cmdline_user_args()
	check(args.size()==2,"Expected qualified standalone library and capture folder")
	folder=args[1]
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,720)
	root.content_scale_size=root.size
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	var main=load("res://scenes/native_journey.tscn").instantiate()
	main.native_checkpoint_path="user://cp45_attack_review_opening.json"
	main.native_preferences_path="user://cp45_attack_review.cfg"
	main.get_node("SystemJourneyPreview").checkpoint_path="user://cp45_attack_review_maintenance.json"
	main.get_node("NativeJourneyController").checkpoint_path="user://cp45_attack_review_route.json"
	main.get_node("NativeCampaignController").checkpoint_path="user://cp45_attack_review_campaign.json"
	root.add_child(main)
	main.set_audio_muted(true)
	main.set_visual_quality("low")
	for frame in 5:await process_frame
	var player: EchoPlayer=main.player
	player.finish_opening_recovery()
	var dialogue=main.hud.find_child("DialogueOverlay",true,false)
	while dialogue.is_active:dialogue.advance_dialogue()
	main.native_pause_menu.resume_button.pressed.emit()
	main.hud.visible=false
	player.control_locked=false
	player.set_physics_process(false)
	player.set_process(false)
	player.set_process_unhandled_input(false)
	player.set_combat_available(true) # Isolated asset fixture, never a story decision.
	player.unsheath_weapon()
	var avatar:Node3D=player.get_node("ModelRoot/EchoOpeningUniform")
	var rig:Skeleton3D=avatar.find_child("Skeleton3D",true,false)
	check(rig.get_bone_count()==68 and avatar.get_meta("short_jacket_variant",false),"Reviewed actual V31 jacket/rig unavailable")
	var library=load(args[0]) as AnimationLibrary
	check(library!=null and library.has_animation("Attack_Source_Retarget"),"Exact qualified native source unavailable")
	var native:Animation=library.get_animation("Attack_Source_Retarget")
	check(native.get_meta("source_native_fps",0)==30,"Candidate lost native timing provenance")
	var ap:AnimationPlayer=player.animation_player
	ap.get_animation_library("").add_animation("NATIVE_ATTACK_REVIEW",native.duplicate())
	ap.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var blade:Node3D=player.find_child("KatanaBlade",true,false)
	check(blade.get_parent()==player._hand_weapon_socket and blade.visible,"Actual built weapon lost its hand socket")
	var hand:=rig.find_bone("RightHand")
	var rest:=rig.get_bone_global_rest(hand)
	var middle:=rig.get_bone_global_rest(rig.find_bone("RightHandMiddle1")).origin
	var local_grip:Vector3=rest.affine_inverse()*rest.origin.lerp(middle,.5)
	var max_grip_error:=0.0
	var camera:=Camera3D.new()
	camera.fov=32
	camera.cull_mask=1<<19
	for mesh in avatar.find_children("*","MeshInstance3D",true,false):mesh.layers=1<<19
	for mesh in blade.find_children("*","MeshInstance3D",true,false):mesh.layers=1<<19
	for spec in [[Vector3(-30,-35,0),1.2],[Vector3(-20,145,0),.6]]:
		var light:=DirectionalLight3D.new()
		light.layers=1<<19
		light.light_cull_mask=1<<19
		light.rotation_degrees=spec[0]
		light.light_energy=spec[1]
		main.add_child(light)
	main.add_child(camera)
	camera.make_current()
	var count:=int(round(native.length*30.0))+1
	var trajectory:Array=[]
	for frame in count:
		main.set_reduced_motion(false)
		ap.play("NATIVE_ATTACK_REVIEW",0)
		ap.seek(minf(frame/30.0,native.length),true)
		ap.pause()
		var before:Array[Transform3D]=[]
		for bone in 68:before.append(rig.get_bone_pose(bone))
		main.set_reduced_motion(true)
		ap.play("NATIVE_ATTACK_REVIEW",0)
		ap.seek(minf(frame/30.0,native.length),true)
		ap.pause()
		for bone in 68:check(rig.get_bone_pose(bone).is_equal_approx(before[bone]),"Reduced Motion changed a native source joint")
		await process_frame
		var grip:=rig.to_global(rig.get_bone_global_pose(hand)*local_grip)
		var error:=grip.distance_to(blade.to_global(Vector3(0,-.12,0)))
		max_grip_error=maxf(max_grip_error,error)
		check(error<.0001,"Actual weapon handle detached from its measured palm center")
		var frame_tip:=blade.to_global(Vector3(0,1.1,0))
		var pelvis:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("Hips")).origin)
		trajectory.append({"frame":frame,"grip":[grip.x,grip.y,grip.z],"tip":[frame_tip.x,frame_tip.y,frame_tip.z],"pelvis":[pelvis.x,pelvis.y,pelvis.z]})
		if frame not in [0,9,18,24,30,34,39,48,60,count-1]:continue
		main.set_reduced_motion(false)
		var low:=Vector3(INF,INF,INF)
		var high:=Vector3(-INF,-INF,-INF)
		for bone in 68:
			var point:=rig.to_global(rig.get_bone_global_pose(bone).origin)
			low=low.min(point);high=high.max(point)
		for tip in [Vector3(0,1.1,0),Vector3(0,-.25,0)]:
			var point:=blade.to_global(tip)
			low=low.min(point);high=high.max(point)
		var center:Vector3=(low+high)*.5
		var distance:float=((high.y-low.y)*.5+.22)/tan(deg_to_rad(camera.fov*.5))*1.1
		var forward:Vector3=(player.visual_root.global_basis*player.model_local_forward).normalized()
		var side:=forward.cross(Vector3.UP).normalized()
		for view in ["front","side","grip"]:
			camera.global_position=grip+forward*.6+side*.22+Vector3.UP*.18 if view=="grip" else center+((forward+side*.2+Vector3.UP*.2).normalized() if view=="front" else (side+Vector3.UP*.15).normalized())*distance
			camera.look_at(grip if view=="grip" else center)
			for tick in 2:await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/%03d-%s.png"%[frame,view])
	var file:=FileAccess.open(folder+"/review.json",FileAccess.WRITE)
	var report:={"checks":checks,"samples":count,"maximum_palm_socket_error_m":max_grip_error,"renderer":RenderingServer.get_current_rendering_method(),"source_library_sha256":FileAccess.get_sha256(args[0]),"character_sha256":FileAccess.get_sha256("res://assets/characters/echo_v31_short_jacket.glb"),"scope":"Opt-in actual avatar/weapon source playback and Reduced Motion invariance. Fixture lights and camera layers isolate the rig. Finger enclosure, self-intersection, gameplay contact and final art require review; production aliases unchanged."}
	file.store_string(JSON.stringify(report,"\t"));file.close()
	var trace_file:=FileAccess.open(folder+"/trajectory.json",FileAccess.WRITE)
	trace_file.store_string(JSON.stringify(trajectory,"\t"));trace_file.close()
	print("NATIVE_ATTACK_POSE_REVIEW ",JSON.stringify(report))
	quit(0)
