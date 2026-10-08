extends Node3D

## Direct-skin ink projected once onto authored neck atlas; native GPU skin.
## Source geometry, inverse binds, rest and all animation keys remain immutable.
const IDENTIFIER := "EX-011"
const NECK_BONE := "tripo__Head_0"
const HEAD_BONE := "tripo__Head_1"
const INK_OFFSET := 0.00015 #0.27mm at1.81 scale prevents z fighting.
var projection_records: Array = []
var placement_report := {}

func _ready() -> void: _attach_identifier.call_deferred()

func _attach_identifier() -> void:
	if not placement_report.is_empty(): return
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	var rig_profile := preload("res://scripts/player/echo_rig_profile.gd").identify(skeleton)
	var body_name := "EchoV31BodyAndCoat" if rig_profile.get("id") == preload("res://scripts/player/echo_rig_profile.gd").V31_ID else "EchoOpeningUniformBody"
	var body := find_child(body_name, true, false) as MeshInstance3D
	var neck_bone: String = str(rig_profile.get("bones",{}).get("neck",""))
	var head_bone: String = str(rig_profile.get("bones",{}).get("head",""))
	var local_forward: Vector3 = rig_profile.get("local_forward",Vector3.ZERO)
	if rig_profile.is_empty() or not body or not body.skin or skeleton.find_bone(neck_bone) < 0 or skeleton.find_bone(head_bone) < 0:
		push_warning("EX-011: unsupported character/neck map; no guessed attachment")
		return
	var material := body.get_active_material(0)
	var texture: Texture2D
	if material is BaseMaterial3D: texture = material.albedo_texture
	elif material is ShaderMaterial: texture = material.get_shader_parameter("albedo_texture")
	if not texture:
		push_warning("EX-011: authored skin atlas unavailable; no cloth placement")
		return
	var atlas := texture.get_image()
	var source := body.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = source[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
	var source_bones: PackedInt32Array = source[Mesh.ARRAY_BONES]
	var source_weights: PackedFloat32Array = source[Mesh.ARRAY_WEIGHTS]
	var influence_count := source_bones.size() / vertices.size()
	var bind_matrices: Array[Transform3D] = []
	for bind in body.skin.get_bind_count():
		var bone := body.skin.get_bind_bone(bind)
		if bone < 0: bone = skeleton.find_bone(body.skin.get_bind_name(bind))
		bind_matrices.append(skeleton.get_bone_global_rest(bone) * body.skin.get_bind_pose(bind))
	var rest_points := PackedVector3Array()
	for v in vertices.size():
		var position := Vector3.ZERO
		for i in influence_count:
			position += (bind_matrices[source_bones[v * influence_count + i]] * vertices[v]) * source_weights[v * influence_count + i]
		rest_points.append(position)
	var neck := skeleton.get_bone_global_rest(skeleton.find_bone(neck_bone)).origin
	var head := skeleton.get_bone_global_rest(skeleton.find_bone(head_bone)).origin
	var up := (head - neck).normalized()
	var triangles: Array = []
	for i in range(0, indices.size(), 3):
		var a := indices[i]
		var b := indices[i + 1]
		var c := indices[i + 2]
		var center := (rest_points[a] + rest_points[b] + rest_points[c]) / 3.0
		if center.y < neck.y - 0.018 or center.y > head.y - 0.006: continue
		if not _skin_texel(atlas, (uv[a] + uv[b] + uv[c]) / 3.0): continue
		triangles.append([a, b, c])
	var template := TextMesh.new()
	template.text = IDENTIFIER
	template.font_size = 24
	template.pixel_size = 0.00027
	template.depth = 0.0
	template.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	template.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var faces := template.get_faces()
	var chosen: Array = []
	var chosen_angle := 0.0
	var chosen_center := Vector3.ZERO
	#Finite placement search over measured neck skin, never another bone.
	for height in [0.004, 0.010, -0.002]:
		if not chosen.is_empty(): break
		for angle in [30.0, 15.0, 0.0]:
			var outward := Basis(Vector3.UP,-deg_to_rad(angle))*local_forward
			outward = (outward - up * outward.dot(up)).normalized()
			var tangent := up.cross(outward).normalized()
			var center: Vector3 = neck + up * float(height)
			var attempt: Array = []
			for glyph in faces:
				var target: Vector3 = center + tangent * glyph.x + up * glyph.y
				var hit := _project(target + outward * 0.18, -outward, triangles, rest_points, uv, atlas)
				if hit.is_empty():
					attempt.clear()
					break
				attempt.append(hit)
			if attempt.size() == faces.size() and not attempt.is_empty():
				chosen = attempt
				chosen_angle = angle
				chosen_center = center
				break
	if chosen.is_empty():
		push_warning("EX-011: complete lettering cannot fit exposed neck; no floating substitute")
		return
	# Ink lives in the body's own UV atlas, so skinning/face deformation cannot
	# separate lettering from skin. Keep the imported atlas and every material
	# parameter immutable; only this instance receives the stamped copy.
	var stamped := atlas.duplicate() as Image
	if stamped.is_compressed(): stamped.decompress()
	stamped.convert(Image.FORMAT_RGBA8)
	var ink_pixels := 0
	var outward := Basis(Vector3.UP,-deg_to_rad(chosen_angle))*local_forward
	outward = (outward - up * outward.dot(up)).normalized()
	var tangent := up.cross(outward).normalized()
	# Clip each glyph against each source triangle before converting to UV.
	# Converting a whole glyph across UV seams fills unrelated atlas regions.
	for triangle in triangles:
		var p0: Vector3 = rest_points[triangle[0]]
		var p1: Vector3 = rest_points[triangle[1]]
		var p2: Vector3 = rest_points[triangle[2]]
		var normal := (p1 - p0).cross(p2 - p0).normalized()
		if absf(normal.dot(outward)) < 0.25: continue
		var projected := PackedVector2Array()
		for point in [p0, p1, p2]:
			projected.append(Vector2((point - chosen_center).dot(tangent), (point - chosen_center).dot(up)))
		for face in range(0, faces.size(), 3):
			var glyph := PackedVector2Array([Vector2(faces[face].x, faces[face].y), Vector2(faces[face + 1].x, faces[face + 1].y), Vector2(faces[face + 2].x, faces[face + 2].y)])
			var clipped := Geometry2D.intersect_polygons(glyph, projected)
			for polygon in clipped:
				if polygon.size() < 3: continue
				var center := Vector2.ZERO
				for point in polygon: center += point
				center /= polygon.size()
				var target: Vector3 = chosen_center + tangent * center.x + up * center.y
				var visible := _project(target + outward * 0.18, -outward, triangles, rest_points, uv, atlas)
				if visible.is_empty() or visible.ids != triangle: continue
				var polygon_uv := PackedVector2Array()
				for point in polygon:
					var bary := _barycentric(Vector3(point.x, point.y, 0), Vector3(projected[0].x, projected[0].y, 0), Vector3(projected[1].x, projected[1].y, 0), Vector3(projected[2].x, projected[2].y, 0))
					var mapped: Vector2 = uv[triangle[0]] * bary.x + uv[triangle[1]] * bary.y + uv[triangle[2]] * bary.z
					polygon_uv.append(mapped)
					projection_records.append({"ids": triangle, "bary": bary, "normal": normal, "uv": mapped})
				for index in range(1, polygon_uv.size() - 1):
					ink_pixels += _stamp_triangle(stamped, atlas, polygon_uv[0], polygon_uv[index], polygon_uv[index + 1])
	if ink_pixels == 0:
		push_warning("EX-011: lettering has no atlas pixels; no invisible success")
		return
	stamped.generate_mipmaps()
	var ink_texture := ImageTexture.create_from_image(stamped)
	var ink_material := material.duplicate() as Material
	if ink_material is BaseMaterial3D: ink_material.albedo_texture = ink_texture
	else: ink_material.set_shader_parameter("albedo_texture", ink_texture)
	body.set_surface_override_material(0, ink_material)
	placement_report = {"bone": neck_bone, "head_bone": head_bone, "rig_profile":rig_profile.id, "body_mesh":body_name, "legacy_fallback": false, "native_skin": true, "method": "instance-local skin albedo ink", "vertices": chosen.size(), "skin_triangles": triangles.size(), "angle_degrees": chosen_angle, "rest_center": [chosen_center.x, chosen_center.y, chosen_center.z], "skin_offset_local_m": 0.0, "atlas_skin_only": true, "ink_pixels": ink_pixels, "atlas_size": [atlas.get_width(), atlas.get_height()]}

func _stamp_triangle(destination: Image, original: Image, a: Vector2, b: Vector2, c: Vector2) -> int:
	var size := Vector2(destination.get_width(), destination.get_height())
	a *= size
	b *= size
	c *= size
	var minimum := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.y, minf(b.y, c.y))).floor()
	var maximum := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.y, maxf(b.y, c.y))).ceil()
	var determinant := (b - a).cross(c - a)
	if absf(determinant) < 0.00001: return 0
	var count := 0
	for y in range(int(minimum.y), int(maximum.y) + 1):
		for x in range(int(minimum.x), int(maximum.x) + 1):
			if x < 0 or y < 0 or x >= destination.get_width() or y >= destination.get_height(): continue
			var delta := Vector2(x + 0.5, y + 0.5) - a
			var u := delta.cross(c - a) / determinant
			var v := (b - a).cross(delta) / determinant
			if u < 0.0 or v < 0.0 or u + v > 1.0: continue
			if not _skin_texel(original, Vector2(x + 0.5, y + 0.5) / size): continue
			destination.set_pixel(x, y, Color(0.12, 0.035, 0.045, 1.0))
			count += 1
	return count
