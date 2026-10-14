extends RefCounted

## Follow measured deforming avatar bones without altering rest or authority.
const RigProfile = preload("res://scripts/player/echo_rig_profile.gd")
var host: Node3D
var authority: Node
var presentation: Node
var skeleton: Skeleton3D
var avatar_root: Node
var bone_index := -1
var profile := {}
var rest_socket := Transform3D.IDENTITY
var role := ""
var eyelid_meshes: Array[MeshInstance3D] = []
var skin_bones := PackedInt32Array()
var skin_weights := PackedFloat32Array()

# Manifestation procedural animation & levitation state
var is_manifested := false
var oscillation_time := 0.0
var hover_amplitude := 0.0035
var hover_frequency := 1.6
var breathing_tilt_degrees := 1.8
var glow_pulse_amplitude := 0.16
var emergence_tween: Tween

func configure(node: Node3D, socket_role: String) -> bool:
	host = node
	role = socket_role
	authority = null
	presentation = null
	skeleton = null
	avatar_root = null
	bone_index = -1
	profile = {}
	eyelid_meshes.clear()
	skin_bones.clear()
	skin_weights.clear()
	is_manifested = false
	oscillation_time = 0.0
	var ancestor: Node = node.get_parent()
	while ancestor:
		if _has_property(ancestor, "contract_with_zero_sealed"): authority = ancestor
		if _has_property(ancestor, "reduced_motion"): presentation = ancestor
		ancestor = ancestor.get_parent()
	if not is_instance_valid(authority): return false
	var model := authority.get_node_or_null("ModelRoot")
	if not model: return false
	# The generated wing has its own Skeleton3D; inspect only avatar profiles.
	for child in model.get_children():
		if not child is Node3D or child == host or not child.visible: continue
		var candidate := child.find_child("Skeleton3D", true, false) as Skeleton3D
		if not candidate and child is Skeleton3D: candidate = child
		var identified := RigProfile.identify(candidate)
		if not identified.is_empty():
			skeleton = candidate
			avatar_root = child
			profile = identified
			break
	if not is_instance_valid(skeleton): return false
	if socket_role == "eye": _collect_eyelids(avatar_root)
	var forward: Vector3 = profile.local_forward
	var left := Vector3.UP.cross(forward).normalized()
	var frame := Basis(left, Vector3.UP, forward)
	var avatar_to_skeleton := skeleton.global_transform.affine_inverse() * (avatar_root as Node3D).global_transform
	var point := Vector3.ZERO
	if socket_role == "eye":
		bone_index = skeleton.find_bone(str(profile.bones.head))
		# v13's sparse cyan atlas samples were hair highlights, rejected in
		# actual native close-up. Its iris centre is measured in that view and
		# seated on the source face surface. V31 has a distinct dense iris atlas.
		point = Vector3(0.0773, 0.89284, -0.02318) if profile.id == RigProfile.LEGACY_ID else Vector3(0.01751708, 0.89248657, 0.06093486)
		# v13's armature node has a +0.5 Y origin. Raw mesh/atlas landmarks
		# live in avatar coordinates, not in Skeleton3D coordinates.
		point = avatar_to_skeleton * point
	elif socket_role == "wing":
		var legacy: bool = profile.id == RigProfile.LEGACY_ID
		# Tripo's legacy Left/Right labels oppose the measured +X facing. Its
		# negative-Z arm base is anatomical left. A chest socket follows that
		# shoulder without inheriting the upper arm's full gait swing.
		var shoulder := "tripo__0_Right_Limb_0" if legacy else "LeftShoulder"
		var shoulder_index := skeleton.find_bone(shoulder)
		bone_index = skeleton.find_bone("tripo__Spine_2") if legacy else shoulder_index
		if shoulder_index < 0: return false
		if bone_index < 0: return false
		var shoulder_offset := left * 0.020 + Vector3.UP * 0.020 - forward * 0.024 if legacy else Vector3(0.036, 0.005, -0.025)
		point = skeleton.get_bone_global_rest(shoulder_index).origin + avatar_to_skeleton.basis * shoulder_offset
	else: return false
	if bone_index < 0: return false
	rest_socket = Transform3D(avatar_to_skeleton.basis * frame, point)
	if socket_role == "eye": _bind_skin_influences(point)
	update_socket()
	return true

