class_name FloatingPod
extends Node3D

signal pulse_emitted()
signal tactical_scan_completed(target: Node3D)

@export var follow_target: Node3D
@export var aim_target: Node3D
@export var chapter_enabled := true

var float_offset: Vector3 = Vector3(0.45, 1.8, 0.25)
var current_time: float = 0.0
var scan_cooldown: float = 0.0
var reduced_motion := false

@onready var searchlight: SpotLight3D = $Searchlight if has_node("Searchlight") else null

func _ready() -> void:
	set_chapter_enabled(chapter_enabled)
	if searchlight:
		searchlight.shadow_enabled = false
	_set_guide_shadow_casting($GuideCore)
	_apply_companion_cel_shading()

func set_chapter_enabled(enabled: bool) -> void:
	chapter_enabled = enabled
	visible = enabled
	set_process(enabled)
	if not enabled:
		follow_target = null
		aim_target = null
		scan_cooldown = 0.0
	var light := get_node_or_null("Searchlight") as SpotLight3D
	if light: light.visible = enabled

func _apply_companion_cel_shading() -> void:
	var guide_core = get_node_or_null("GuideCore")
	if guide_core:
		var cel_shader = load("res://shaders/anime_cel.gdshader")
		var outline_shader = load("res://shaders/anime_outline.gdshader")
		var applicator = load("res://scripts/combat/shader_applicator.gd")
		if cel_shader and applicator:
			applicator.apply_cel_shader(
				guide_core,
				cel_shader,
				Color(1.0, 1.0, 1.0, 1.0),
				Color(0.15, 0.75, 0.95, 1.0), # Cyan aura rim
				Color(0.22, 0.28, 0.38, 1.0),
				3.2,
				0.6,
				outline_shader
			)

func _set_guide_shadow_casting(node: Node) -> void:
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_set_guide_shadow_casting(child)

func _process(delta: float) -> void:
	if not chapter_enabled: return
	current_time += delta
	if not reduced_motion and has_node("OuterHalo"):
		$OuterHalo.rotate_object_local(Vector3.FORWARD, delta * 0.7)
	if not reduced_motion and has_node("InnerHalo"):
		$InnerHalo.rotate_object_local(Vector3.UP, delta * 1.1)

	# Follow Player with Spring Damped Lerp
	if follow_target:
		var target_pos: Vector3 = follow_target.global_position + follow_target.global_transform.basis * float_offset
		target_pos = _clear_player_face(target_pos)
		if not reduced_motion: target_pos.y += sin(current_time * 3.5) * 0.06
		global_position = global_position.lerp(target_pos, 1.0 - exp(-10.0 * maxf(delta, 0.0)))

		# Aim tactical spotlight towards enemy or facing direction
		if aim_target:
			var target_look: Vector3 = aim_target.global_position + Vector3(0, 1.0, 0)
			look_at(target_look, Vector3.UP)
		else:
			var echo_look_point := follow_target.global_position + Vector3(0.0, 1.25, 0.0)
			look_at(echo_look_point, Vector3.UP)

	# Handle Tactical Ultrasonic Resonance Scan (Q Key)
	if scan_cooldown > 0.0:
		scan_cooldown -= delta
	elif Input.is_action_just_pressed("companion_scan"):
		trigger_scan()

func _clear_player_face(target_pos: Vector3) -> Vector3:
	if not follow_target is EchoPlayer: return target_pos
	var camera := get_viewport().get_camera_3d()
	if not camera: return target_pos
	var head := follow_target.global_position + Vector3.UP * 1.55
	var rig: Skeleton3D = follow_target._recovery_skeleton
	if is_instance_valid(rig):
		var index: int = rig.find_bone(str(follow_target.rig_profile.get("bones",{}).get("head","")))
		if index >= 0: head = rig.to_global(rig.get_bone_global_pose(index).origin) + Vector3.UP * 0.08
	var ray := head - camera.global_position
	if ray.length_squared() < 0.01: return target_pos
	var along: float = (target_pos-camera.global_position).dot(ray) / ray.length_squared()
	if along > 0 and along < 1 and target_pos.distance_to(camera.global_position+ray*along) < 0.48:
		# Resolve toward screen-left, clear of the persistent right-side directive.
		# This changes the follower's desired position, never the actor or camera.
		return target_pos - camera.global_basis.x * 0.85
	return target_pos

func trigger_scan() -> void:
	if not chapter_enabled: return
	scan_cooldown = 8.0
	emit_signal("pulse_emitted")
	if not aim_target:
		var parent = get_parent()
		if parent:
			aim_target = parent.get_node_or_null("SpecimenEX000")
	if aim_target:
		emit_signal("tactical_scan_completed", aim_target)
		var in_range: bool = true
		if is_inside_tree() and aim_target.is_inside_tree():
			var dist: float = global_position.distance_to(aim_target.global_position)
			in_range = dist <= 16.0
		if in_range:
			aim_target.set("is_staggered", true)
			aim_target.set("stagger_timer", 2.0)
			if aim_target.has_signal("stagger_changed"):
				aim_target.emit_signal("stagger_changed", true)
