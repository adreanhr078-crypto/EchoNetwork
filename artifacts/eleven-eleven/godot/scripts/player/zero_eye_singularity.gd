extends Node3D

signal singularity_activated(intensity)
signal singularity_deactivated
const Attachment = preload("res://scripts/player/zero_manifestation_attachment.gd")
const SurfaceIrisShader = preload("res://shaders/zero_contract_iris.gdshader")
@export var is_singularity_active := false
@export_range(0.0, 0.04) var base_energy := 0.032
var eye_light: OmniLight3D
var iris: MeshInstance3D
var attachment := Attachment.new()
var local_time := 0.0
var current_intensity := 0.0
var pulse_remaining := 0.0
var mount_valid := false
var iris_uses_source_skin := false
var iris_surface_report := {}

func _ready() -> void:
	eye_light = get_node_or_null("EyeLight") as OmniLight3D
	iris = get_node_or_null("ContractIris") as MeshInstance3D
	mount_valid = attachment.configure(self, "eye")
	if mount_valid and iris:
		_build_iris(0.0056 if attachment.profile.id == "echo_opening_v13" else 0.0072)
	# Scene flags never authorize powers before the accepted contract.
	deactivate_singularity()

func _process(delta: float) -> void:
	if not mount_valid or not attachment.update_socket(delta):
		mount_valid = attachment.configure(self, "eye")
		if mount_valid: _build_iris(0.0056 if attachment.profile.id == "echo_opening_v13" else 0.0072)
		else:
			deactivate_singularity()
			return
	if not is_singularity_active: return
	if not attachment.contract_is_sealed():
		deactivate_singularity()
		return
	var reduced := attachment.motion_is_reduced()
	if not reduced:
		local_time += clampf(delta, 0.0, 0.1)
		pulse_remaining = maxf(0.0, pulse_remaining - clampf(delta, 0.0, 0.1))
	var pulse := 0.0 if reduced else minf(pulse_remaining / 0.25, 1.0)
	_set_presentation(current_intensity + pulse * 0.3, reduced)

func activate_singularity(intensity: float = 1.0) -> void:
	if not mount_valid or not attachment.update_socket():
		mount_valid = attachment.configure(self, "eye")
		if mount_valid: _build_iris(0.0056 if attachment.profile.id == "echo_opening_v13" else 0.0072)
	if not is_finite(intensity) or not mount_valid or not attachment.contract_is_sealed(): return
	current_intensity = clampf(intensity, 0.15, 1.8)
	is_singularity_active = true
	visible = true
	attachment.set_manifested(true)
	attachment.update_socket()
	_set_presentation(current_intensity, attachment.motion_is_reduced())
	singularity_activated.emit(current_intensity)

func deactivate_singularity() -> void:
	is_singularity_active = false
	current_intensity = 0.0
	pulse_remaining = 0.0
	local_time = 0.0
	attachment.set_manifested(false)
	attachment.reset_oscillation()
	visible = false
	if is_instance_valid(iris): iris.visible = false
	if eye_light: eye_light.visible = false
	if iris and iris.material_override is ShaderMaterial:
		iris.material_override.set_shader_parameter("intensity", 0.0)
	singularity_deactivated.emit()

func pulse_singularity(duration: float = 0.6) -> void:
	if not is_finite(duration) or duration <= 0.0 or not is_singularity_active: return
	# Local countdowns cannot revive a dismissed eye through stale timers.
	pulse_remaining = minf(duration, 1.2)

func _set_presentation(intensity: float, reduced: bool) -> void:
	var closure := attachment.eyelid_closure()
	if is_instance_valid(iris): iris.visible = is_singularity_active and closure < 0.68
	if eye_light:
		eye_light.visible = true
		var base_light: float = minf(base_energy * intensity, 0.03) * (1.0 - closure)
		eye_light.light_energy = attachment.get_eye_glow_pulse(local_time, base_light)
	if iris and iris.material_override is ShaderMaterial:
		iris.material_override.set_shader_parameter("local_time", local_time)
		iris.material_override.set_shader_parameter("intensity", intensity)
		iris.material_override.set_shader_parameter("reduced_motion", reduced)

