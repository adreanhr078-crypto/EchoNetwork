class_name LocomotionAnimController
extends Node

## Chooses a locomotion clip from horizontal movement. AnimationPlayer owns the crossfade.
## Combat displacement remains scripted until authored root-motion clips exist.

signal skid_triggered(intensity: float)
signal root_motion_started(step: int, distance: float)
signal root_motion_finished(step: int)
signal roll_started(direction: Vector3)
signal roll_finished()
signal hard_landing_started(impact_velocity: float)
signal hard_landing_finished()
signal combat_stance_changed(is_combat: bool)

enum LocomotionState {
	IDLE,
	FIGHT_IDLE,
	WALK,
	RUN,
	SPRINT,
	SKID_STOP,
	ATTACK_ROOT_MOTION,
	ROLLING,
	HARD_LANDING
}

var current_state: LocomotionState = LocomotionState.IDLE
var blend_pos: Vector2 = Vector2.ZERO
var target_blend: Vector2 = Vector2.ZERO
var blend_smoothing: float = 12.0

var is_combat_stance: bool = false
var is_skidding: bool = false
var skid_timer: float = 0.0
const SKID_DURATION: float = 0.28

var is_rolling: bool = false
var roll_timer: float = 0.0
var roll_direction: Vector3 = Vector3.ZERO
const ROLL_DURATION: float = 0.45
const ROLL_SPEED: float = 7.5

var is_hard_landing: bool = false
var hard_landing_timer: float = 0.0
const HARD_LANDING_DURATION: float = 0.38

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

func trigger_roll(direction: Vector3) -> void:
	cancel_root_motion()
	is_skidding = false
	is_hard_landing = false
	is_rolling = true
	roll_timer = ROLL_DURATION
	var d = direction.normalized() if direction.length() > 0.01 else Vector3.FORWARD
	d.y = 0.0
	roll_direction = d.normalized()
	current_state = LocomotionState.ROLLING
	emit_signal("roll_started", roll_direction)

func trigger_hard_landing(impact_velocity: float) -> void:
	cancel_root_motion()
	is_skidding = false
	is_rolling = false
	is_hard_landing = true
	hard_landing_timer = HARD_LANDING_DURATION
	current_state = LocomotionState.HARD_LANDING
	emit_signal("hard_landing_started", impact_velocity)

func set_combat_stance(active: bool) -> void:
	if is_combat_stance != active:
		is_combat_stance = active
		emit_signal("combat_stance_changed", active)

func is_action_locked() -> bool:
	return is_hard_landing or is_rolling

func update(delta: float, input_vec: Vector2, speed: float, sprint_requested: bool, _attacking: bool) -> Dictionary:
	# Update Hard Landing Recovery State
	if is_hard_landing:
		hard_landing_timer -= delta
		if hard_landing_timer <= 0.0:
			is_hard_landing = false
			emit_signal("hard_landing_finished")
		else:
			return {
				"state": LocomotionState.HARD_LANDING,
				"root_velocity": Vector3.ZERO,
				"is_skid": false,
				"is_rolling": false,
				"is_hard_landing": true,
				"blend": blend_pos,
				"anim_name": "preset_biped_hard_landing_001"
			}

	# Update Combat Dodge Roll State
	if is_rolling:
		roll_timer -= delta
		if roll_timer <= 0.0:
			is_rolling = false
			emit_signal("roll_finished")
		else:
			var roll_speed_cur: float = ROLL_SPEED * clampf(roll_timer / ROLL_DURATION + 0.25, 0.4, 1.1)
			return {
				"state": LocomotionState.ROLLING,
				"root_velocity": roll_direction * roll_speed_cur,
				"is_skid": false,
				"is_rolling": true,
				"is_hard_landing": false,
				"blend": blend_pos,
				"anim_name": "preset_biped_roll_001"
			}

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
			"is_rolling": false,
			"is_hard_landing": false,
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
				"is_rolling": false,
				"is_hard_landing": false,
				"blend": blend_pos,
				"anim_name": "preset_biped_idle_001"
			}

	# Detect Skid Trigger: moving fast (> 4.2 m/s) and player suddenly releases input
	if current_state == LocomotionState.SPRINT and speed > 4.2 and input_vec.length() < 0.1 and not is_skidding:
		is_skidding = true
		skid_timer = SKID_DURATION
		current_state = LocomotionState.SKID_STOP
		emit_signal("skid_triggered", speed / 5.8)
		return {
			"state": LocomotionState.SKID_STOP,
			"root_velocity": Vector3.ZERO,
			"is_skid": true,
			"is_rolling": false,
			"is_hard_landing": false,
			"blend": blend_pos,
			"anim_name": "preset_biped_idle_001"
		}

	# Locomotion Blend Space Target calculation
	target_blend = input_vec.normalized()
	blend_pos = blend_pos.lerp(target_blend, minf(1.0, blend_smoothing * delta))

	# Determine Locomotion State & Animation
	var anim_name: String = "preset_biped_idle_001"
	if input_vec.length() > 0.1 and speed > 0.35:
		if sprint_requested and speed > 3.8:
			current_state = LocomotionState.SPRINT
			anim_name = "preset_biped_run_001"
		else:
			current_state = LocomotionState.WALK
			anim_name = "preset_biped_walk_001"
	else:
		if is_combat_stance:
			current_state = LocomotionState.FIGHT_IDLE
			anim_name = "preset_biped_fight_idle_001"
		else:
			current_state = LocomotionState.IDLE
			anim_name = "preset_biped_idle_001"

	return {
		"state": current_state,
		"root_velocity": Vector3.ZERO,
		"is_skid": false,
		"is_rolling": false,
		"is_hard_landing": false,
		"blend": blend_pos,
		"anim_name": anim_name
	}
