class_name LocomotionAnimController
extends Node

## AAA Locomotion Animation Blending & Root Motion Controller
## Simulates 4-directional blend spaces, inertia skid/foot-planting, and weapon attack root motion.

signal skid_triggered(intensity: float)
signal root_motion_started(step: int, distance: float)
signal root_motion_finished(step: int)

enum LocomotionState {
	IDLE,
	WALK,
	RUN,
	SPRINT,
	SKID_STOP,
	ATTACK_ROOT_MOTION
}

var current_state: LocomotionState = LocomotionState.IDLE
var blend_pos: Vector2 = Vector2.ZERO
var target_blend: Vector2 = Vector2.ZERO
var blend_smoothing: float = 12.0

var is_combat_stance: bool = false
var is_skidding: bool = false
var skid_timer: float = 0.0
const SKID_DURATION: float = 0.28

var root_motion_active: bool = false
var root_motion_velocity: Vector3 = Vector3.ZERO
var root_motion_timer: float = 0.0
var root_motion_step: int = 1

# Root motion forward displacement specifications (Genshin / NieR heavy feel)
const COMBO_ROOT_MOTION: Dictionary = {
	1: {"distance": 0.85, "duration": 0.22, "speed": 3.86},
	2: {"distance": 1.15, "duration": 0.25, "speed": 4.60},
	3: {"distance": 1.65, "duration": 0.32, "speed": 5.15}
}

func trigger_combo_root_motion(step: int, forward_direction: Vector3) -> void:
	var clamped_step: int = clampi(step, 1, 3)
	root_motion_step = clamped_step
	var spec: Dictionary = COMBO_ROOT_MOTION.get(clamped_step, COMBO_ROOT_MOTION[1])
	root_motion_active = true
	root_motion_timer = spec["duration"]
	var norm_dir: Vector3 = forward_direction.normalized()
	norm_dir.y = 0.0
	root_motion_velocity = norm_dir * spec["speed"]
	current_state = LocomotionState.ATTACK_ROOT_MOTION
	emit_signal("root_motion_started", clamped_step, spec["distance"])

func cancel_root_motion() -> void:
	if root_motion_active:
		root_motion_active = false
		root_motion_velocity = Vector3.ZERO
		emit_signal("root_motion_finished", root_motion_step)

func update(delta: float, input_vec: Vector2, speed: float, was_sprinting: bool, attacking: bool) -> Dictionary:
	# Update Root Motion
	if root_motion_active:
		root_motion_timer -= delta
		if root_motion_timer <= 0.0:
			root_motion_active = false
			var finished_step: int = root_motion_step
			root_motion_velocity = Vector3.ZERO
			emit_signal("root_motion_finished", finished_step)
		return {
			"state": LocomotionState.ATTACK_ROOT_MOTION,
			"root_velocity": root_motion_velocity,
			"is_skid": false,
			"blend": blend_pos,
			"anim_name": "preset_biped_attack_00" + str(root_motion_step) if root_motion_step <= 3 else "preset_biped_attack_001"
		}

	# Update Skid Deceleration
	if is_skidding:
		skid_timer -= delta
		if skid_timer <= 0.0 or input_vec.length() > 0.2:
			is_skidding = false
		else:
			return {
				"state": LocomotionState.SKID_STOP,
				"root_velocity": Vector3.ZERO,
				"is_skid": true,
				"blend": blend_pos,
				"anim_name": "preset_biped_idle_001"
			}

	# Detect Skid Trigger: moving fast (> 6.0 m/s) and player suddenly releases input
	if was_sprinting and speed > 5.5 and input_vec.length() < 0.1 and not is_skidding:
		is_skidding = true
		skid_timer = SKID_DURATION
		current_state = LocomotionState.SKID_STOP
		emit_signal("skid_triggered", speed / 7.2)
		return {
			"state": LocomotionState.SKID_STOP,
			"root_velocity": Vector3.ZERO,
			"is_skid": true,
			"blend": blend_pos,
			"anim_name": "preset_biped_idle_001"
		}

	# Locomotion Blend Space Target calculation
	target_blend = input_vec.normalized()
	blend_pos = blend_pos.lerp(target_blend, blend_smoothing * delta)

	# Determine Locomotion State & Animation
	var anim_name: String = "preset_biped_idle_001"
	if input_vec.length() > 0.1:
		if was_sprinting and speed > 5.0:
			current_state = LocomotionState.SPRINT
			anim_name = "preset_biped_run_001"
		elif speed > 3.0:
			current_state = LocomotionState.RUN
			anim_name = "preset_biped_run_001"
		else:
			current_state = LocomotionState.WALK
			anim_name = "preset_biped_walk_001"
	else:
		current_state = LocomotionState.IDLE
		anim_name = "preset_biped_idle_001"

	return {
		"state": current_state,
		"root_velocity": Vector3.ZERO,
		"is_skid": false,
		"blend": blend_pos,
		"anim_name": anim_name
	}
