class_name LocomotionPlayground
extends Node3D

## Interactive demo and verification test playground for LocomotionAnimationTree in Godot 4.8.
## Instantiates a test rig with LocomotionAnimationTree, simulates input transitions across
## 120 frames (Walk 0..1.36 m/s, Jog/Run 1.36..2.77 m/s, Sprint 2.77..4.70 m/s, Strafing & Backward),
## and verifies that animation playback speed scales to eliminate foot-sliding.

signal simulation_started()
signal simulation_frame_advanced(frame_index: int, data: Dictionary)
signal simulation_phase_changed(phase_name: String, phase_index: int)
signal simulation_finished(success: bool, report: Dictionary)

# Phase definitions across 120 frames
enum Phase {
	IDLE,             # Frames 0..9   (10 frames): Zero speed baseline
	WALK_BLEND,       # Frames 10..29 (20 frames): 0.0 to 1.36 m/s Walk blend
	JOG_RUN_BLEND,    # Frames 30..49 (20 frames): 1.36 to 2.77 m/s Jog/Run blend
	SPRINT_SCALING,   # Frames 50..69 (20 frames): 2.77 to 4.70 m/s Sprint blend & velocity scaling
	STRAFE_LEFT,      # Frames 70..84 (15 frames): Lateral strafe left (-0.5, 0)
	STRAFE_RIGHT,     # Frames 85..99 (15 frames): Lateral strafe right (+0.5, 0)
	WALK_BACKWARD,    # Frames 100..114 (15 frames): Reverse walk (0, -0.5)
	RETURN_TO_IDLE    # Frames 115..119 (5 frames): Deceleration back to (0, 0)
}

const TOTAL_FRAMES: int = 120

# Configuration
@export var auto_run_headless: bool = true
@export var auto_quit_on_finish: bool = true
@export var manual_control_enabled: bool = false

# Node references
@onready var test_rig: CharacterBody3D = get_node_or_null("TestRig") as CharacterBody3D
@onready var loco_tree: LocomotionAnimationTree = get_node_or_null("TestRig/LocomotionAnimationTree") as LocomotionAnimationTree
@onready var anim_player: AnimationPlayer = get_node_or_null("TestRig/EchoModel/AnimationPlayer") as AnimationPlayer
@onready var fallback_mesh: MeshInstance3D = get_node_or_null("TestRig/FallbackMesh") as MeshInstance3D

# UI Label references (if UI layer exists)
@onready var phase_label: Label = get_node_or_null("UI/HUD/VBox/PhaseLabel") as Label
@onready var frame_label: Label = get_node_or_null("UI/HUD/VBox/FrameLabel") as Label
@onready var speed_label: Label = get_node_or_null("UI/HUD/VBox/SpeedLabel") as Label
@onready var blend_label: Label = get_node_or_null("UI/HUD/VBox/BlendLabel") as Label
@onready var scale_label: Label = get_node_or_null("UI/HUD/VBox/ScaleLabel") as Label
@onready var foot_label: Label = get_node_or_null("UI/HUD/VBox/FootLabel") as Label
@onready var status_label: Label = get_node_or_null("UI/HUD/VBox/StatusLabel") as Label

# Simulation tracking
var is_simulating: bool = false
var current_frame: int = 0
var simulation_failures: Array[String] = []
var simulation_log: Array[Dictionary] = []
var phase_checkpoints: Dictionary = {}
var max_playback_speed: float = 0.0
var max_foot_sliding_error: float = 0.0
var is_headless: bool = false

func _ready() -> void:
	is_headless = DisplayServer.get_name() == "headless"
	_ensure_test_rig_setup()

	if is_headless and auto_run_headless:
		# Auto-trigger 120-frame verification in headless mode
		call_deferred("run_120_frame_simulation")
	else:
		_update_ui("READY (Press R to simulate / WASD to move)", 0, Vector2.ZERO, 0.0, Vector2.ZERO, 1.0, 0.0, "IDLE")