func update_socket(delta: float = 0.0) -> bool:
	if not is_instance_valid(host) or not is_instance_valid(skeleton) or not is_instance_valid(avatar_root) or not (avatar_root as Node3D).visible or bone_index < 0: return false
	var deformation := skeleton.get_bone_global_pose(bone_index) * skeleton.get_bone_global_rest(bone_index).affine_inverse()
	if not skin_bones.is_empty():
		var blended := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
		for index in skin_bones.size():
			var bone := skin_bones[index]
			var weight := skin_weights[index]
			var transform := skeleton.get_bone_global_pose(bone) * skeleton.get_bone_global_rest(bone).affine_inverse()
			blended.basis.x += transform.basis.x * weight
			blended.basis.y += transform.basis.y * weight
			blended.basis.z += transform.basis.z * weight
			blended.origin += transform.origin * weight
		deformation = blended
	var socket_transform := rest_socket
	if delta > 0.0 and not motion_is_reduced() and is_manifested and contract_is_sealed():
		oscillation_time += delta
	if oscillation_time > 0.0 and not motion_is_reduced() and is_manifested and contract_is_sealed():
		if role == "wing":
			var hover := get_wing_hover_offset(oscillation_time)
			var breath := get_wing_breathing_basis(oscillation_time)
			socket_transform = Transform3D(socket_transform.basis * breath, socket_transform.origin + hover)
		elif role == "eye":
			var hover := get_eye_hover_offset(oscillation_time)
			socket_transform = Transform3D(socket_transform.basis, socket_transform.origin + hover)
	host.global_transform = skeleton.global_transform * deformation * socket_transform
	return true

func set_manifested(manifest: bool) -> void:
	is_manifested = manifest
	if not manifest:
		reset_oscillation()

func reset_oscillation() -> void:
	oscillation_time = 0.0

func advance_oscillation(delta: float) -> void:
	if delta > 0.0 and not motion_is_reduced() and is_manifested and contract_is_sealed():
		oscillation_time += delta

## Procedural breathing / pulsing glow for Zero's singularity eye.
func get_eye_glow_pulse(time_sec: float = -1.0, base: float = 1.0) -> float:
	if motion_is_reduced():
		return base
	var t: float = oscillation_time if time_sec < 0.0 else time_sec
	var beat := 1.0 + glow_pulse_amplitude * sin(t * 2.2) + 0.04 * sin(t * 4.4)
	return base * beat

## Procedural micro-levitation wave for Zero's eye.
func get_eye_hover_offset(time_sec: float = -1.0) -> Vector3:
	if motion_is_reduced() or not is_manifested:
		return Vector3.ZERO
	var t: float = oscillation_time if time_sec < 0.0 else time_sec
	var wave_y := sin(t * 2.0) * 0.0004
	var wave_z := sin(t * 1.5) * 0.0002
	return Vector3(0.0, wave_y, wave_z)

## Procedural levitation wave for Zero's shadow wing.
func get_wing_hover_offset(time_sec: float = -1.0) -> Vector3:
	if motion_is_reduced() or not is_manifested:
		return Vector3.ZERO
	var t: float = oscillation_time if time_sec < 0.0 else time_sec
	var wave_y := sin(t * 1.4) * hover_amplitude
	var wave_x := sin(t * 0.9) * (hover_amplitude * 0.4)
	var wave_z := sin(t * 1.1) * (hover_amplitude * 0.6)
	return Vector3(wave_x, wave_y, wave_z)

## Procedural breathing oscillation rotation for Zero's shadow wing.
func get_wing_breathing_basis(time_sec: float = -1.0) -> Basis:
	if motion_is_reduced() or not is_manifested:
		return Basis.IDENTITY
	var t: float = oscillation_time if time_sec < 0.0 else time_sec
	var roll := sin(t * 1.4) * deg_to_rad(breathing_tilt_degrees)
	var pitch := sin(t * 1.0) * deg_to_rad(breathing_tilt_degrees * 0.6)
	var yaw := sin(t * 0.7) * deg_to_rad(breathing_tilt_degrees * 0.4)
	return Basis.from_euler(Vector3(pitch, yaw, roll))

## Procedural pulsing glow energy for Zero's shadow wing.
func get_wing_glow_energy(base_energy: float, time_sec: float = -1.0) -> float:
	if motion_is_reduced():
		return base_energy
	var t: float = oscillation_time if time_sec < 0.0 else time_sec
	return base_energy * (1.0 + 0.16 * sin(t * 1.5))

