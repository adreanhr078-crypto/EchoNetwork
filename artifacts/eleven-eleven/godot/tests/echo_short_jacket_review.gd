extends SceneTree
var checks := 0
var folder := ""
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		push_error(label)
		quit(1)
		assert(ok,label)
func _run() -> void:
	folder=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	var main=load("res://scenes/native_journey.tscn").instantiate()
	main.native_checkpoint_path="user://cp45_short_jacket_opening.json"
	main.native_preferences_path="user://cp45_short_jacket.cfg"
	main.get_node("SystemJourneyPreview").checkpoint_path="user://cp45_short_jacket_maintenance.json"
	main.get_node("NativeJourneyController").checkpoint_path="user://cp45_short_jacket_route.json"
	main.get_node("NativeCampaignController").checkpoint_path="user://cp45_short_jacket_campaign.json"
	root.add_child(main)
	main.set_audio_muted(true)
	for frame in 5: await process_frame
	var player: EchoPlayer=main.player
	player.finish_opening_recovery()
	var dialogue=main.hud.find_child("DialogueOverlay",true,false)
	while dialogue.is_active: dialogue.advance_dialogue()
	main.native_pause_menu.resume_button.pressed.emit()
	main.set_reduced_motion(false)
	main.set_visual_quality("low")
	player.control_locked=false
	player._camera_suspended=false
	player.set_physics_process(false)
	player.set_process(false)
	player.set_process_unhandled_input(false)
	var avatar: Node3D=player.get_node("ModelRoot/EchoOpeningUniform")
	var rig: Skeleton3D=avatar.find_child("Skeleton3D",true,false)
	check(avatar.get_meta("short_jacket_variant",false),"Actual player did not use the reviewed jacket")
	check(avatar.find_child("EchoCapeMotion",true,false)==null,"Short jacket retained an unnecessary cape solver")
	var source=load("res://assets/characters/echo_v31_adopted_high.glb").instantiate()
	var source_rig: Skeleton3D=source.find_child("Skeleton3D",true,false)
	check(rig.get_bone_count()==68 and source_rig.get_bone_count()==68,"Original rig changed")
	check(rig.transform.is_equal_approx(source_rig.transform),"Skeleton import transform changed")
	var old_mesh: MeshInstance3D=source.find_children("*","MeshInstance3D",true,false)[0]
	var new_mesh: MeshInstance3D=avatar.find_child("EchoV31BodyAndCoat",true,false)
	check(old_mesh.skin.get_bind_count()==new_mesh.skin.get_bind_count(),"Original skin binding count changed")
	for bind in old_mesh.skin.get_bind_count():
		check(old_mesh.skin.get_bind_name(bind)==new_mesh.skin.get_bind_name(bind),"Skin joint binding changed")
		check(old_mesh.skin.get_bind_pose(bind).is_equal_approx(new_mesh.skin.get_bind_pose(bind)),"Original inverse bind changed")
	for bone in 68:
		check(rig.get_bone_name(bone)==source_rig.get_bone_name(bone),"Bone identity changed")
		check(rig.get_bone_parent(bone)==source_rig.get_bone_parent(bone),"Bone hierarchy changed")
		check(rig.get_bone_rest(bone).is_equal_approx(source_rig.get_bone_rest(bone)),"Original rest changed")
	source.free()
	var ap: AnimationPlayer=player.animation_player
	ap.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var samples := 0
	var clips: Array=[] if OS.get_cmdline_user_args().has("--capture-only") else ["IDLE","WALK","RUN","preset_jump","PARKOUR_HANG","PARKOUR_MANTLE","PARKOUR_STAND"]
	for clip in clips:
		check(ap.has_animation(clip),"Existing native motion unavailable: "+clip)
		var motion:=ap.get_animation(clip)
		for frame in int(round(motion.length*30.0))+1:
			var time:=minf(float(frame)/30.0,motion.length)
			main.set_reduced_motion(false)
			ap.play(clip,0);ap.seek(time,true);ap.pause()
			var before: Array[Transform3D]=[]
			for bone in 68: before.append(rig.get_bone_pose(bone))
			main.set_reduced_motion(true)
			ap.play(clip,0);ap.seek(time,true);ap.pause()
			for bone in 68:
				check(rig.get_bone_pose(bone).is_equal_approx(before[bone]),"Reduced Motion altered native jacket/body pose")
			samples+=1
	main.set_reduced_motion(false)
	main.hud.visible=false
	var camera:=Camera3D.new()
	camera.fov=32
	# Dedicated inspection visibility prevents room walls/the pod occluding
	# reverse angles; this changes this fixture's camera layers only.
	camera.cull_mask=1<<19
	for mesh in avatar.find_children("*","MeshInstance3D",true,false): mesh.layers=1<<19
	var key:=DirectionalLight3D.new()
	key.layers=1<<19
	key.light_cull_mask=1<<19
	key.rotation_degrees=Vector3(-30,-35,0)
	key.light_energy=1.2
	main.add_child(key)
	var fill:=DirectionalLight3D.new()
	fill.layers=1<<19
	fill.light_cull_mask=1<<19
	fill.rotation_degrees=Vector3(-20,145,0)
	fill.light_energy=.6
	main.add_child(fill)
	main.add_child(camera)
	camera.make_current()
	for clip in ["IDLE","WALK","RUN","preset_jump","PARKOUR_HANG","PARKOUR_MANTLE","PARKOUR_STAND"]:
		var moment: float={"IDLE":.4,"WALK":.46,"RUN":.2,"preset_jump":.8,"PARKOUR_HANG":0.0,"PARKOUR_MANTLE":.5666667,"PARKOUR_STAND":.2}[clip]
		ap.play(clip,0);ap.seek(moment,true);ap.pause()
		# Traversal source hips rise above the capsule. Frame the actual posed
		# joints rather than cropping them with a standing-height camera target.
		var low:=Vector3(INF,INF,INF)
		var high:=Vector3(-INF,-INF,-INF)
		for bone in 68:
			var point:=rig.to_global(rig.get_bone_global_pose(bone).origin)
			low=low.min(point);high=high.max(point)
		var center: Vector3=(low+high)*.5
		var distance: float=((high.y-low.y)*.5+.22)/tan(deg_to_rad(camera.fov*.5))*1.1
		for view in ["rear","side","front"]:
			var offset:=Vector3(1.3,1.1,-3.4) if view=="rear" else (Vector3(3.5,1.1,0) if view=="side" else Vector3(-.7,1.1,3.5))
			camera.global_position=center+offset.normalized()*distance
			camera.look_at(center)
			for frame in 3: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/"+clip+"-"+view+".png")
	var report:={"status":"SCOPED_RIG_PASS_ART_REVIEW_OPEN" if clips.is_empty() else "SCOPED_RIG_AND_NATIVE_MOTION_PASS_ART_REVIEW_OPEN","checks":checks,"native_samples":samples,"rest_hierarchy_names_preserved":68,"body_or_animation_keys_changed":false,"cape_solver_required":false,"renderer":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name(),"source_sha256":FileAccess.get_sha256("res://assets/characters/echo_v31_adopted_high.glb"),"jacket_sha256":FileAccess.get_sha256("res://assets/characters/echo_v31_short_jacket.glb"),"scope":"Actual native_journey player; scoped source clocks and all68 joints compared across Reduced Motion when native_samples>0. Twenty-one critical-pose captures with fixture lights and room geometry excluded by inspection-camera layers. Does not prove all contact frames, complete chapter or Steam release acceptance."}
	var file:=FileAccess.open(folder+"/review.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("SHORT_JACKET_REVIEW ",JSON.stringify(report))
	quit(0)