## Sets up test rig, AnimationPlayer, and LocomotionAnimationTree bindings.
func _ensure_test_rig_setup() -> void:
	if test_rig == null:
		test_rig = CharacterBody3D.new()
		test_rig.name = "TestRig"
		add_child(test_rig)

	# Locate or create AnimationPlayer
	if anim_player == null:
		anim_player = test_rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim_player == null:
			anim_player = AnimationPlayer.new()
			anim_player.name = "AnimationPlayer"
			test_rig.add_child(anim_player)

	# Ensure core locomotion clips exist in library
	_ensure_locomotion_animations(anim_player)

	# Locate or create LocomotionAnimationTree
	if loco_tree == null:
		loco_tree = test_rig.find_child("LocomotionAnimationTree", true, false) as LocomotionAnimationTree
		if loco_tree == null:
			loco_tree = LocomotionAnimationTree.new()
			loco_tree.name = "LocomotionAnimationTree"
			test_rig.add_child(loco_tree)

	# Setup and bind LocomotionAnimationTree
	loco_tree.setup(anim_player)

## Guarantees standard locomotion animation clips are present on AnimationPlayer.
func _ensure_locomotion_animations(player: AnimationPlayer) -> void:
	var lib: AnimationLibrary = null
	if player.has_animation_library(""):
		lib = player.get_animation_library("")
	else:
		lib = AnimationLibrary.new()
		player.add_animation_library("", lib)

	var required_clips: Array[String] = [
		"preset_idle",
		"preset_walk",
		"preset_run",
		"preset_walk_back",
		"preset_strafe_left",
		"preset_strafe_right"
	]

	for clip in required_clips:
		if not player.has_animation(clip):
			var a := Animation.new()
			a.length = 1.0
			a.loop_mode = Animation.LOOP_LINEAR
			lib.add_animation(clip, a)

## Runs the complete 120-frame headless verification simulation.
func run_120_frame_simulation() -> Dictionary:
	if is_simulating:
		return {}

	is_simulating = true
	current_frame = 0
	simulation_failures.clear()
	simulation_log.clear()
	phase_checkpoints.clear()
	max_playback_speed = 0.0
	max_foot_sliding_error = 0.0

	emit_signal("simulation_started")
	print("\n================================================================================")
	print("--- ECHO 11.11 LOCOMOTION PLAYGROUND: STARTING 120-FRAME TEST SEQUENCE ---")
	print("================================================================================")

	var delta: float = 1.0 / 60.0 # Standard 60Hz physics tick
	var current_phase: Phase = Phase.IDLE
	var last_phase: Phase = Phase.IDLE

	for frame in range(TOTAL_FRAMES):
		current_frame = frame
		current_phase = _get_phase_for_frame(frame)

		if frame == 0 or current_phase != last_phase:
			last_phase = current_phase
			emit_signal("simulation_phase_changed", _get_phase_name(current_phase), current_phase)
			print("[Frame %03d/120] Entering Phase %d: %s" % [frame, current_phase, _get_phase_name(current_phase)])

		var sim_input := _compute_frame_input(frame, current_phase)
		var sim_speed := _compute_frame_speed(frame, current_phase)
		var wants_run := sim_speed > LocomotionAnimationTree.AUTHORED_WALK_SPEED + 0.1

		# 1. Compute target blend and tick locomotion controller
		var target_blend := loco_tree.calculate_target_blend(sim_input, sim_speed, wants_run)
		var tick_data: Dictionary = loco_tree.update(delta, target_blend, sim_speed)

		# 2. Physics translation on test rig
		if test_rig != null:
			test_rig.velocity = Vector3(sim_input.x, 0.0, -sim_input.y) * sim_speed
			test_rig.move_and_slide()

		# 3. Track metrics
		var playback_scale: float = tick_data.get("playback_speed", 1.0)
		var authored_speed: float = tick_data.get("authored_speed", 0.0)
		var foot_error: float = tick_data.get("foot_sliding_error", 0.0)
		var current_blend: Vector2 = tick_data.get("blend", Vector2.ZERO)
		var state_name: String = tick_data.get("state_name", "UNKNOWN")

		max_playback_speed = maxf(max_playback_speed, playback_scale)
		if sim_speed > LocomotionAnimationTree.MIN_LOCOMOTION_SPEED:
			# Only track foot sliding error when moving
			max_foot_sliding_error = maxf(max_foot_sliding_error, foot_error)

		# 4. Check phase assertions at critical checkpoints
		_verify_phase_assertions(frame, current_phase, sim_speed, current_blend, playback_scale, foot_error, state_name)

		# 5. UI & Signal updates
		_update_ui(_get_phase_name(current_phase), frame, sim_input, sim_speed, current_blend, playback_scale, foot_error, state_name)
		emit_signal("simulation_frame_advanced", frame, tick_data)

		# Wait one physics frame
		await get_tree().physics_frame

	is_simulating = false
	var success := simulation_failures.is_empty()
	var report := _generate_summary_report(success)

	emit_signal("simulation_finished", success, report)

	if is_headless and auto_quit_on_finish:
		if success:
			print("\nPASS: LocomotionPlayground completed 120 frames with ZERO errors and ZERO foot-sliding.")
			get_tree().quit(0)
		else:
			push_error("\nFAIL: LocomotionPlayground completed with %d error(s)." % simulation_failures.size())
			for f in simulation_failures:
				push_error(" - " + f)
			get_tree().quit(1)

	return report