func _build_iris(radius: float) -> void:
	if attachment.profile.id == Attachment.RigProfile.V31_ID:
		if not _build_source_iris(): mount_valid = false
		return
	iris_uses_source_skin = false
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.append(Vector3(0, 0, 0.00055))
	normals.append(Vector3.BACK)
	uvs.append(Vector2(0.5, 0.5))
	for segment in 65:
		var angle := TAU * float(segment) / 64.0
		vertices.append(Vector3(cos(angle) * radius, sin(angle) * radius * 0.94, 0.0))
		normals.append(Vector3.BACK)
		uvs.append(Vector2(cos(angle), sin(angle)) * 0.5 + Vector2(0.5, 0.5))
	for segment in 64:
		indices.append_array(PackedInt32Array([0, segment + 1, segment + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	iris.mesh = mesh
	iris.material_override = iris.material_override.duplicate() as ShaderMaterial

func _build_source_iris() -> bool:
	# The adopted V31 already has an authored iris/aperture and pupil. Copy only
	# its eye surface with identical UV/bone weights; recolour cyan atlas texels.
	# The source body, atlas, rest and binds stay immutable and no disc is added.
	var body := attachment.avatar_root.find_child("EchoV31BodyAndCoat", true, false) as MeshInstance3D
	if not body or not body.mesh or not body.skin or not is_instance_valid(iris): return false
	var source := body.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = source[Mesh.ARRAY_TEX_UV]
	var triangles: PackedInt32Array = source[Mesh.ARRAY_INDEX]
	var bones: PackedInt32Array = source[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = source[Mesh.ARRAY_WEIGHTS]
	var tangents: PackedFloat32Array = source[Mesh.ARRAY_TANGENT]
	if points.is_empty() or bones.is_empty() or uv.is_empty(): return false
	var selected := {}
	var selected_indices := PackedInt32Array()
	for face in range(0, triangles.size(), 3):
		var near_iris := false
		for corner in 3:
			var index := triangles[face + corner]
			var p := points[index]
			var t := uv[index]
			# Include adjacent authored facial skin for optical vein filaments.
			# UV bounds exclude the separate hair atlas; original surface is untouched.
			if p.x > 0.002 and p.x < 0.045 and p.y > 0.866 and p.y < 0.913 and p.z > 0.045 and p.z < 0.075 and t.x > 0.842 and t.x < 0.890 and t.y > 0.073 and t.y < 0.122:
				near_iris = true
		if not near_iris: continue
		for corner in 3:
			var index := triangles[face + corner]
			if not selected.has(index): selected[index] = selected.size()
			selected_indices.append(selected[index])
	if selected.size() < 20: return false
	var output := []
	output.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array()
	var copied_normals := PackedVector3Array()
	var copied_uv := PackedVector2Array()
	var copied_bones := PackedInt32Array()
	var copied_weights := PackedFloat32Array()
	var copied_tangents := PackedFloat32Array()
	var influence_count: int = bones.size() / points.size()
	for index in selected:
		# 0.21mm at the measured 1.752 scale avoids z fighting on the source skin.
		vertices.append(points[index] + normals[index] * 0.00012)
		copied_normals.append(normals[index])
		copied_uv.append(uv[index])
		for influence in influence_count:
			copied_bones.append(bones[index * influence_count + influence])
			copied_weights.append(weights[index * influence_count + influence])
		if not tangents.is_empty():
			for component in 4: copied_tangents.append(tangents[index * 4 + component])
	output[Mesh.ARRAY_VERTEX] = vertices
	output[Mesh.ARRAY_NORMAL] = copied_normals
	output[Mesh.ARRAY_TEX_UV] = copied_uv
	output[Mesh.ARRAY_BONES] = copied_bones
	output[Mesh.ARRAY_WEIGHTS] = copied_weights
	output[Mesh.ARRAY_INDEX] = selected_indices
	if not copied_tangents.is_empty(): output[Mesh.ARRAY_TANGENT] = copied_tangents
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, output, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if influence_count == 8 else 0)
	var source_material := body.get_active_material(0)
	var atlas: Texture2D
	if source_material is BaseMaterial3D: atlas = source_material.albedo_texture
	elif source_material is ShaderMaterial: atlas = source_material.get_shader_parameter("albedo_texture")
	if not atlas: return false
	var material := ShaderMaterial.new()
	material.shader = SurfaceIrisShader
	material.set_shader_parameter("source_albedo", atlas)
	iris.reparent(body, false)
	iris.transform = Transform3D.IDENTITY
	iris.mesh = mesh
	iris.skin = body.skin
	iris.skeleton = iris.get_path_to(attachment.skeleton)
	iris.material_override = material
	iris_uses_source_skin = true
	iris_surface_report = {"method":"actual source iris surface", "source_vertices":points.size(),
		"patch_vertices":selected.size(),"patch_triangles":selected_indices.size() / 3,
		"uv_and_weights_exact":true,"pupil_and_aperture":"retained source atlas",
		"offset_authored_m":0.00012,"side":"anatomical left, positive X","veins":"optical shader only on adjacent source skin; no original geometry edits"}
	return true

func _exit_tree() -> void:
	if iris_uses_source_skin and is_instance_valid(iris) and iris.get_parent() != self:
		iris.queue_free()
