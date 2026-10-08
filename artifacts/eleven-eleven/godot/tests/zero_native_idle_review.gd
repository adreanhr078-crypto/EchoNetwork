extends SceneTree

## Read-only whole-take review of the actual generated skeletal Idle. Manual
## sampling changes only the playback cursor, never a source key or rest.
const Slot=preload("res://scripts/cinematics/zero_generated_model_slot.gd")
var stage: Node3D
var slot: Node3D
var camera: Camera3D
var folder: String
var movie: bool
var clip_name: String="idle"
var movie_fps: int=2
var movie_duration: float=INF
var movie_frames:=0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	root.size=Vector2i(960,720)
	root.content_scale_size=root.size
	folder=ProjectSettings.globalize_path("res://../audits/evidence/room-color-cinematics-20261007/zero-native-idle-v4/")
	DirAccess.make_dir_recursive_absolute(folder)
	DirAccess.make_dir_recursive_absolute(folder+"cycle/")
	var source:=ProjectSettings.globalize_path("res://../art/production/tripo-20261007/zero-humanoid-idle-v4/tripo-out/zero-humanoid-idle-v4-20261008-r-d77f057b/model.glb")
	var args:=OS.get_cmdline_user_args()
	for index in args.size()-1:
		if args[index]=="--source": source=args[index+1]
		if args[index]=="--out": folder=args[index+1].trim_suffix("/")+"/"
		if args[index]=="--clip": clip_name=args[index+1]
		if args[index]=="--movie-fps": movie_fps=clampi(int(args[index+1]),1,30)
		if args[index]=="--movie-duration": movie_duration=float(args[index+1])
	DirAccess.make_dir_recursive_absolute(folder)
	DirAccess.make_dir_recursive_absolute(folder+"cycle/")
	movie=DisplayServer.get_name()!="headless"
	var source_hash:=FileAccess.get_sha256(source)
	var document:=GLTFDocument.new()
	var state:=GLTFState.new()
	assert(document.append_from_file(source,state)==OK)
	var model:=document.generate_scene(state,30.0,false,false)
	stage=Node3D.new()
	root.add_child(stage)
	slot=Slot.new()
	stage.add_child(slot)
	assert(slot.configure(model,_profile()))
	assert(slot.skeleton.get_bone_count()==41)
	assert(slot.body_animation_verified and slot.body_animation_kind=="imported_native_clip")
	var player: AnimationPlayer=slot.source_player
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var animation: Animation=player.get_animation(clip_name)
	if clip_name=="idle": assert(absf(animation.length-15.3666667938232)<0.00001)
	var key_signature:=_clip_signature(animation)
	_build_lighting()
	camera=Camera3D.new()
	stage.add_child(camera)
	camera.fov=35
	camera.position=Vector3(6,4,11.5)
	camera.look_at(Vector3(0,3,0))
	camera.make_current()
	slot.tick(0,false,"manifested",0)
	player.advance(0)
	for i in 3: await process_frame
	var first:=_poses()
	var changed_max:=0
	var joint_motion: Dictionary={}
	var initial_points: Dictionary={}
	var joint_displacement: Dictionary={}
	for index in slot.skeleton.get_bone_count(): initial_points[slot.skeleton.get_bone_name(index)]=slot.skeleton.get_bone_global_pose(index).origin
	var checkpoints: Array[Dictionary]=[]
	var clip_duration:=animation.length
	# Full native30fps take, with CPU-skinned bounds every halfsecond.
	# Movie sampling is explicit and never changes native source playback keys.
	for frame in ceili(clip_duration*30.0)+1:
		var time:=minf(frame/30.0,clip_duration-0.000001)
		player.seek(time,true)
		player.advance(0)
		slot.tick(time,false,"manifested",0)
		var changed:=0
		for index in slot.skeleton.get_bone_count():
			var pose: Transform3D=slot.skeleton.get_bone_pose(index)
			if not pose.is_equal_approx(first[index]): changed+=1
			var angle:=_rotation_angle_degrees(pose.basis.get_rotation_quaternion(),first[index].basis.get_rotation_quaternion())
			var bone: String=slot.skeleton.get_bone_name(index)
			joint_motion[bone]=maxf(float(joint_motion.get(bone,0.0)),angle)
			var point: Vector3=slot.skeleton.get_bone_global_pose(index).origin
			joint_displacement[bone]=maxf(float(joint_displacement.get(bone,0.0)),point.distance_to(initial_points[bone]))
		changed_max=maxi(changed_max,changed)
		if frame%15==0 or frame==ceili(clip_duration*30.0):
			var bounds:=_skin_bounds()
			if clip_name=="idle":
				assert(bounds.size.y>5.5 and bounds.size.y<7.0,"Every sampled Idle skin must retain a coherent6.2mbody")
				assert(bounds.size.x<8.5 and bounds.size.z<5.0,"Idle must not produce stretched or exploding limbs")
			else:
				assert(bounds.size.y>3.0 and bounds.size.y<10.5 and bounds.size.x<12.0 and bounds.size.z<8.0,"Acting source must remain bounded; spatial fit and Canon remain separate visual gates")
			checkpoints.append({"time":time,"changed_bones":changed,"skin_min":[bounds.position.x,bounds.position.y,bounds.position.z],"skin_size":[bounds.size.x,bounds.size.y,bounds.size.z]})
			if frame==0: await _capture("01-whole-body-source-start")
			if frame==120: await _capture("02-whole-body-source-four-seconds")
			if frame==240: await _capture("03-whole-body-source-eight-seconds")
			if frame==360: await _capture("04-whole-body-source-twelve-seconds")
		if (frame%maxi(1,roundi(30.0/movie_fps))==0 or frame==ceili(clip_duration*30.0)) and time<=movie_duration:
			movie_frames+=1
			await _capture("cycle/frame-%03d" % movie_frames)
	assert(changed_max>=3,"An acting source must articulate real source bones")
	if clip_name=="idle":
		assert(changed_max>=12,"Actual native Idle must move the body, head and hands")
		for bone in ["Spine02","Head","L_Upperarm","L_Forearm","R_Upperarm","R_Forearm"]:
			assert(float(joint_motion[bone])>0.01,"Required source body part must actually move: "+bone)
		for bone in ["L_Hand","R_Hand"]:
			assert(float(joint_displacement[bone])>0.002,"Source hands must actually move with their bound arm hierarchy: "+bone)
	var loop_angle:=0.0
	var loop_translation:=0.0
	for index in slot.skeleton.get_bone_count():
		var last: Transform3D=slot.skeleton.get_bone_pose(index)
		loop_angle=maxf(loop_angle,_rotation_angle_degrees(last.basis.get_rotation_quaternion(),first[index].basis.get_rotation_quaternion()))
		loop_translation=maxf(loop_translation,last.origin.distance_to(first[index].origin))
	player.seek(minf(7.5,clip_duration*0.55),true)
	player.advance(0)
	camera.position=Vector3(0,5.8,3.4)
	camera.look_at(Vector3(0,5.35,0))
	await _capture("05-native-head-and-directed-eyes")
	camera.position=Vector3(0,3.0,8.0)
	camera.look_at(Vector3(0,3.1,0))
	await _capture("06-native-hands-and-mantle")
	var frozen:=_poses()
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	slot.tick(7.5,true,"manifested",4)
	assert(not player.is_playing())
	for i in 8: await process_frame
	assert(frozen==_poses(),"Reduced motion must pause the native source sample exactly")
	assert(key_signature==_clip_signature(animation) and source_hash==FileAccess.get_sha256(source),"Review must preserve source file and imported keys")
	var report:={"status":"NATIVE_FULL_TAKE_REVIEW_CAPTURED_VISUAL_ACCEPTANCE_PENDING","source_sha256":source_hash,"skeleton_bones":41,"native_animation":clip_name,"native_duration":clip_duration,"native_track_count":animation.get_track_count(),"native_key_signature":key_signature,"maximum_changed_bones":changed_max,"joint_rotation_degrees":joint_motion,"joint_skeleton_displacement_m":joint_displacement,"skeleton_to_world_transform":var_to_str(slot.skeleton.global_transform),"skeleton_to_world_scale":var_to_str(slot.skeleton.global_basis.get_scale()),"loop_end_max_local_angle_degrees":loop_angle,"loop_end_max_local_translation_m":loop_translation,"hand_motion":"The skeleton has no finger bones. Rotation values are actual native localbones; distances are in original skeletonspace, before skeleton_to_world_transform.","full_take_sample_fps":30,"skin_sample_count":checkpoints.size(),"skin_samples":checkpoints,"movie_sample_fps":movie_fps,"movie_frames":movie_frames,"movie_requested_duration":movie_duration if movie_duration!=INF else clip_duration,"reduced_motion_exact":true,"source_keys_changed":false,"campaign_integrated":false}
	var file:=FileAccess.open(folder+"native-full-take-review.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	stage.queue_free()
	for i in 5: await process_frame
	print("PASS Zero real native ",clip_name," full",clip_duration,"s,41-bone skin, actual skeletal motion, full-take skin bounds, exact reduced-motion pause and untouched source keys")
	quit(0)

func _profile() -> Dictionary:
	return {"source_height":2.10000105682411,"source_base_y":0.00000051673851,"facing_y_radians":-PI/2,"idle_animation":clip_name,"eyes":[{"source_position":[0.122,1.85596,0.04084],"source_forward":[1,0,0],"bone_name":"Head","width":0.022,"height":0.006,"color":[0.90,0.05,0.15]},{"source_position":[0.122,1.85596,-0.04084],"source_forward":[1,0,0],"bone_name":"Head","width":0.022,"height":0.006,"color":[0.56,0.13,0.95]}]}

func _poses() -> Array[Transform3D]:
	var poses: Array[Transform3D]=[]
	for index in slot.skeleton.get_bone_count(): poses.append(slot.skeleton.get_bone_pose(index))
	return poses

func _rotation_angle_degrees(a: Quaternion, b: Quaternion) -> float:
	# Relative-vector atan2 avoids the false nonzero acos(q dot q) angle
	# caused by single-precision norm error on unchanged source quaternions.
	var difference:=a.inverse()*b
	return rad_to_deg(2.0*atan2(Vector3(difference.x,difference.y,difference.z).length(),absf(difference.w)))

func _clip_signature(animation: Animation) -> String:
	var data: Array=[]
	for track in animation.get_track_count():
		var keys: Array=[]
		for key in animation.track_get_key_count(track): keys.append([animation.track_get_key_time(track,key),var_to_str(animation.track_get_key_value(track,key))])
		data.append([str(animation.track_get_path(track)),animation.track_get_type(track),keys])
	return JSON.stringify(data).sha256_text()

func _skin_bounds() -> AABB:
	var meshes: Array[MeshInstance3D]=[]
	_collect_meshes(slot.model_root,meshes)
	var minimum:=Vector3(INF,INF,INF)
	var maximum:=Vector3(-INF,-INF,-INF)
	for mesh in meshes:
		if not mesh.skin: continue
		var transforms: Array[Transform3D]=[]
		for binding in mesh.skin.get_bind_count():
			var name:=mesh.skin.get_bind_name(binding)
			var index: int=slot.skeleton.find_bone(name) if name!="" else mesh.skin.get_bind_bone(binding)
			transforms.append(slot.skeleton.get_bone_global_pose(index)*mesh.skin.get_bind_pose(binding))
		for surface in mesh.mesh.get_surface_count():
			var arrays:=mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
			var stride: int=bones.size()/vertices.size()
			for vertex in vertices.size():
				var point:=Vector3.ZERO
				for binding in stride:
					var at:=vertex*stride+binding
					if weights[at]>0: point+=(transforms[bones[at]]*vertices[vertex])*weights[at]
				var actual: Vector3=slot.skeleton.to_global(point)
				minimum=minimum.min(actual)
				maximum=maximum.max(actual)
	return AABB(minimum,maximum-minimum)

func _collect_meshes(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D: meshes.append(node)
	for child in node.get_children(): _collect_meshes(child,meshes)

func _capture(label: String) -> void:
	if not movie: return
	for i in 2: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+label+".png")

func _build_lighting() -> void:
	var world:=WorldEnvironment.new()
	var environment:=Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color(0.025,0.040,0.062)
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color(0.60,0.68,0.85)
	environment.ambient_light_energy=0.65
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled=true
	environment.glow_intensity=0.25
	environment.glow_hdr_threshold=1.0
	world.environment=environment
	stage.add_child(world)
	for data in [[Vector3(3.2,7,4),Color(0.77,0.84,1),3.2],[Vector3(-3,4.7,-1.4),Color(0.35,0.40,0.85),2.3]]:
		var light:=OmniLight3D.new()
		light.position=data[0]
		light.light_color=data[1]
		light.light_energy=data[2]
		light.omni_range=14
		stage.add_child(light)
	var floor:=MeshInstance3D.new()
	var mesh:=PlaneMesh.new()
	mesh.size=Vector2(22,22)
	floor.mesh=mesh
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color(0.14,0.18,0.25)
	material.roughness=0.76
	floor.material_override=material
	stage.add_child(floor)