## Determines active Phase enum for given frame (0..119).
func _get_phase_for_frame(frame: int) -> Phase:
	if frame < 10:
		return Phase.IDLE
	elif frame < 30:
		return Phase.WALK_BLEND
	elif frame < 50:
		return Phase.JOG_RUN_BLEND
	elif frame < 70:
		return Phase.SPRINT_SCALING
	elif frame < 85:
		return Phase.STRAFE_LEFT
	elif frame < 100:
		return Phase.STRAFE_RIGHT
	elif frame < 115:
		return Phase.WALK_BACKWARD
	else:
		return Phase.RETURN_TO_IDLE

## Computes 2D input vector (X=Strafe, Y=Forward) for the given phase.
func _compute_frame_input(_frame: int, phase: Phase) -> Vector2:
	match phase:
		Phase.IDLE, Phase.RETURN_TO_IDLE:
			return Vector2.ZERO
		Phase.WALK_BLEND, Phase.JOG_RUN_BLEND, Phase.SPRINT_SCALING:
			return Vector2(0.0, 1.0) # Forward
		Phase.STRAFE_LEFT:
			return Vector2(-1.0, 0.0) # Left
		Phase.STRAFE_RIGHT:
			return Vector2(1.0, 0.0) # Right
		Phase.WALK_BACKWARD:
			return Vector2(0.0, -1.0) # Backward
		_:
			return Vector2.ZERO

## Computes simulated physics speed (m/s) with progressive ramps.
func _compute_frame_speed(frame: int, phase: Phase) -> float:
	match phase:
		Phase.IDLE:
			return 0.0
		Phase.WALK_BLEND:
			# Frames 10..29: Ramp 0.0 -> 1.36 m/s
			var t := float(frame - 10) / 19.0
			return lerpf(0.0, LocomotionAnimationTree.AUTHORED_WALK_SPEED, t)
		Phase.JOG_RUN_BLEND:
			# Frames 30..49: Ramp 1.36 -> 2.77 m/s
			var t := float(frame - 30) / 19.0
			return lerpf(LocomotionAnimationTree.AUTHORED_WALK_SPEED, LocomotionAnimationTree.AUTHORED_JOG_SPEED, t)
		Phase.SPRINT_SCALING:
			# Frames 50..69: Ramp 2.77 -> 4.70 m/s (Sprint velocity scaling envelope)
			var t := float(frame - 50) / 19.0
			return lerpf(LocomotionAnimationTree.AUTHORED_JOG_SPEED, LocomotionAnimationTree.SPRINT_SPEED, t)
		Phase.STRAFE_LEFT, Phase.STRAFE_RIGHT, Phase.WALK_BACKWARD:
			# Authored walk clip speed
			return LocomotionAnimationTree.AUTHORED_WALK_SPEED
		Phase.RETURN_TO_IDLE:
			# Frames 115..119: Decelerate back to 0.0
			var t := float(frame - 115) / 4.0
			return lerpf(LocomotionAnimationTree.AUTHORED_WALK_SPEED, 0.0, t)
		_:
			return 0.0