func _project(origin: Vector3, direction: Vector3, triangles: Array, points: PackedVector3Array, uv: PackedVector2Array, atlas: Image) -> Dictionary:
	var result := {}
	var nearest := INF
	for triangle in triangles:
		var a: Vector3 = points[triangle[0]]
		var b: Vector3 = points[triangle[1]]
		var c: Vector3 = points[triangle[2]]
		var hit = Geometry3D.ray_intersects_triangle(origin, direction, a, b, c)
		if hit == null: continue
		var distance := origin.distance_to(hit)
		if distance >= nearest: continue
		var bary := _barycentric(hit, a, b, c)
		if not _skin_texel(atlas, uv[triangle[0]] * bary.x + uv[triangle[1]] * bary.y + uv[triangle[2]] * bary.z): continue
		nearest = distance
		var normal := (b - a).cross(c - a).normalized()
		if normal.dot(direction) > 0: normal = -normal
		result = {"position": hit, "normal": normal, "ids": triangle, "bary": bary, "uv": uv[triangle[0]] * bary.x + uv[triangle[1]] * bary.y + uv[triangle[2]] * bary.z}
	return result

func _barycentric(point: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var v0 := b - a
	var v1 := c - a
	var v2 := point - a
	var denominator := v0.dot(v0) * v1.dot(v1) - v0.dot(v1) * v0.dot(v1)
	var y := (v1.dot(v1) * v2.dot(v0) - v0.dot(v1) * v2.dot(v1)) / denominator
	var z := (v0.dot(v0) * v2.dot(v1) - v0.dot(v1) * v2.dot(v0)) / denominator
	return Vector3(1.0 - y - z, y, z)

func _skin_texel(atlas: Image, uv: Vector2) -> bool:
	var color := atlas.get_pixel(clampi(int(uv.x * atlas.get_width()), 0, atlas.get_width() - 1), clampi(int(uv.y * atlas.get_height()), 0, atlas.get_height() - 1))
	return color.r > 0.25 and color.r - color.b > 0.025 and color.r - color.g > 0.008

func _ink_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.035, 0.045, 1.0)
	material.roughness = 0.96
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
