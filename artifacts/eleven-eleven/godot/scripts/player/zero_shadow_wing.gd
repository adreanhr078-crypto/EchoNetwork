extends Node3D

signal wing_manifested(intensity)
signal wing_dismissed

const Attachment = preload("res://scripts/player/zero_manifestation_attachment.gd")
const FeatherScene = preload("res://assets/characters/echo_shadow_wing_feathers_v1.glb")
const DetailShader = preload("res://shaders/zero_feather_detail.gdshader")
@export var is_wing_manifested := false
@export var base_scale := Vector3.ONE
@export_range(0, 3) var quality_tier := 2
var wing_mesh: Node3D
var shadow_particles: CPUParticles3D
var wing_light: OmniLight3D
var feather_skeleton: Skeleton3D
var rest_rotations: Array[Quaternion] = []
var attachment := Attachment.new()
var material_instances: Array[ShaderMaterial] = []
var tip_trails: Array[Node3D] = []
var local_time := 0.0
var reveal := 0.0
var current_intensity := 0.0
var mount_valid := false
var resonance:Node3D
var emergence_hold:=0.0

func _ready() -> void:
	base_scale = base_scale.clamp(Vector3.ONE * 0.25, Vector3.ONE) if base_scale.is_finite() else Vector3.ONE
	wing_mesh = get_node_or_null("WingRoot") as Node3D
	shadow_particles = get_node_or_null("ShadowMistParticles") as CPUParticles3D
	wing_light = get_node_or_null("WingGlowLight") as OmniLight3D
	if wing_mesh:
		var feathers := FeatherScene.instantiate() as Node3D
		# Source node scale means the first physical root starts at X=.052491,
		# not the assumed raw-accessor root. Seat that geometry on the socket.
		feathers.position.x = -0.05249099
		wing_mesh.add_child(feathers)
		feather_skeleton = _find_skeleton(feathers)
		_install_materials(feathers)
		if feather_skeleton:
			for bone in feather_skeleton.get_bone_count(): rest_rotations.append(feather_skeleton.get_bone_pose_rotation(bone))
	mount_valid = attachment.configure(self, "wing") and is_instance_valid(feather_skeleton) and feather_skeleton.get_bone_count() == 16 and not material_instances.is_empty()
	if mount_valid: _create_tip_trails()
	resonance=preload("res://scripts/player/echo_contract_resonance.gd").new()
	resonance.name="ContractResonance"
	add_child(resonance)
	resonance.configure(attachment)
	dismiss_wing()

func _process(delta: float) -> void:
	if not mount_valid or not attachment.update_socket(delta):
		mount_valid = attachment.configure(self, "wing") and is_instance_valid(feather_skeleton)
		if not mount_valid:
			dismiss_wing()
			return
	if not is_wing_manifested: return
	if not attachment.contract_is_sealed():
		dismiss_wing()
		return
	var reduced := attachment.motion_is_reduced()
	var step := clampf(delta, 0.0, 0.1)
	if reduced:
		reveal = 1.0
	else:
		local_time += step
		if emergence_hold>0:emergence_hold=maxf(0.0,emergence_hold-step)
		else:reveal = minf(1.0, reveal + step / 1.1)
	wing_mesh.scale = attachment.get_emergence_scale(reveal, base_scale)
	wing_mesh.rotation = attachment.get_emergence_rotation(reveal)
	_animate_feathers(reduced)
	for material in material_instances:
		material.set_shader_parameter("local_time", local_time)
		material.set_shader_parameter("intensity", current_intensity)
		material.set_shader_parameter("reduced_motion", reduced)
	if shadow_particles: shadow_particles.emitting = not reduced and quality_tier > 0
	if wing_light:
		wing_light.light_energy = attachment.get_wing_glow_energy(minf(0.30 * current_intensity, 0.55), local_time)
	_update_tip_trails(reduced)
	if resonance:resonance.present(local_time,reveal,current_intensity,reduced)

func manifest_wing(intensity: float = 1.0) -> void:
	if not mount_valid or not attachment.update_socket():
		mount_valid = attachment.configure(self, "wing") and is_instance_valid(feather_skeleton)
	if not is_finite(intensity) or not mount_valid or not attachment.contract_is_sealed(): return
	var already_manifested := is_wing_manifested
	is_wing_manifested = true
	visible = true
	current_intensity = clampf(intensity, 0.15, 1.8)
	attachment.set_manifested(true)
	if not already_manifested:
		local_time = 0.0
		reveal = 1.0 if attachment.motion_is_reduced() else 0.04
	attachment.update_socket()
	wing_mesh.scale = attachment.get_emergence_scale(reveal, base_scale)
	wing_mesh.rotation = attachment.get_emergence_rotation(reveal)
	if resonance:resonance.configure(attachment);resonance.present(local_time,reveal,current_intensity,attachment.motion_is_reduced())
	if wing_light:
		wing_light.visible = true
		wing_light.light_energy = attachment.get_wing_glow_energy(minf(0.30 * current_intensity, 0.55), local_time)
	wing_manifested.emit(current_intensity)

