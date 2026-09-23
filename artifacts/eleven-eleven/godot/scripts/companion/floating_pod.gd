class_name FloatingPod
extends Node3D

signal pulse_emitted()
signal tactical_scan_completed(target: Node3D)

@export var follow_target: Node3D
@export var aim_target: Node3D

var float_offset: Vector3 = Vector3(0.65, 1.4, -0.5)
var current_time: float = 0.0
var scan_cooldown: float = 0.0

@onready var searchlight: SpotLight3D = $Searchlight if has_node("Searchlight") else null

func _process(delta: float) -> void:
	current_time += delta

	# Follow Player with Spring Damped Lerp
	if follow_target:
		var target_pos: Vector3 = follow_target.global_position + follow_target.global_transform.basis * float_offset
		target_pos.y += sin(current_time * 3.5) * 0.06 # Subtle ominous hover bobbing
		global_position = global_position.lerp(target_pos, 10.0 * delta)

		# Aim tactical spotlight towards enemy or facing direction
		if aim_target:
			var target_look: Vector3 = aim_target.global_position + Vector3(0, 1.0, 0)
			look_at(target_look, Vector3.UP)
		else:
			var look_dir: Vector3 = -follow_target.global_transform.basis.z
			look_at(global_position + look_dir, Vector3.UP)

	# Handle Tactical Ultrasonic Resonance Scan (Q Key)
	if scan_cooldown > 0.0:
		scan_cooldown -= delta
	elif Input.is_action_just_pressed("companion_scan"):
		trigger_scan()

func trigger_scan() -> void:
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
