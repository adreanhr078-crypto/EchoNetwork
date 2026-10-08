extends SceneTree

## Read-only native inspection of a returned Tripo source. This does not
## attach it to the campaign, author motion or accept art/animation quality.
var rig: Skeleton3D

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var source:=ProjectSettings.globalize_path("res://../art/production/tripo-20261007/zero-rig-v1/tripo-out/zero-rig-v1-20261008-rig-925ca3b6/model.glb")
	var out:=ProjectSettings.globalize_path("res://../audits/evidence/room-color-cinematics-20261007/zero-generated-rest/")
	var args:=OS.get_cmdline_user_args()
	for index in args.size()-1:
		if args[index]=="--source": source=args[index+1]
		if args[index]=="--out": out=args[index+1]
	DirAccess.make_dir_recursive_absolute(out)
	var document:=GLTFDocument.new()
	var state:=GLTFState.new()
	assert(document.append_from_file(source,state)==OK)
	var model:=document.generate_scene(state)
	root.add_child(model)
	for i in 3: await process_frame
	rig=_find_rig(model)
	assert(rig,"Returned source must have a real native Skeleton3D")
	var meshes: Array[MeshInstance3D]=[]
	_collect_meshes(model,meshes)
	var minimum:=Vector3(INF,INF,INF)
	var maximum:=Vector3(-INF,-INF,-INF)
	var rest_error:=0.0
	var bind_node_offsets: Array[Dictionary]=[]
	var vertices_count:=0
	for mesh in meshes:
		assert(mesh.skin,"Every Zero body surface must have an actual skin")
		var transforms: Array[Transform3D]=[]
		var node_offset:=Vector3.ZERO
		var offset_measured:=false
		for binding in mesh.skin.get_bind_count():
			var name:=mesh.skin.get_bind_name(binding)
			var index:=rig.find_bone(name) if name!="" else mesh.skin.get_bind_bone(binding)
			assert(index>=0)
			transforms.append(rig.get_bone_global_pose(index)*mesh.skin.get_bind_pose(binding))
		for surface in mesh.mesh.get_surface_count():
			var arrays:=mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
			var stride: int=bones.size()/vertices.size()
			vertices_count+=vertices.size()
			for vertex in vertices.size():
				var point:=Vector3.ZERO
				for binding in stride:
					var at: int=vertex*stride+binding
					if weights[at]>0: point+=(transforms[bones[at]]*vertices[vertex])*weights[at]
				var actual:=rig.to_global(point)
				var expected:=mesh.to_global(vertices[vertex])
				if not offset_measured:
					# A skinned glTF node can have a mesh/armature placement offset
					# encoded in its inverse binds. Measure that constant translation
					# without applying it to the source or changing any vertex/key.
					node_offset=actual-expected
					offset_measured=true
				rest_error=maxf(rest_error,(actual-expected-node_offset).length())
				minimum=minimum.min(actual)
				maximum=maximum.max(actual)
		bind_node_offsets.append({"mesh":mesh.name,"skin_to_mesh_node_rest_offset":[node_offset.x,node_offset.y,node_offset.z]})
	var bones_report: Array[Dictionary]=[]
	for index in rig.get_bone_count():
		var point:=rig.to_global(rig.get_bone_global_rest(index).origin)
		bones_report.append({"name":rig.get_bone_name(index),"parent":rig.get_bone_parent(index),"rest_world_position":[point.x,point.y,point.z]})
	var clips: Array[Dictionary]=[]
	_collect_clips(model,clips)
	var report:={"status":"NATIVE_SOURCE_REST_MEASURED_NOT_ART_ACCEPTED","source_path":source,"source_sha256":FileAccess.get_sha256(source),"vertices":vertices_count,"skeleton_bones":rig.get_bone_count(),"native_rest_skin_shape_error_m":rest_error,"bind_node_offsets":bind_node_offsets,"world_bounds_min":[minimum.x,minimum.y,minimum.z],"world_bounds_max":[maximum.x,maximum.y,maximum.z],"source_height":maximum.y-minimum.y,"source_base_y":minimum.y,"facing":"UNVERIFIED requires source image and actual shaded view","bones":bones_report,"clips":clips,"source_keys_changed":false,"campaign_integrated":false}
	var file:=FileAccess.open(out.path_join("native-source-rest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("ZERO_NATIVE_SOURCE ",JSON.stringify({"bones":rig.get_bone_count(),"vertices":vertices_count,"rest_error_m":rest_error,"source_height":maximum.y-minimum.y,"source_base_y":minimum.y,"clips":clips}))
	assert(rest_error<0.00012,"Actual native skin rest must preserve generated surface within quantized-weight error")
	model.queue_free()
	for i in 4: await process_frame
	quit(0)

func _find_rig(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for child in node.get_children():
		var found:=_find_rig(child)
		if found: return found
	return null

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D: output.append(node)
	for child in node.get_children(): _collect_meshes(child,output)

func _collect_clips(node: Node, output: Array[Dictionary]) -> void:
	if node is AnimationPlayer:
		for name in node.get_animation_list():
			var animation: Animation=node.get_animation(name)
			var rotations:=0
			var keys:=0
			for track in animation.get_track_count():
				keys+=animation.track_get_key_count(track)
				if animation.track_get_type(track)==Animation.TYPE_ROTATION_3D: rotations+=1
			output.append({"name":name,"length":animation.length,"rotation_tracks":rotations,"keys":keys})
	for child in node.get_children(): _collect_clips(child,output)
