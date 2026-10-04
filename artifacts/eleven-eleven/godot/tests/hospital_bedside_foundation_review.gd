extends SceneTree

## Isolated bed/scale/contact evidence. Rigid rest-body placement is diagnostic,
## not a hospital animation, costume, natural hands or campaign acceptance.
const OUTPUT := "res://../audits/evidence/hospital-bedside-foundation-20261001/"
const WardScene = preload("res://scenes/environment/hospital_bedside_foundation.tscn")
const AvatarScene = preload("res://assets/characters/echo_opening_uniform_v13.glb")
var ward: Node3D
var actor: Node3D
var camera: Camera3D

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var capture_enabled := "--capture" in OS.get_cmdline_user_args()
	var neck_only := "--neck-only" in OS.get_cmdline_user_args()
	if capture_enabled and DisplayServer.get_name() == "headless":
		push_error("Hospital visual evidence requires rendered pixels")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	ward = WardScene.instantiate()
	root.add_child(ward)
	await process_frame
	await physics_frame
	var space := ward.get_world_3d().direct_space_state
	var bed_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 3, 0), Vector3(0, -1, 0)))
	var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(2.5, 3, 1.8), Vector3(2.5, -1, 1.8)))
	if bed_hit.is_empty() or floor_hit.is_empty() or absf(bed_hit.position.y - 0.70) > 0.001 or absf(floor_hit.position.y) > 0.001:
		push_error("Real physics floor/bed support surface mismatch")
		quit(1)
		return
	actor = AvatarScene.instantiate()
	actor.name = "IsolatedCurrentAvatarScaleProbe"
	actor.scale = Vector3.ONE * 1.81
	ward.add_child(actor)
	for node in actor.find_children("*", "AnimationPlayer", true, false):
		(node as AnimationPlayer).stop()
	for node in actor.find_children("*", "Skeleton3D", true, false):
		(node as Skeleton3D).reset_bone_poses()
	for node in actor.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for shape in mesh.mesh.get_blend_shape_count(): mesh.set_blend_shape_value(shape, 0)
	await process_frame
	var standing_points := _rest_points()
	var standing_bounds := _bounds(standing_points)
	actor.position = Vector3(1.72, -standing_bounds.position.y, 0.88)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 43
	ward.add_child(camera)
	var folder := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(folder)
	var review := {"status": "PARTIAL", "renderer": RenderingServer.get_current_rendering_method(), "source_avatar": "echo_opening_uniform_v13.glb", "source_animation_changed": false, "body_pose": "Rigid rest-body rotation ONLY; no character keys, joint pose or native animation authored", "canon_reference": "approved page-063: daylight bedside wake; no simulation truth or city exit claim", "mattress_size_m": [2.12, 0.14, 0.96], "mattress_top_m": 0.70, "standing_avatar_bounds_m": _aabb_json(standing_bounds), "captures": []}
	if neck_only and FileAccess.file_exists(folder + "review.json"):
		var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder + "review.json"))
		for item in previous.get("captures", []):
			if item.name != "neck-placement-detail": review.captures.append(item)
		review["capture_refresh"] = "Only isolated neck lettering/camera refreshed; room and rest-body scale/contact geometry unchanged"
	if capture_enabled and not neck_only:
		await _capture("ward-person-scale", Vector3(4.0, 2.6, 4.8), Vector3(0, 0.85, 0), review)
		actor.visible = false
		await _capture("ward-three-quarter", Vector3(3.6, 2.0, 3.6), Vector3(-0.1, 0.90, -0.25), review)
		await _capture("bed-detail", Vector3(1.8, 1.9, 2.25), Vector3(-0.20, 0.67, 0), review)
		actor.visible = true
	# Rotate current unmodified rest mesh: native character rest front +X becomes +Y.
	actor.position = Vector3.ZERO
	actor.rotation.z = PI / 2.0
	await process_frame
	var rotated_points := _rest_points()
	var rotated_bounds := _bounds(rotated_points)
	actor.position.x = -rotated_bounds.get_center().x
	var back_min := INF
	for point in rotated_points:
		var shifted_x := point.x + actor.position.x
		if shifted_x > -0.55 and shifted_x < 0.55:
			back_min = minf(back_min, point.y)
	actor.position.y = 0.70 - back_min
	await process_frame
	var support_min := INF
	var support_max := -INF
	var mattress_penetration := 0.0
	var head_pillow_penetration := 0.0
	var head_pillow_gap := INF
	var foot_cover_gap := INF
	for point in _rest_points():
		if absf(point.z) < 0.48 and absf(point.x) < 1.06:
			mattress_penetration = maxf(mattress_penetration, 0.70 - point.y)
		if point.x > -0.55 and point.x < 0.55:
			support_min = minf(support_min, point.y - 0.70)
			support_max = maxf(support_max, point.y - 0.70)
		if point.x > -0.99 and point.x < -0.55 and absf(point.z) < 0.34:
			head_pillow_penetration = maxf(head_pillow_penetration, 0.80 - point.y)
			head_pillow_gap = minf(head_pillow_gap, point.y - 0.80)
		if point.x > 0.65 and absf(point.z) < 0.42:
			foot_cover_gap = minf(foot_cover_gap, point.y - 0.79)
	review["rigid_reclined_bounds_m"] = _aabb_json(_bounds(_rest_points()))
	review["support_region_back_min_gap_m"] = support_min
	review["support_region_body_depth_m"] = support_max - support_min
	review["mattress_penetration_m"] = mattress_penetration
	review["pillow_envelope_penetration_m"] = head_pillow_penetration
	review["head_pillow_min_gap_m"] = head_pillow_gap
	review["foot_cover_min_gap_m"] = foot_cover_gap
	review["native_patient_pose_acceptance"] = "FAIL: rigid standing rest body is not supported naturally at pillow/heels; numerical nonpenetration is not bed-pose acceptance"
	review["physics_support_hits_m"] = {"bed_y": bed_hit.position.y, "floor_y": floor_hit.position.y}
	review["contact_measurement_scope"] = "Independent actual neutral skin vertices: Godot bone global poses times inverse bind, weighted per vertex, current actor scale. No pressure or animation acceptance. Pillow metric conservative box envelope."
	var skeleton := actor.find_child("Skeleton3D", true, false) as Skeleton3D
	var neck_bone := skeleton.find_bone("tripo__Head_0")
	if neck_bone < 0: neck_bone = skeleton.find_bone("tripo::Head_0")
	if neck_bone < 0:
		push_error("Current anatomical neck bone missing")
		quit(1)
		return
	var neck := skeleton.to_global(skeleton.get_bone_global_rest(neck_bone).origin)
	var mark := MeshInstance3D.new()
	mark.name = "IsolatedEX011NeckPlacementProbe"
	var text := TextMesh.new()
	text.text = "EX-011"
	text.font_size = 32
	text.pixel_size = 0.00055
	text.depth = 0.0001
	mark.mesh = text
	var ink := StandardMaterial3D.new()
	ink.albedo_color = Color(0.17, 0.04, 0.065)
	ink.roughness = 1.0
	ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	mark.material_override = ink
	actor.add_child(mark)
	mark.position = actor.to_local(neck) + Vector3(0.055, 0.012, 0.023)
	mark.scale = Vector3.ONE * 0.45
	mark.rotation.y = PI / 3.0
	review["neck_probe_position_m"] = [mark.global_position.x, mark.global_position.y, mark.global_position.z]
	review["neck_probe_limit"] = "Isolated TextMesh placement on anatomical neck reference; not a production skin decal, deforming attachment or reveal interaction."
	if capture_enabled:
		if not neck_only: await _capture("rigid-bed-contact-prototype", Vector3(1.9, 2.6, 2.4), Vector3(-0.05, 0.82, 0), review)
		await _capture("neck-placement-detail", mark.global_position + Vector3(0.09, 0.31, 0.30), mark.global_position, review)
	var geometry := {"mesh_instances": 0, "triangles": 0, "materials": 0}
	for node in ward.get_children():
		if node is MeshInstance3D:
			geometry.mesh_instances += 1
			geometry.triangles += (node as MeshInstance3D).mesh.get_faces().size() / 3
	geometry.materials = ward.materials.size() + 1
	review["ward_geometry_excluding_avatar"] = geometry
	review["floor_top_m"] = 0.0
	review["lowest_caster_m"] = 0.0
	review["remaining"] = ["Native patient reclining/sitting pose, pressure/contact and natural hands", "Hospital gown/costume and facial acting", "Deforming EX-011 skin mark and interaction", "Campaign route, audio and real-device performance"]
	if standing_bounds.size.y < 1.5 or standing_bounds.size.y > 1.9 or rotated_bounds.size.x > 2.12:
		push_error("Bed/person scale contract failed")
		quit(1)
		return
	var file := FileAccess.open(folder + "review.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(review, "\t"))
	file.close()
	print("PASS ward local geometry/bed scale; character pose/contact PARTIAL ", JSON.stringify(review))
	ward.queue_free()
	await process_frame
	quit(0)

func _rest_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	var skeleton := actor.find_child("Skeleton3D", true, false) as Skeleton3D
	skeleton.force_update_all_bone_transforms()
	for node in actor.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.mesh or mesh.name == "IsolatedEX011NeckPlacementProbe": continue
		var transforms: Array[Transform3D] = []
		if mesh.skin:
			for bind in range(mesh.skin.get_bind_count()):
				var bone := mesh.skin.get_bind_bone(bind)
				if bone < 0: bone = skeleton.find_bone(mesh.skin.get_bind_name(bind))
				transforms.append(skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind))
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if transforms.is_empty():
				for vertex in vertices: points.append(mesh.to_global(vertex))
				continue
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var influences := bones.size() / vertices.size()
			for vertex in range(vertices.size()):
				var skinned := Vector3.ZERO
				for influence in range(influences):
					var index := vertex * influences + influence
					if weights[index] > 0:
						skinned += (transforms[bones[index]] * vertices[vertex]) * weights[index]
				points.append(skeleton.to_global(skinned))
	return points

func _bounds(points: PackedVector3Array) -> AABB:
	var bounds := AABB(points[0], Vector3.ZERO)
	for point in points: bounds = bounds.expand(point)
	return bounds

func _aabb_json(bounds: AABB) -> Dictionary:
	return {"min": [bounds.position.x, bounds.position.y, bounds.position.z], "size": [bounds.size.x, bounds.size.y, bounds.size.z]}

func _capture(label: String, from: Vector3, target: Vector3, review: Dictionary) -> void:
	camera.position = from
	camera.look_at(target)
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	picture.save_png(ProjectSettings.globalize_path(OUTPUT) + label + ".png")
	review.captures.append({"name": label, "size": [picture.get_width(), picture.get_height()]})