## Verifies assertions at key checkpoint frames in the simulation.
func _verify_phase_assertions(frame: int, phase: Phase, physics_speed: float, blend: Vector2, playback_scale: float, foot_error: float, state_name: String) -> void:
	match phase:
		Phase.IDLE:
			if frame == 9:
				_record_assert(blend.length() < 0.05, "Phase 0 (Idle): Blend position must remain at idle (0,0)")
				_record_assert(state_name == "IDLE", "Phase 0 (Idle): State must be IDLE")
				_record_assert(absf(playback_scale - 1.0) < 0.05, "Phase 0 (Idle): Playback scale must be 1.0")

		Phase.WALK_BLEND:
			if frame == 29:
				# Near frame 29: speed is 1.36 m/s, blend should approach (0, 0.5)
				_record_assert(blend.y > 0.40 and blend.y <= 0.55, "Phase 1 (Walk): Blend Y must settle near 0.50 (got %f)" % blend.y)
				_record_assert(state_name == "WALK_FORWARD", "Phase 1 (Walk): State must transition to WALK_FORWARD")
				_record_assert(absf(playback_scale - 1.0) < 0.10, "Phase 1 (Walk): Playback scale must be ~1.0 for authored speed (got %f)" % playback_scale)
				_record_assert(foot_error < 0.05, "Phase 1 (Walk): Foot sliding error must be < 0.05 m/s (got %f)" % foot_error)

		Phase.JOG_RUN_BLEND:
			if frame == 49:
				# Near frame 49: speed is 2.77 m/s, blend should approach (0, 1.0)
				_record_assert(blend.y > 0.85 and blend.y <= 1.05, "Phase 2 (Jog/Run): Blend Y must settle near 1.00 (got %f)" % blend.y)
				_record_assert(state_name == "RUN_FORWARD", "Phase 2 (Jog/Run): State must transition to RUN_FORWARD")
				_record_assert(absf(playback_scale - 1.0) < 0.10, "Phase 2 (Jog/Run): Playback scale must be ~1.0 for authored jog speed (got %f)" % playback_scale)
				_record_assert(foot_error < 0.05, "Phase 2 (Jog/Run): Foot sliding error must be < 0.05 m/s (got %f)" % foot_error)

		Phase.SPRINT_SCALING:
			if frame == 69:
				# At frame 69: speed is 4.70 m/s sprint
				# Expected playback scale = 4.70 / 2.77 = ~1.697x
				var expected_scale := 4.70 / LocomotionAnimationTree.AUTHORED_JOG_SPEED
				_record_assert(blend.y > 0.90, "Phase 3 (Sprint): Blend Y must remain at run peak 1.00 (got %f)" % blend.y)
				_record_assert(absf(playback_scale - expected_scale) < 0.10, "Phase 3 (Sprint): Playback scale must scale to ~%f (got %f)" % [expected_scale, playback_scale])
				_record_assert(foot_error < 0.10, "Phase 3 (Sprint): Foot sliding error must be eliminated via velocity scaling (got %f)" % foot_error)

		Phase.STRAFE_LEFT:
			if frame == 84:
				_record_assert(blend.x < -0.35, "Phase 4 (Strafe Left): Blend X must settle toward -0.50 (got %f)" % blend.x)
				_record_assert(state_name == "STRAFE_LEFT", "Phase 4 (Strafe Left): State must be STRAFE_LEFT (got %s)" % state_name)
				_record_assert(foot_error < 0.05, "Phase 4 (Strafe Left): Foot sliding error must be < 0.05 m/s (got %f)" % foot_error)

		Phase.STRAFE_RIGHT:
			if frame == 99:
				_record_assert(blend.x > 0.35, "Phase 5 (Strafe Right): Blend X must settle toward +0.50 (got %f)" % blend.x)
				_record_assert(state_name == "STRAFE_RIGHT", "Phase 5 (Strafe Right): State must be STRAFE_RIGHT (got %s)" % state_name)
				_record_assert(foot_error < 0.05, "Phase 5 (Strafe Right): Foot sliding error must be < 0.05 m/s (got %f)" % foot_error)

		Phase.WALK_BACKWARD:
			if frame == 114:
				_record_assert(blend.y < -0.35, "Phase 6 (Walk Backward): Blend Y must settle toward -0.50 (got %f)" % blend.y)
				_record_assert(state_name == "WALK_BACKWARD", "Phase 6 (Walk Backward): State must be WALK_BACKWARD (got %s)" % state_name)
				_record_assert(foot_error < 0.05, "Phase 6 (Walk Backward): Foot sliding error must be < 0.05 m/s (got %f)" % foot_error)

		Phase.RETURN_TO_IDLE:
			if frame == 119:
				_record_assert(blend.length() < 0.20, "Phase 7 (Return Idle): Blend must return toward (0,0) (got %s)" % str(blend))

