extends SceneTree

## Raw native GLB review only: no avatar, motion keys or import settings changed.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.unfocusable=true
	root.size=Vector2i(960,720)
	var args:=OS.get_cmdline_user_args()
	if args.size()<3: push_error("Provide raw GLB, Blender reference and output folder");quit(1);return
	DirAccess.make_dir_recursive_absolute(args[2])
	var reference: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	if reference.get("source_sha256","")!=FileAccess.get_sha256(args[0]): push_error("Reference/source hash mismatch");quit(1);return
	var doc:=GLTFDocument.new()
	var state:=GLTFState.new()
	if doc.append_from_file(args[0],state)!=OK: push_error("Raw GLB parse failed");quit(1);return
	# Use the source's actual24Hz clock. The default30Hz bake is unsuitable here.
	var model: Node3D=doc.generate_scene(state,float(reference.fps),false,false)
	root.add_child(model)
	var rig:=model.find_child("Skeleton3D",true,false) as Skeleton3D
	var anim:=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if not rig or not anim: push_error("Candidate lacks rig/animation");quit(1);return
	var clips:=anim.get_animation_list()
	if clips.size()!=1: push_error("Expected exactly one untouched source clip");quit(1);return
	anim.play(clips[0]);anim.active=false
	if args.has("--mixer-probe"):
		var hand:=rig.find_bone("mixamorig_LeftHand")
		anim.seek(1.0/24.0,true);rig.force_update_all_bone_transforms()
		print("DISABLED_MIXER_HAND ",rig.get_bone_global_pose(hand).origin)
		anim.active=true
		anim.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		anim.play(clips[0],0.0);anim.seek(1.0/24.0,true);anim.pause()
		await process_frame
		print("MANUAL_MIXER_HAND ",rig.get_bone_global_pose(hand).origin)
		print("BLENDER_HAND ",reference.frames[0].bones["mixamorig:LeftHand"].head)
		quit(0);return
	anim.active=true
	anim.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	anim.root_motion_track=NodePath("")
	anim.get_animation(clips[0]).loop_mode=Animation.LOOP_NONE
	var max_position:=0.0
	var max_rotation:=0.0
	var compared:=0
	for frame in reference.frames:
		anim.play(clips[0],0.0);anim.seek(float(frame.time),true);anim.pause()
		await process_frame
		rig.force_update_all_bone_transforms()
		for name in frame.bones:
			var index:=rig.find_bone(String(name).replace(":","_"))
			if index<0: index=rig.find_bone(name)
			if index<0: push_error("Missing source joint "+name);quit(1);return
			var expected: Dictionary=frame.bones[name]
			var pose:=model.global_transform.affine_inverse()*rig.global_transform*rig.get_bone_global_pose(index)
			var rest:=model.global_transform.affine_inverse()*rig.global_transform*rig.get_bone_global_rest(index)
			var head:=Vector3(expected.head[0],expected.head[1],expected.head[2])
			var q: Array=expected.deform_q_wxyz
			var wanted:=Quaternion(q[1],q[2],q[3],q[0]).normalized()
			var actual: Quaternion=(pose*rest.affine_inverse()).basis.get_rotation_quaternion().normalized()
			max_position=maxf(max_position,pose.origin.distance_to(head))
			var relative: Quaternion=(actual.inverse()*wanted).normalized()
			max_rotation=maxf(max_rotation,rad_to_deg(2.0*atan2(Vector3(relative.x,relative.y,relative.z).length(),absf(relative.w))))
			compared+=1
	var numerical:=max_position<0.0001 and max_rotation<0.05
	var report:={"source_sha256":FileAccess.get_sha256(args[0]),"clip":clips[0],"fps":reference.fps,"frames":reference.frames.size(),"bones":rig.get_bone_count(),"compared_joints":compared,"max_position_error_m":max_position,"max_deformation_rotation_error_degrees":max_rotation,"numerical_pass":numerical,"scope":"Raw source replay in Blender/Godot, no retarget or runtime replacement; art/acting/skin contact remain separate"}
	var output:=FileAccess.open(args[2]+"/replay.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"));output.close()
	print("RAW_ACTOR_REPLAY ",JSON.stringify(report))
	if not numerical: push_error("Native replay differs from Blender");quit(1);return
	if DisplayServer.get_name()=="headless": quit(0);return
	var world:=WorldEnvironment.new();world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR
	world.environment.background_color=Color(.035,.045,.06)
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color(.72,.8,.95)
	world.environment.ambient_light_energy=.7;root.add_child(world)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-30,-35,0);sun.light_energy=1.7;root.add_child(sun)
	var camera:=Camera3D.new();camera.fov=39;root.add_child(camera);camera.make_current()
	camera.position=Vector3(1.15,.9,2.4);camera.look_at(Vector3(0,.5,0))
	for frame in [1,107,213,319,423]:
		anim.play(clips[0],0.0);anim.seek(frame/24.0,true);anim.pause();rig.force_update_all_bone_transforms()
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[2]+"/frame-%03d.png"%frame)
	quit(0)