func supports_cinematic_framing() -> bool:
	return mount_valid and is_instance_valid(feather_skeleton) and feather_skeleton.get_bone_count() == 16 and attachment.skeleton.global_basis.get_scale().length() <= 3.25

func restart_cinematic_emergence(delay:float=.65) -> void:
	if not is_wing_manifested or not attachment.contract_is_sealed():return
	local_time=0.0
	emergence_hold=0.0 if attachment.motion_is_reduced() else clampf(delay,0.0,1.0)
	reveal=1.0 if attachment.motion_is_reduced() else .02

func complete_cinematic_emergence() -> void:
	if not is_wing_manifested or not attachment.contract_is_sealed():return
	emergence_hold=0.0
	reveal=1.0

func dismiss_wing() -> void:
	is_wing_manifested = false
	visible = false
	reveal = 0.0
	local_time = 0.0
	current_intensity = 0.0
	emergence_hold=0.0
	if resonance:resonance.hide()
	attachment.set_manifested(false)
	attachment.reset_oscillation()
	if is_instance_valid(wing_mesh):
		wing_mesh.scale = base_scale * 0.001
		wing_mesh.rotation = Vector3.ZERO
	if wing_light: wing_light.visible = false
	if shadow_particles: shadow_particles.emitting = false
	for trail in tip_trails:
		trail.set("emitting", false)
		trail.call("clear")
	if feather_skeleton:
		for bone in feather_skeleton.get_bone_count(): feather_skeleton.reset_bone_pose(bone)
	wing_dismissed.emit()

func set_quality_tier(tier: int) -> void:
	quality_tier = clampi(tier, 0, 3)
	if shadow_particles: shadow_particles.amount = 4 if quality_tier < 2 else 12
	if quality_tier == 0:
		for trail in tip_trails:
			trail.set("emitting", false)
			trail.call("clear")

func _animate_feathers(reduced: bool) -> void:
	for fan in 5:
		for segment in 3:
			var bone := feather_skeleton.find_bone("Feather_%d_%d" % [fan, segment])
			if bone < 0: continue
			if reduced:
				feather_skeleton.reset_bone_pose(bone)
				continue
			var phase := local_time * 1.65 - float(segment) * 0.55 + float(fan) * 0.42
			var bending := sin(phase) * (0.018 + float(segment) * 0.009) * reveal
			var twist := sin(phase * 0.73 + 0.7) * 0.024 * reveal
			var unfurl := (1.0 - reveal) * -0.13 if segment == 0 else 0.0
			feather_skeleton.set_bone_pose_rotation(bone, rest_rotations[bone] * Quaternion(Vector3.RIGHT, bending) * Quaternion(Vector3.UP, twist + unfurl))
	feather_skeleton.force_update_all_bone_transforms()

func _create_tip_trails() -> void:
	if not ClassDB.class_exists("Trail3D"): return
	for fan in [1, 4]:
		var trail := ClassDB.instantiate("Trail3D") as Node3D
		if not trail: continue
		trail.name = "VioletFeatherTrace%d" % fan
		trail.set("emitting", false)
		trail.set("width", 0.0015)
		trail.set("lifetime", 0.18)
		trail.set("min_section_length", 0.003)
		trail.set("color", Color(0.29, 0.035, 0.56, 0.32))
		trail.set_meta("fan", fan)
		wing_mesh.add_child(trail)
		tip_trails.append(trail)

func _update_tip_trails(reduced: bool) -> void:
	for i in tip_trails.size():
		var trail := tip_trails[i]
		var emitting := not reduced and reveal > 0.95 and quality_tier > 0 and (quality_tier > 1 or i == 0)
		trail.set("emitting", emitting)
		if not emitting:
			trail.call("clear")
			continue
		var fan: int = trail.get_meta("fan")
		var bone := feather_skeleton.find_bone("Feather_%d_2" % fan)
		var angle := deg_to_rad(-7.0 if fan == 1 else 39.0)
		var tip := Vector3(cos(angle) * 0.69, sin(angle) * 0.69, 0)
		var pose := feather_skeleton.get_bone_global_pose(bone) * feather_skeleton.get_bone_global_rest(bone).affine_inverse()
		trail.global_position = feather_skeleton.global_transform * (pose * tip)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found: return found
	return null

func _install_materials(node: Node) -> void:
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var original := node.get_active_material(surface) as BaseMaterial3D
			if not original or not original.albedo_texture: continue
			var material := ShaderMaterial.new()
			material.shader = DetailShader
			material.set_shader_parameter("source_albedo", original.albedo_texture)
			material.set_shader_parameter("source_normal", original.normal_texture)
			material.set_shader_parameter("has_normal", original.normal_enabled and original.normal_texture != null)
			material.set_shader_parameter("source_roughness", original.roughness_texture)
			material.set_shader_parameter("source_metallic", original.metallic_texture)
			material.set_shader_parameter("has_roughness", original.roughness_texture != null)
			material.set_shader_parameter("has_metallic", original.metallic_texture != null)
			material.set_shader_parameter("roughness_channel", original.roughness_texture_channel)
			material.set_shader_parameter("metallic_channel", original.metallic_texture_channel)
			node.set_surface_override_material(surface, material)
			material_instances.append(material)
	for child in node.get_children(): _install_materials(child)
