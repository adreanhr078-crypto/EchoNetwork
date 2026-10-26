extends SceneTree

## Export the actual adopted avatar's post-mixer skin for independent triangle
## intersection review. No generated source, skin, rest or animation is written.
func _initialize() -> void: _run.call_deferred()

func _matrix(value: Transform3D) -> Array:
	return [[value.basis.x.x,value.basis.y.x,value.basis.z.x,value.origin.x], [value.basis.x.y,value.basis.y.y,value.basis.z.y,value.origin.y], [value.basis.x.z,value.basis.y.z,value.basis.z.z,value.origin.z]]

func _buffer(path: String, value: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "Cannot write garment evidence")
	file.store_buffer(value)

func _skin_matrices(rig: Skeleton3D, surfaces: Array, meshes: Array[MeshInstance3D]) -> Array:
	var matrices: Array = []
	for surface in surfaces.size():
		var transforms: Array = []
		for bind in surfaces[surface].bind_ids.size():
			transforms.append(_matrix(rig.global_transform * rig.get_bone_global_pose(surfaces[surface].bind_ids[bind]) * meshes[surface].skin.get_bind_pose(bind)))
		matrices.append(transforms)
	return matrices

func _joint_centers(rig: Skeleton3D) -> Dictionary:
	var points := {}
	for name in ["Hips","LeftUpLeg","LeftLeg","LeftFoot","RightUpLeg","RightLeg","RightFoot"]:
		var point := rig.to_global(rig.get_bone_global_pose(rig.find_bone(name)).origin)
		points[name] = [point.x,point.y,point.z]
	return points

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	assert(not args.is_empty(), "An absolute evidence folder is required")
	var folder: String = args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	var world := Node3D.new()
	root.add_child(world)
	var player: EchoPlayer = load("res://scenes/player/echo_player.tscn").instantiate()
	world.add_child(player)
	player.finish_opening_recovery()
	player.set_physics_process(false)
	player.set_process(false)
	player.set_process_unhandled_input(false)
	player.control_locked = false
	player._camera_suspended = false
	player.reduced_motion = args.has("--reduced-motion")
	var rig: Skeleton3D = player.visual_root.find_child("Skeleton3D",true,false)
	assert(rig != null and rig.get_bone_count() == 68)
	var cape: Node = rig.find_child("EchoCapeMotion",true,false)
	assert(cape != null and cape.configured)
	cape.active = false
	var ap := player.animation_player
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var garment_input := {}
	var names: Array = []
	for bone in rig.get_bone_count():
		names.append(rig.get_bone_name(bone))
		if rig.get_bone_name(bone).begins_with("Cape_"): garment_input[bone] = rig.get_bone_pose(bone)
	var surfaces: Array = []
	var meshes: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in player.visual_root.find_children("*","MeshInstance3D",true,false):
		if not mesh.skin or not mesh.mesh: continue
		if mesh.get_node_or_null(mesh.skeleton) != rig: continue
		var bind_ids: Array = []
		var bind_poses: Array = []
		var rest_matrices: Array = []
		for bind in mesh.skin.get_bind_count():
			var bone := mesh.skin.get_bind_bone(bind)
			if bone < 0: bone = rig.find_bone(mesh.skin.get_bind_name(bind))
			if bone < 0:
				push_error("Unresolved actual avatar bind: " + str(mesh.name) + " / " + str(mesh.skin.get_bind_name(bind)))
				quit(1)
				return
			bind_ids.append(bone)
			bind_poses.append(_matrix(mesh.skin.get_bind_pose(bind)))
			rest_matrices.append(_matrix(rig.get_bone_global_rest(bone) * mesh.skin.get_bind_pose(bind)))
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var prefix := "surface-%d" % surfaces.size()
			var count: int = arrays[Mesh.ARRAY_VERTEX].size()
			assert(count > 0)
			_buffer(folder+"/"+prefix+"-vertices.bin", arrays[Mesh.ARRAY_VERTEX].to_byte_array())
			_buffer(folder+"/"+prefix+"-bones.bin", arrays[Mesh.ARRAY_BONES].to_byte_array())
			_buffer(folder+"/"+prefix+"-weights.bin", arrays[Mesh.ARRAY_WEIGHTS].to_byte_array())
			_buffer(folder+"/"+prefix+"-indices.bin", arrays[Mesh.ARRAY_INDEX].to_byte_array())
			surfaces.append({"prefix":prefix,"mesh_path":str(mesh.get_path()),"surface":surface,"vertices":count,"influences":arrays[Mesh.ARRAY_BONES].size()/count,"bind_ids":bind_ids,"bind_poses":bind_poses,"rest_matrices":rest_matrices})
			meshes.append(mesh)
	assert(not surfaces.is_empty(), "No actual adopted skin exported")
	var records: Array = []
	rig.reset_bone_poses()
	records.append({"clip":"REST","time":0.0,"matrices":_skin_matrices(rig,surfaces,meshes),"joints":_joint_centers(rig)})
	var checks := 0
	var hyper: Node = root.get_node("HyperAnimeWorldManager")
	hyper.set_process(false)
	var clips: Array = [] if args.has("--metadata-only") else ["IDLE","WALK","RUN","preset_jump"]
	for clip: String in clips:
		assert(ap.has_animation(clip))
		var animation := ap.get_animation(clip)
		var count := int(round(animation.length * 30.0)) + 1
		player.velocity = Vector3(0,0,7) if clip == "RUN" else (Vector3(0,0,2) if clip == "WALK" else Vector3.ZERO)
		cape.reset_motion()
		for warm in 45:
			for bone in garment_input: rig.set_bone_pose(bone, garment_input[bone])
			ap.play(clip,0); ap.seek(0,true); ap.pause()
			hyper.visual_time = float(warm)/30.0
			cape._process_modification_with_delta(1.0/30.0)
		for sample in count:
			var time := minf(float(sample)/30.0,animation.length)
			for bone in garment_input: rig.set_bone_pose(bone, garment_input[bone])
			ap.play(clip,0); ap.seek(time,true); ap.pause()
			var body_before := {}
			for bone in rig.get_bone_count():
				if not garment_input.has(bone): body_before[bone] = rig.get_bone_pose(bone)
			hyper.visual_time = float(sample+45)/30.0
			if args.has("--gravity-only"):
				cape.reset_motion()
				cape._apply_support_pose()
			elif not args.has("--source-only"): cape._process_modification_with_delta(1.0/30.0)
			for bone in body_before:
				checks += 1
				assert(rig.get_bone_pose(bone).is_equal_approx(body_before[bone]), "Garment changed protected body joint")
			records.append({"clip":clip,"time":time,"matrices":_skin_matrices(rig,surfaces,meshes),"joints":_joint_centers(rig)})
		print("GARMENT_SKIN_EXPORTED ",clip," samples=",count)
	var hashes := {}
	for path in ["assets/characters/echo_v31_adopted_high.glb","engine_visuals/EchoCapeMotion.gd","scripts/player/echo_v31_motion_adapter.gd","tests/echo_cape_skin_review.gd"]:
		hashes[path] = FileAccess.get_sha256("res://"+path)
	var report := {"scope":"Actual V31 skin and post-mixer matrices; independent triangle review required", "bone_names":names,"surfaces":surfaces,"poses":records,"protected_body_checks":checks,"source_only":args.has("--source-only"),"gravity_only":args.has("--gravity-only"),"reduced_motion":player.reduced_motion,"source_hashes":hashes}
	var file := FileAccess.open(folder+"/skin-poses.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	file.close()
	player.queue_free()
	await process_frame
	world.queue_free()
	await process_frame
	print("PASS garment skin evidence export; protected body checks=",checks,"; triangle/art acceptance OPEN")
	quit(0)