## Ominous ease curve: starts slow and menacing, then unfolds with controlled dark grace.
func ominous_ease(progress: float) -> float:
	var t := clampf(progress, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

## Wing emergence scale from folded / zero to full spread.
func get_emergence_scale(progress: float, target_scale: Vector3) -> Vector3:
	if motion_is_reduced():
		return target_scale
	var p := ominous_ease(progress)
	return target_scale * maxf(0.001, p)

## Wing emergence rotation unfolding from cocoon tuck to full spread.
func get_emergence_rotation(progress: float) -> Vector3:
	if motion_is_reduced():
		return Vector3.ZERO
	var p := ominous_ease(progress)
	var folded := Vector3(deg_to_rad(-25.0), deg_to_rad(30.0), deg_to_rad(-40.0))
	return folded.lerp(Vector3.ZERO, p)

## Animate wing emergence unfolding via Tween on contract acceptance or awakening.
func animate_wing_emergence(target_node: Node3D, target_scale: Vector3, duration: float = 1.1) -> Tween:
	if not is_instance_valid(target_node):
		return null
	if is_instance_valid(emergence_tween) and emergence_tween.is_running():
		emergence_tween.kill()
	if motion_is_reduced():
		target_node.scale = target_scale
		target_node.rotation = Vector3.ZERO
		return null
	target_node.scale = target_scale * 0.001
	target_node.rotation = Vector3(deg_to_rad(-25.0), deg_to_rad(30.0), deg_to_rad(-40.0))
	emergence_tween = target_node.create_tween()
	emergence_tween.set_parallel(true)
	emergence_tween.set_ease(Tween.EASE_OUT)
	emergence_tween.set_trans(Tween.TRANS_CUBIC)
	emergence_tween.tween_property(target_node, "scale", target_scale, duration)
	emergence_tween.tween_property(target_node, "rotation", Vector3.ZERO, duration)
	return emergence_tween

## Accessibility: Audio settings inspection.
func is_audio_muted() -> bool:
	if is_instance_valid(presentation) and _has_property(presentation, "audio_muted") and presentation.get("audio_muted") == true:
		return true
	if is_instance_valid(authority) and _has_property(authority, "audio_muted") and authority.get("audio_muted") == true:
		return true
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx >= 0 and AudioServer.is_bus_mute(master_idx):
		return true
	return false

func get_audio_volume() -> float:
	if is_audio_muted():
		return 0.0
	if is_instance_valid(presentation) and _has_property(presentation, "audio_volume"):
		return clampf(float(presentation.get("audio_volume")), 0.0, 1.0)
	if is_instance_valid(authority) and _has_property(authority, "audio_volume"):
		return clampf(float(authority.get("audio_volume")), 0.0, 1.0)
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		return clampf(db_to_linear(AudioServer.get_bus_volume_db(master_idx)), 0.0, 1.0)
	return 1.0

func can_play_audio() -> bool:
	return not is_audio_muted() and get_audio_volume() > 0.0

func contract_is_sealed() -> bool:
	return is_instance_valid(authority) and authority.get("contract_with_zero_sealed") == true

func motion_is_reduced() -> bool:
	return is_instance_valid(presentation) and presentation.get("reduced_motion") == true

func eyelid_closure() -> float:
	var closure := 0.0
	for mesh in eyelid_meshes:
		if not is_instance_valid(mesh): continue
		var index := mesh.find_blend_shape_by_name("Blink_L")
		if index >= 0: closure = maxf(closure, clampf(mesh.get_blend_shape_value(index), 0.0, 1.0))
	return closure

func _collect_eyelids(node: Node) -> void:
	if node is MeshInstance3D and node.mesh and node.find_blend_shape_by_name("Blink_L") >= 0:
		eyelid_meshes.append(node)
	for child in node.get_children(): _collect_eyelids(child)

func _bind_skin_influences(socket_point: Vector3) -> void:
	var mesh_name := "EchoOpeningUniformBody" if profile.id == RigProfile.LEGACY_ID else "EchoV31BodyAndCoat"
	var body := avatar_root.find_child(mesh_name, true, false) as MeshInstance3D
	if not body or not body.mesh or not body.skin: return
	var arrays := body.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	if vertices.is_empty() or bones.is_empty(): return
	var count: int = bones.size() / vertices.size()
	var bind_bones := PackedInt32Array()
	var rest_matrices: Array[Transform3D] = []
	for bind in body.skin.get_bind_count():
		var bone := body.skin.get_bind_bone(bind)
		if bone < 0: bone = skeleton.find_bone(body.skin.get_bind_name(bind))
		if bone < 0: return
		bind_bones.append(bone)
		rest_matrices.append(skeleton.get_bone_global_rest(bone) * body.skin.get_bind_pose(bind))
	var atlas_point := ((avatar_root as Node3D).global_transform.affine_inverse() * skeleton.global_transform) * socket_point
	var closest := -1
	var best := INF
	for vertex in vertices.size():
		if vertices[vertex].distance_squared_to(atlas_point) > 0.0004: continue
		var rest_point := Vector3.ZERO
		for influence in count:
			var index := vertex * count + influence
			rest_point += (rest_matrices[bones[index]] * vertices[vertex]) * weights[index]
		var distance := rest_point.distance_squared_to(socket_point)
		if distance < best:
			best = distance
			closest = vertex
	if closest < 0 or best > 0.0001: return
	var total := 0.0
	for influence in count:
		var index := closest * count + influence
		if weights[index] <= 0.000001: continue
		skin_bones.append(bind_bones[bones[index]])
		skin_weights.append(weights[index])
		total += weights[index]
	if total > 0.0:
		for index in skin_weights.size(): skin_weights[index] /= total

func _has_property(node: Object, property_name: String) -> bool:
	for entry in node.get_property_list():
		if entry.name == property_name: return true
	return false