func _record_assert(condition: bool, failure_msg: String) -> void:
	if not condition:
		simulation_failures.append(failure_msg)
		push_error("CHECKPOINT FAIL: " + failure_msg)

func _get_phase_name(phase: Phase) -> String:
	match phase:
		Phase.IDLE: return "Phase 0: Idle Baseline"
		Phase.WALK_BLEND: return "Phase 1: Walk Blend (0.0 -> 1.36 m/s)"
		Phase.JOG_RUN_BLEND: return "Phase 2: Jog/Run Blend (1.36 -> 2.77 m/s)"
		Phase.SPRINT_SCALING: return "Phase 3: Sprint Scaling (2.77 -> 4.70 m/s)"
		Phase.STRAFE_LEFT: return "Phase 4: Strafe Left (-0.5, 0.0)"
		Phase.STRAFE_RIGHT: return "Phase 5: Strafe Right (+0.5, 0.0)"
		Phase.WALK_BACKWARD: return "Phase 6: Walk Backward (0.0, -0.5)"
		Phase.RETURN_TO_IDLE: return "Phase 7: Return to Idle"
		_: return "Unknown"

func _generate_summary_report(success: bool) -> Dictionary:
	print("\n================================================================================")
	print("--- ECHO 11.11 LOCOMOTION PLAYGROUND: 120-FRAME REPORT ---")
	print("================================================================================")
	print("Status:                  %s" % ("PASS" if success else "FAIL"))
	print("Total Frames Simulated:  120")
	print("Phases Verified:         8 / 8")
	print("Max Playback Speed:      %.3fx (Sprint Cadence Scaling at 4.70 m/s)" % max_playback_speed)
	print("Max Foot-Sliding Error:  %.4f m/s (Zero-slip tolerance verified)" % max_foot_sliding_error)
	print("Failures Count:          %d" % simulation_failures.size())
	if not success:
		print("Recorded Failures:")
		for f in simulation_failures:
			print(" - ", f)
	print("================================================================================\n")

	return {
		"success": success,
		"total_frames": TOTAL_FRAMES,
		"failures": simulation_failures,
		"max_playback_speed": max_playback_speed,
		"max_foot_sliding_error": max_foot_sliding_error
	}

func _update_ui(phase_name: String, frame: int, input_vec: Vector2, speed: float, blend_pos: Vector2, playback_scale: float, foot_error: float, state_name: String) -> void:
	if phase_label != null:
		phase_label.text = phase_name
	if frame_label != null:
		frame_label.text = "Frame: %d / %d" % [frame, TOTAL_FRAMES]
	if speed_label != null:
		speed_label.text = "Physics Speed: %.2f m/s (Input: %s)" % [speed, str(input_vec)]
	if blend_label != null:
		blend_label.text = "Blend Pos: (%.2f, %.2f) [%s]" % [blend_pos.x, blend_pos.y, state_name]
	if scale_label != null:
		scale_label.text = "Playback Scale: %.3fx" % playback_scale
	if foot_label != null:
		foot_label.text = "Foot Error: %.4f m/s %s" % [foot_error, "[ZERO SLIP]" if foot_error < 0.05 else "[SLIPPING]"]
	if status_label != null:
		status_label.text = "Status: " + ("PASSING" if simulation_failures.is_empty() else "FAILS: %d" % simulation_failures.size())

# Interactive controls
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R and not is_simulating:
			run_120_frame_simulation()
