extends SceneTree
## Isolated face diagnostic:actual GPU morph mix against evaluated Blender skin.
## Skeleton-pose baking ignores morphs,so it is only used at the neutralrest.
var failures:Array[String]=[]
var checks:=0
var folder:String
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
	print("PASS " if ok else "FAIL ",label)
func vec(row:Array)->Vector3:return Vector3(float(row[0]),float(row[1]),float(row[2]))
func key(point:Vector3)->Vector3i:return Vector3i(roundi(point.x*5000),roundi(point.y*5000),roundi(point.z*5000))
func physical_point(point:Vector3,index:int,arrays:Array,transforms:Array,space:Transform3D)->Vector3:
	var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
	var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
	var count:int=bones.size()/arrays[Mesh.ARRAY_VERTEX].size()
	var result:=Vector3.ZERO
	for slot in count:
		var item:=index*count+slot
		if weights[item]>0:result+=(transforms[bones[item]]*point)*weights[item]
	return space*result
func _initialize()->void:_run.call_deferred()
func _run()->void:
	var args:=OS.get_cmdline_user_args()
	folder=args[0]
	var body_mode:=args.has("--body-motion")
	DirAccess.make_dir_recursive_absolute(folder)
	var reference_path:="res://body-reference.json" if body_mode else "res://reference.json"
	var reference:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(reference_path))
	var rest_positions:Array=reference.get("rest_positions",reference.frames[0].positions)
	root.size=Vector2i(960,960)
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(.04,.05,.065)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE
	environment.environment.ambient_light_energy=.3
	environment.environment.tonemap_mode=Environment.TONE_MAPPER_ACES
	root.add_child(environment)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-30,-25,0)
	light.light_energy=.4
	root.add_child(light)
	var model:Node3D=load("res://candidate.glb").instantiate()
	root.add_child(model)
	var skeleton:=model.find_child("Skeleton3D",true,false) as Skeleton3D
	var meshes:=model.find_children("*","MeshInstance3D",true,false)
	check(skeleton!=null and skeleton.get_bone_count()==65 and meshes.size()==1,"Original65 body skeleton andsingle skinned body retained")
	if skeleton==null or meshes.size()!=1:quit(1);return
	var mesh:=meshes[0] as MeshInstance3D
	check(mesh.get_blend_shape_count()==1 and mesh.find_blend_shape_by_name("blink")==0,"Exactlyone real blink morph imported")
	var max_bone_error:=0.0
	var bones_found:=0
	for name:String in reference.bones:
		var index:=skeleton.find_bone(name)
		if index<0:continue
		bones_found+=1
		var actual:=skeleton.to_global(skeleton.get_bone_global_rest(index).origin)
		max_bone_error=maxf(max_bone_error,actual.distance_to(vec(reference.bones[name])))
	check(bones_found==65 and max_bone_error<.00002,"All65 originalrest joints agree with Blenderwithin20micrometers")
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=.17
	root.add_child(camera)
	var center:=Vector3(-.003,1.597,.05)
	camera.position=center+Vector3(0,0,3)
	camera.look_at(center)
	camera.current=true
	await process_frame
	await RenderingServer.frame_post_draw
	var baseline:=mesh.bake_mesh_from_current_blend_shape_mix()
	var original_arrays:Array=[]
	for surface in mesh.mesh.get_surface_count():original_arrays.append(mesh.mesh.surface_get_arrays(surface))
	var transforms:Array[Transform3D]=[]
	for bind in mesh.skin.get_bind_count():
		var bone:=mesh.skin.get_bind_bone(bind)
		if bone<0:bone=skeleton.find_bone(mesh.skin.get_bind_name(bind))
		transforms.append(skeleton.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
	var buckets:Dictionary={}
	var source_ids:Dictionary={}
	for surface in baseline.get_surface_count():
		var vertices:PackedVector3Array=baseline.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		var labels:PackedVector2Array=original_arrays[surface][Mesh.ARRAY_TEX_UV2]
		if labels.size()!=vertices.size():check(false,"Diagnostic sourcevertex labels survived import");quit(1);return
		for index in vertices.size():
			var point:=physical_point(vertices[index],index,original_arrays[surface],transforms,skeleton.global_transform)
			var bucket:=key(point)
			if not buckets.has(bucket):buckets[bucket]=[]
			buckets[bucket].append({"surface":surface,"index":index,"point":point})
			# Blender glTF export reverses UVV;headlessorientation probe matched
			# all738 source IDs only with this inverse conversion.
			var source_id:=roundi(labels[index].x*255)+roundi((1-labels[index].y)*511)*256
			if not source_ids.has(source_id):source_ids[source_id]={"surface":surface,"index":index,"point":point}
	var matches:Array=[]
	var maximum_match_error:=0.0
	var maximum_moving_match_error:=0.0
	var sample_number:=0
	for row:Array in rest_positions:
		var expected:=vec(row)
		var bucket:=key(expected)
		var nearest:Dictionary={}
		var distance:=INF
		var identity:int=reference.sampled_original_vertex_indices[sample_number]
		if source_ids.has(identity):
			nearest=source_ids[identity]
			distance=nearest.point.distance_to(expected)
		if not nearest.is_empty():matches.append(nearest)
		else:matches.append({})
		maximum_match_error=maxf(maximum_match_error,distance)
		if reference.moving_flags[sample_number]:maximum_moving_match_error=maxf(maximum_moving_match_error,distance)
		sample_number+=1
	var matched_count:=0
	for item:Dictionary in matches:
		if not item.is_empty():matched_count+=1
	check(matched_count==reference.sampled_original_vertex_indices.size(),"Every sampledvertex matched byexported diagnostic identity,without nearest-neighbor ambiguity")
	if matched_count!=reference.sampled_original_vertex_indices.size():
		var debug:={"status":"FAIL_NEUTRAL_MAPPING","maximum_match_error_m":maximum_match_error,"mesh_transform":str(mesh.global_transform),"skeleton_transform":str(skeleton.global_transform),"samples":[]}
		var skinned:=mesh.bake_mesh_from_current_skeleton_pose()
		for sample in mini(5,rest_positions.size()):
			var expected:=vec(rest_positions[sample])
			var row:={"expected":expected,"mixed_nearest":Vector3.ZERO,"mixed_error":INF,"skinned_nearest":Vector3.ZERO,"skinned_error":INF}
			for surface in baseline.get_surface_count():
				var vertices:PackedVector3Array=baseline.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				var skin_vertices:PackedVector3Array=skinned.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for index in vertices.size():
					var point:=mesh.global_transform*vertices[index]
					var skin_point:=mesh.global_transform*skin_vertices[index]
					var distance:=point.distance_to(expected)
					if distance<float(row.mixed_error):row.mixed_error=distance;row.mixed_nearest=point
					distance=skin_point.distance_to(expected)
					if distance<float(row.skinned_error):row.skinned_error=distance;row.skinned_nearest=skin_point
			debug.samples.append(row)
		var debug_file:=FileAccess.open(folder.path_join("native-mapping-failure.json"),FileAccess.WRITE)
		debug_file.store_string(JSON.stringify(debug,"\t"));debug_file.close()
		root.get_texture().get_image().save_png(folder.path_join("native-mapping-failed-neutral.png"))
		print("BLINK_NATIVE_MAPPING_FAILURE ",JSON.stringify(debug))
		quit(1);return
	var skeleton_only:=mesh.bake_mesh_from_current_skeleton_pose()
	var maximum_rest_skin_error:=0.0
	for sample in matches.size():
		var match:Dictionary=matches[sample]
		var vertices:PackedVector3Array=skeleton_only.surface_get_arrays(match.surface)[Mesh.ARRAY_VERTEX]
		maximum_rest_skin_error=maxf(maximum_rest_skin_error,(mesh.global_transform*vertices[match.index]).distance_to(vec(rest_positions[sample])))
	check(maximum_rest_skin_error<.0002,"Actual rest skeleton skin agrees with Blenderwithin0.2mm")
	var proxy:=MeshInstance3D.new()
	mesh.get_parent().add_child(proxy)
	proxy.transform=mesh.transform
	proxy.skin=mesh.skin
	proxy.skeleton=proxy.get_path_to(skeleton)
	proxy.visible=false
	var maximum_morph_error:=0.0
	var maximum_delta_error:=0.0
	var baseline_points:Array[Vector3]=[]
	var baseline_expected:Array=[]
	var body_player:AnimationPlayer
	var body_bone_error:=0.0
	var keys_preserved:=true
	if body_mode:
		body_player=AnimationPlayer.new()
		model.add_child(body_player)
		body_player.root_node=NodePath("..")
		body_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		body_player.root_motion_track=NodePath("")
		var library:=AnimationLibrary.new()
		for slug:String in reference.motions:
			var facts:Dictionary=reference.motions[slug]
			if FileAccess.get_sha256(facts.library)!=facts.library_sha256:check(false,"Qualified bodylibrary identity changed");quit(1);return
			var source_library:AnimationLibrary=load(facts.library)
			var original:Animation=source_library.get_animation(facts.action)
			var clip:Animation=original.duplicate(true)
			clip.loop_mode=Animation.LOOP_NONE
			for track in clip.get_track_count():
				var path:=clip.track_get_path(track)
				if path.get_subname_count()!=1 or skeleton.find_bone(path.get_subname(0))<0:check(false,"Bodytrack doesnot resolve onoriginal65");quit(1);return
				clip.track_set_path(track,NodePath(str(model.get_path_to(skeleton))+":"+str(path.get_subname(0))))
				keys_preserved=keys_preserved and clip.track_get_key_count(track)==original.track_get_key_count(track)
			library.add_animation(facts.action,clip)
		body_player.add_animation_library("",library)
	var head:=skeleton.find_bone("mixamorig_Head")
	var rest_head:=skeleton.global_transform*skeleton.get_bone_global_rest(head)
	var frames:Array=[]
	var captures:Array=[]
	for frame:Dictionary in reference.frames:
		if body_mode:
			body_player.play(frame.action,0.0)
			body_player.seek(float(frame.time),true)
			body_player.pause()
			skeleton.force_update_all_bone_transforms()
			for bone_name:String in frame.bones:
				var bone_index:=skeleton.find_bone(bone_name)
				body_bone_error=maxf(body_bone_error,skeleton.to_global(skeleton.get_bone_global_pose(bone_index).origin).distance_to(vec(frame.bones[bone_name])))
		mesh.set_blend_shape_value(0,float(frame.blink))
		await process_frame
		await RenderingServer.frame_post_draw
		var baked:=mesh.bake_mesh_from_current_blend_shape_mix()
		var combined_mesh:=ArrayMesh.new()
		for surface in baked.get_surface_count():
			var data:=baked.surface_get_arrays(surface)
			data[Mesh.ARRAY_BONES]=original_arrays[surface][Mesh.ARRAY_BONES]
			data[Mesh.ARRAY_WEIGHTS]=original_arrays[surface][Mesh.ARRAY_WEIGHTS]
			combined_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data)
		proxy.mesh=combined_mesh
		await process_frame
		await RenderingServer.frame_post_draw
		var combined:=proxy.bake_mesh_from_current_skeleton_pose()
		var arrays:Array=[]
		for surface in combined.get_surface_count():arrays.append(combined.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
		var frame_error:=0.0
		if float(frame.blink)==0:
			baseline_points.clear()
			baseline_expected=frame.positions
		for sample in matches.size():
			var match:Dictionary=matches[sample]
			var point:Vector3=mesh.global_transform*arrays[match.surface][match.index]
			frame_error=maxf(frame_error,point.distance_to(vec(frame.positions[sample])))
			if float(frame.blink)==0:baseline_points.append(point)
			else:
				var actual_delta:Vector3=point-baseline_points[sample]
				var expected_delta:=vec(frame.positions[sample])-vec(baseline_expected[sample])
				maximum_delta_error=maxf(maximum_delta_error,actual_delta.distance_to(expected_delta))
		maximum_morph_error=maxf(maximum_morph_error,frame_error)
		frames.append({"blink":frame.blink,"motion":frame.get("motion","rest"),"frame":frame.get("frame",0),"maximum_blender_error_m":frame_error})
		var motion:=Transform3D.IDENTITY
		if body_mode:motion=(skeleton.global_transform*skeleton.get_bone_global_pose(head))*rest_head.affine_inverse()
		var face_center:=motion*center
		var views:Array=["front"] if body_mode else ["front","threequarter","reverse-threequarter"]
		for view:String in views:
			camera.position=face_center+motion.basis*Vector3(0 if view=="front" else 1.5 if view=="threequarter" else -1.5,0,3)
			camera.look_at(face_center)
			await RenderingServer.frame_post_draw
			var label:="native-%.2f-%s.png"%[float(frame.blink),view]
			if body_mode:label="native-body-%s-%03d-%d.png"%[str(frame.motion),int(frame.frame),int(frame.blink)]
			var path:=folder.path_join(label)
			root.get_texture().get_image().save_png(path);captures.append(path)
	check(maximum_morph_error<.0002,"All %d GPU morph-plus-skin states agree with evaluated Blender within 0.2mm"%frames.size())
	check(maximum_delta_error<.00002,"Actual blink deformation relative to neutral agrees with Blenderwithin20micrometers")
	if body_mode:
		check(keys_preserved,"Qualified bodykeys retained;only diagnostic nodepaths adapted")
		check(body_bone_error<.00002,"All65 bodypose joints agree with Blenderacross18 body-plus-blink states")
	var report:={"status":"PASS_SCOPED_NATIVE_MORPH" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,
		"sample_count":matches.size(),"moving_samples":reference.moving_sample_count,"frames":frames,
		"max_rest_bone_error_m":max_bone_error,"max_rest_skin_error_m":maximum_rest_skin_error,"max_morph_error_m":maximum_morph_error,"max_morph_delta_error_m":maximum_delta_error,
		"max_cpu_moving_mapping_error_m":maximum_moving_match_error,"max_cpu_mapping_error_m":maximum_match_error,
		"body_motion":body_mode,"body_bone_error_m":body_bone_error,"body_keys_preserved":keys_preserved,
		"vertex_correspondence":"Explicit LAB_SOURCE_VERTEX_ID in diagnostic-only UV2;originalUV0 andsourcebodytextures unchanged. Absolute skin uses established0.2mm GPUskin budget;relativeblink displacement has independent20micrometer gate.",
		"captures":captures,"renderer":RenderingServer.get_current_rendering_method(),"engine":Engine.get_version_info(),
		"source_glb_sha256":FileAccess.get_sha256("res://candidate.glb"),"reference_sha256":FileAccess.get_sha256(reference_path),
		"reviewer_sha256":FileAccess.get_sha256("res://review.gd"),
		"scope":"Isolated real morph fidelity and rendered closeups only;body-motion sampling is recorded separately by body_motion and frames. GPU blendshape mix -> diagnostic proxy retaining original weights/skin -> actual GPU skeleton bake. Original renderer shows the real combined original mesh. Final face art and runtime integration remain open. Skin baking alone ignores morphs;direct raw mix/world comparison was wrong space and its failed artifact is retained."}
	var file:=FileAccess.open(folder.path_join("godot-blink-body-review.json" if body_mode else "godot-blink-review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("BLINK_NATIVE_REVIEW ",JSON.stringify({"checks":checks,"failures":failures,"max_morph_error_m":maximum_morph_error}))
	quit(0 if failures.is_empty() else 1)
