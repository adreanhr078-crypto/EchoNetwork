extends SkeletonModifier3D

## Add gaze after authored animation; never replace the animated head rotation.
var player: EchoPlayer
var head_index := -1
var _gaze := Quaternion.IDENTITY

func configure(subject: EchoPlayer) -> void:
	player = subject
	var skeleton := subject.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton:
		head_index = skeleton.find_bone(preload("res://scripts/player/echo_rig_profile.gd").bone(skeleton,"head"))

func _process_modification() -> void: _process_modification_with_delta(1.0 / 60.0)

func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if not is_instance_valid(player) or not skeleton or head_index < 0: return
	var pose := skeleton.get_bone_global_pose(head_index)
	var desired := Quaternion.IDENTITY
	var target := player.get_nearest_interactable() if not player.control_locked and not player.opening_recovery_active and not player.reduced_camera_motion else null
	if is_instance_valid(target) and target is Node3D and target.is_inside_tree():
		var offset: Vector3 = player.get_interaction_focus(target) - skeleton.to_global(pose.origin)
		if offset.length() > 0.4 and offset.length() < 3.8:
			# Facing comes from the measured rig profile.
			var forward := player.visual_root.global_basis * player.model_local_forward
			forward.y = 0.0
			var horizontal := Vector3(offset.x, 0, offset.z)
			if horizontal.length_squared() > 0.0001:
				var yaw := clampf(forward.normalized().signed_angle_to(horizontal.normalized(), Vector3.UP), -0.55, 0.55)
				var pitch := clampf(atan2(offset.y, horizontal.length()), -0.32, 0.32)
				var right := forward.normalized().cross(Vector3.UP)
				var world_delta := Quaternion(Vector3.UP, yaw) * Quaternion(right, pitch)
				var frame := skeleton.global_basis.orthonormalized().get_rotation_quaternion()
				desired = frame.inverse() * world_delta * frame
	_gaze = _gaze.slerp(desired, 1.0 - exp(-8.0 * maxf(delta, 0.0)))
	pose.basis = Basis(_gaze) * pose.basis
	skeleton.set_bone_global_pose(head_index, pose)
