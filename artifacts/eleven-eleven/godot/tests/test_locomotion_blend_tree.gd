extends SceneTree

## Headless test suite for LocomotionAnimationTree foundation.
## Verifies BlendSpace2D geometry, blend points, velocity matching, damping, and parameter binding.

const LocomotionAnimationTree = preload("res://scripts/player/locomotion_animation_tree.gd")

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func _assert_approx(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		var detail := "%s (expected approx %f, got %f, diff=%f)" % [message, expected, actual, absf(actual - expected)]
		failures.append(detail)
		push_error("FAIL: " + detail)

func _assert_vector_approx(actual: Vector2, expected: Vector2, tolerance: float, message: String) -> void:
	if actual.distance_to(expected) > tolerance:
		var detail := "%s (expected approx %s, got %s, dist=%f)" % [message, str(expected), str(actual), actual.distance_to(expected)]
		failures.append(detail)
		push_error("FAIL: " + detail)

func _run() -> void:
	print("--- STARTING LOCOMOTION BLEND TREE HEADLESS TEST SUITE ---")

	var root_node := Node.new()
	root.add_child(root_node)

	var loco = LocomotionAnimationTree.new()
	root_node.add_child(loco)

	_test_initialization(loco)
	_test_blend_points_and_geometry(loco)
	_test_velocity_matching_formula(loco)
	_test_target_blend_calculation(loco)
	_test_smooth_damping(loco)
	_test_locomotion_states_and_signals(loco)
	_test_parameter_binding(loco)
	_test_active_scene_integration(root_node, loco)

	root_node.queue_free()
	await process_frame

	print("\n--- TEST SUMMARY ---")
	if failures.is_empty():
		print("PASS: LocomotionAnimationTree passed all modular foundation tests.")
		print("All 6 blend points connected, velocity matching verified, damping smooth, AnimationTree parameters bound.")
		quit(0)
	else:
		print("FAILED with %d error(s):" % failures.size())
		for f in failures:
			print(" - ", f)
		quit(1)

func _test_initialization(loco: Node) -> void:
	print("[1/7] Testing initialization and tree graph structure...")
	_assert(loco.is_initialized, "LocomotionAnimationTree must be initialized after entering tree")
	_assert(loco.get_animation_tree() != null, "AnimationTree must be created")
	_assert(loco.get_blend_space_2d() != null, "BlendSpace2D must be created")
	_assert(loco.get_time_scale_node() != null, "TimeScale node must be created")
	_assert(loco.get_blend_tree_root() != null, "BlendTree root must be created")

func _test_blend_points_and_geometry(loco: Node) -> void:
	print("[2/7] Testing BlendSpace2D geometry and blend points...")
	var bs: AnimationNodeBlendSpace2D = loco.get_blend_space_2d()

	_assert(bs.min_space == Vector2(-1.0, -1.0), "min_space must be (-1, -1)")
	_assert(bs.max_space == Vector2(1.0, 1.0), "max_space must be (1, 1)")
	_assert(bs.get_blend_point_count() == 6, "BlendSpace2D must have exactly 6 blend points, got %d" % bs.get_blend_point_count())

	# Verify required blend points:
	# Idle at (0,0), Walk Forward at (0, 0.5), Run Forward at (0, 1.0),
	# Walk Backward at (0, -0.5), Strafe Left at (-0.5, 0), Strafe Right at (0.5, 0)
	var expected_points := {
		"idle": Vector2(0.0, 0.0),
		"walk_forward": Vector2(0.0, 0.5),
		"run_forward": Vector2(0.0, 1.0),
		"walk_backward": Vector2(0.0, -0.5),
		"strafe_left": Vector2(-0.5, 0.0),
		"strafe_right": Vector2(0.5, 0.0)
	}

	for i in range(bs.get_blend_point_count()):
		var pos := bs.get_blend_point_position(i)
		var matched := false
		for k in expected_points.keys():
			if pos.distance_to(expected_points[k]) < 0.001:
				matched = true
				break
		_assert(matched, "Blend point %d at position %s must match one of the required points" % [i, str(pos)])

	_assert(bs.auto_triangles, "BlendSpace2D must have auto_triangles enabled")

func _test_velocity_matching_formula(loco: Node) -> void:
	print("[3/7] Testing velocity matching formula and foot sliding prevention...")
	# Authored reference velocities
	_assert_approx(LocomotionAnimationTree.AUTHORED_WALK_SPEED, 1.36, 0.001, "Authored walk speed must be 1.36 m/s")
	_assert_approx(LocomotionAnimationTree.AUTHORED_JOG_SPEED, 2.77, 0.001, "Authored jog speed must be 2.77 m/s")

	# Authored speed evaluation per blend point
	_assert_approx(loco.calculate_authored_speed(Vector2(0.0, 0.0)), 0.0, 0.001, "Idle authored speed must be 0.0")
	_assert_approx(loco.calculate_authored_speed(Vector2(0.0, 0.5)), 1.36, 0.001, "Walk forward authored speed must be 1.36 m/s")
	_assert_approx(loco.calculate_authored_speed(Vector2(0.5, 0.0)), 1.36, 0.001, "Strafe right authored speed must be 1.36 m/s")
	_assert_approx(loco.calculate_authored_speed(Vector2(-0.5, 0.0)), 1.36, 0.001, "Strafe left authored speed must be 1.36 m/s")
	_assert_approx(loco.calculate_authored_speed(Vector2(0.0, -0.5)), 1.36, 0.001, "Walk backward authored speed must be 1.36 m/s")
	_assert_approx(loco.calculate_authored_speed(Vector2(0.0, 1.0)), 2.77, 0.001, "Run forward authored speed must be 2.77 m/s")

	# Interpolation between walk and run (magnitude 0.75)
	var expected_mid_speed: float = lerpf(1.36, 2.77, 0.5)
	_assert_approx(loco.calculate_authored_speed(Vector2(0.0, 0.75)), expected_mid_speed, 0.01, "Mid walk-run speed must match lerp")

	# Playback speed scale matching:
	# 1. Idle speed -> scale 1.0
	_assert_approx(loco.calculate_playback_speed(0.0, Vector2(0.0, 0.0)), 1.0, 0.001, "Idle speed must return scale 1.0")

	# 2. Perfect walk speed match (physics 1.36 m/s at walk blend 0.5) -> scale 1.0
	_assert_approx(loco.calculate_playback_speed(1.36, Vector2(0.0, 0.5)), 1.0, 0.001, "Exact walk match must produce 1.0 scale")

	# 3. Perfect jog speed match (physics 2.77 m/s at run blend 1.0) -> scale 1.0
	_assert_approx(loco.calculate_playback_speed(2.77, Vector2(0.0, 1.0)), 1.0, 0.001, "Exact jog match must produce 1.0 scale")

	# 4. Slower walk (0.68 m/s at walk blend 0.5) -> scale 0.5 (half speed)
	_assert_approx(loco.calculate_playback_speed(0.68, Vector2(0.0, 0.5)), 0.5, 0.001, "Half-speed walk must scale playback by 0.5")

	# 5. Faster walk (2.04 m/s at walk blend 0.5) -> scale 1.5
	_assert_approx(loco.calculate_playback_speed(2.04, Vector2(0.0, 0.5)), 1.5, 0.001, "Faster walk must scale playback by 1.5")

	# 6. Clamping floor: very low speed clamped to 0.5
	_assert_approx(loco.calculate_playback_speed(0.1, Vector2(0.0, 0.5)), 0.5, 0.001, "Floor clamp must prevent near-freeze")

	# 7. Clamping ceiling: sprint 4.5 m/s at walk blend clamped to 2.0 (cadence guard)
	_assert_approx(loco.calculate_playback_speed(4.5, Vector2(0.0, 0.5)), 2.0, 0.001, "Ceiling clamp must prevent cartoon fast-forward")

func _test_target_blend_calculation(loco: Node) -> void:
	print("[4/7] Testing target blend calculation from velocity and input...")
	# Zero input / speed
	_assert(loco.calculate_target_blend(Vector2.ZERO, 0.0) == Vector2.ZERO, "Zero input must yield zero blend")

	# Walk Forward input: direction (0, 1), speed 1.36 -> (0, 0.5)
	var walk_fwd_blend: Vector2 = loco.calculate_target_blend(Vector2(0.0, 1.0), 1.36)
	_assert_vector_approx(walk_fwd_blend, Vector2(0.0, 0.5), 0.01, "Walk forward target blend must reach (0, 0.5)")

	# Run Forward input: direction (0, 1), speed 2.77 -> (0, 1.0)
	var run_fwd_blend: Vector2 = loco.calculate_target_blend(Vector2(0.0, 1.0), 2.77, true)
	_assert_vector_approx(run_fwd_blend, Vector2(0.0, 1.0), 0.01, "Run forward target blend must reach (0, 1.0)")

	# Strafe Right input: direction (1, 0), speed 1.36 -> (0.5, 0.0)
	var strafe_r_blend: Vector2 = loco.calculate_target_blend(Vector2(1.0, 0.0), 1.36)
	_assert_vector_approx(strafe_r_blend, Vector2(0.5, 0.0), 0.01, "Strafe right target blend must reach (0.5, 0.0)")

	# 3D Local Velocity conversion:
	# In Godot, -Z is character forward -> should map to +Y in blend space
	var fwd_vel := Vector3(0.0, 0.0, -1.36)
	var vel_blend: Vector2 = loco.calculate_target_blend_from_velocity(fwd_vel)
	_assert_vector_approx(vel_blend, Vector2(0.0, 0.5), 0.01, "Local -Z velocity must map to +Y forward blend")

	# +X is character right -> should map to +X in blend space
	var right_vel := Vector3(1.36, 0.0, 0.0)
	var vel_r_blend: Vector2 = loco.calculate_target_blend_from_velocity(right_vel)
	_assert_vector_approx(vel_r_blend, Vector2(0.5, 0.0), 0.01, "Local +X velocity must map to +X strafe blend")

func _test_smooth_damping(loco: Node) -> void:
	print("[5/7] Testing smooth damping / lerp between states...")
	# Reset to zero
	loco.snap_to_blend(Vector2.ZERO, 1.0)
	_assert(loco.current_blend == Vector2.ZERO, "Snap to zero must be exact")
	_assert_approx(loco.current_playback_speed, 1.0, 0.001, "Snap playback speed must be 1.0")

	# Target Walk Forward: (0, 0.5) with physics speed 1.36
	var target := Vector2(0.0, 0.5)
	var dt := 0.016 # ~60 FPS

	# Tick 1 frame: should move smoothly toward target without overshoot
	var res1: Dictionary = loco.update(dt, target, 1.36)
	_assert(res1["blend"].y > 0.0, "Blend must move toward target on first tick")
	_assert(res1["blend"].y < 0.5, "Blend must not jump instantly to target with damping")

	# Tick 30 frames: should progressively converge
	for i in range(30):
		loco.update(dt, target, 1.36)

	_assert_vector_approx(loco.current_blend, target, 0.02, "Damping must settle near target after 30 frames")
	_assert_approx(loco.current_playback_speed, 1.0, 0.05, "Playback speed must settle near target scale")

func _test_locomotion_states_and_signals(loco: Node) -> void:
	print("[6/7] Testing locomotion state transitions and signals...")
	var recorded_states: Array[String] = []
	loco.locomotion_state_changed.connect(func(_new_state, state_name):
		recorded_states.append(state_name)
	)

	loco.snap_to_blend(Vector2.ZERO, 1.0)
	_assert(loco.current_state == LocomotionAnimationTree.LocomotionState.IDLE, "Zero blend must be IDLE")

	loco.snap_to_blend(Vector2(0.0, 0.5), 1.0)
	_assert(loco.current_state == LocomotionAnimationTree.LocomotionState.WALK_FORWARD, "Blend (0, 0.5) must be WALK_FORWARD")

	loco.snap_to_blend(Vector2(0.0, 1.0), 1.0)
	_assert(loco.current_state == LocomotionAnimationTree.LocomotionState.RUN_FORWARD, "Blend (0, 1.0) must be RUN_FORWARD")

	loco.snap_to_blend(Vector2(0.0, -0.5), 1.0)
	_assert(loco.current_state == LocomotionAnimationTree.LocomotionState.WALK_BACKWARD, "Blend (0, -0.5) must be WALK_BACKWARD")

	loco.snap_to_blend(Vector2(-0.5, 0.0), 1.0)
	_assert(loco.current_state == LocomotionAnimationTree.LocomotionState.STRAFE_LEFT, "Blend (-0.5, 0) must be STRAFE_LEFT")

	loco.snap_to_blend(Vector2(0.5, 0.0), 1.0)
	_assert(loco.current_state == LocomotionAnimationTree.LocomotionState.STRAFE_RIGHT, "Blend (0.5, 0) must be STRAFE_RIGHT")

	_assert(recorded_states.has("WALK_FORWARD"), "State changed signal must record WALK_FORWARD")
	_assert(recorded_states.has("RUN_FORWARD"), "State changed signal must record RUN_FORWARD")
	_assert(recorded_states.has("STRAFE_LEFT"), "State changed signal must record STRAFE_LEFT")
	_assert(recorded_states.has("STRAFE_RIGHT"), "State changed signal must record STRAFE_RIGHT")

func _test_parameter_binding(loco: Node) -> void:
	print("[7/7] Testing AnimationTree parameter reflection...")
	loco.snap_to_blend(Vector2(0.3, 0.7), 1.42)

	var tree: AnimationTree = loco.get_animation_tree()
	var bound_blend = tree.get(LocomotionAnimationTree.PARAM_BLEND_POSITION)
	var bound_scale = tree.get(LocomotionAnimationTree.PARAM_TIME_SCALE)

	_assert(bound_blend != null, "AnimationTree blend position parameter must exist")
	_assert_vector_approx(bound_blend, Vector2(0.3, 0.7), 0.001, "AnimationTree blend position must match snapped blend")
	_assert_approx(bound_scale, 1.42, 0.001, "AnimationTree time scale parameter must match snapped scale")

func _test_active_scene_integration(parent_node: Node, loco: Node) -> void:
	# Add mock AnimationPlayer with locomotion animations
	var anim_player := AnimationPlayer.new()
	var anim_lib := AnimationLibrary.new()

	for clip_name in ["preset_idle", "preset_walk", "preset_run"]:
		var a := Animation.new()
		a.length = 1.0
		anim_lib.add_animation(clip_name, a)

	anim_player.add_animation_library("", anim_lib)
	parent_node.add_child(anim_player)

	loco.setup(anim_player)
	var tree: AnimationTree = loco.get_animation_tree()
	_assert(tree.anim_player == anim_player.get_path(), "AnimationTree anim_player path must bind to AnimationPlayer")
