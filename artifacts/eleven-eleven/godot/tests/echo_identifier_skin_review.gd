extends SceneTree

const OUTPUT := "res://../audits/evidence/echo-identifier-skin-20261001/"

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var avatar := load("res://assets/characters/echo_opening_uniform_v13.glb").instantiate() as Node3D
	root.add_child(avatar)
	await process_frame
	var body := avatar.find_child("EchoOpeningUniformBody", true, false) as MeshInstance3D
	var skeleton := avatar.find_child("Skeleton3D", true, false) as Skeleton3D
	var inspection := {"bones": {}, "exposed_neck_skin_vertices": [], "old_mapping": "bone_6 is right shoulder, not neck"}
	for name in ["bone_6", "tripo__Head_0", "tripo__Head_1", "tripo__Spine_2"]:
		var bone := skeleton.find_bone(name)
		var rest := skeleton.get_bone_global_rest(bone)
		inspection.bones[name] = {"origin": [rest.origin.x, rest.origin.y, rest.origin.z], "basis_x": [rest.basis.x.x, rest.basis.x.y, rest.basis.x.z], "basis_y": [rest.basis.y.x, rest.basis.y.y, rest.basis.y.z], "basis_z": [rest.basis.z.x, rest.basis.z.y, rest.basis.z.z]}
	var material := body.get_active_material(0) as BaseMaterial3D
	var atlas := material.albedo_texture.get_image()
	var arrays := body.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var influence_count := bones.size() / verts.size()
	var matrices: Array[Transform3D] = []
	for bind in range(body.skin.get_bind_count()):
		var bone := body.skin.get_bind_bone(bind)
		if bone < 0: bone = skeleton.find_bone(body.skin.get_bind_name(bind))
		matrices.append(skeleton.get_bone_global_rest(bone) * body.skin.get_bind_pose(bind))
	var neck_y := skeleton.get_bone_global_rest(skeleton.find_bone("tripo__Head_0")).origin.y
	for v in range(verts.size()):
		var point := Vector3.ZERO
		for influence in range(influence_count):
			var index := v * influence_count + influence
			point += (matrices[bones[index]] * verts[v]) * weights[index]
		if point.y < neck_y - 0.025 or point.y > neck_y + 0.045: continue
		var uv := uvs[v]
		var color := atlas.get_pixel(clampi(int(uv.x * atlas.get_width()), 0, atlas.get_width() - 1), clampi(int(uv.y * atlas.get_height()), 0, atlas.get_height() - 1))
		if color.r - color.b < 0.025 or color.r - color.g < 0.008 or color.r < 0.25: continue
		inspection.exposed_neck_skin_vertices.append({"id": v, "rest": [point.x, point.y, point.z], "uv": [uv.x, uv.y], "rgb": [color.r, color.g, color.b]})
	var folder := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(folder)
	var file := FileAccess.open(folder + "inspection.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(inspection, "\t"))
	file.close()
	print("NECK_INSPECTION ", JSON.stringify(inspection.bones), " warm_skin_vertices=", inspection.exposed_neck_skin_vertices.size())
	avatar.queue_free()
	await process_frame
	quit(0)
