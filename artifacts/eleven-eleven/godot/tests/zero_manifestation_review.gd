extends SceneTree

## Real avatar geometry/bones, explicit authority, animation socket movement,
## instance ownership, pause, cancellation and reduced-motion regression.
const EyeScene = preload("res://scenes/player/zero_eye_singularity.tscn")
const LegacyScene = preload("res://assets/characters/echo_opening_uniform_v13.glb")
const WingScene = preload("res://scenes/player/zero_shadow_wing.tscn")
var failures: Array[String] = []
var checks := 0

class Authority extends Node3D:
	var contract_with_zero_sealed := false
	var reduced_motion := false

func _init() -> void:
	run.call_deferred()

func require(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func run() -> void:
	var player := Authority.new()
	root.add_child(player)
	var model := Node3D.new()
	model.name = "ModelRoot"
	player.add_child(model)
	var avatar := LegacyScene.instantiate() as Node3D
	avatar.name = "EchoOpeningUniform"
	avatar.scale = Vector3.ONE * 1.72
	model.add_child(avatar)
	var eye := EyeScene.instantiate() as Node3D
	model.add_child(eye)
	var wing := WingScene.instantiate() as Node3D
	model.add_child(wing)
	await process_frame
	require(eye.mount_valid, "Actual v13 Head socket must resolve")
	require(eye.global_position.y > 1.4 and eye.global_position.y < 1.7, "Actual UV iris remains on the face despite imported armature origin")
	require(not eye.attachment.skin_bones.is_empty(), "Eye follows actual source face skin influences")
	require(not eye.visible and not eye.is_singularity_active, "Dormant eye remains invisible")
	require(wing.mount_valid and wing.feather_skeleton.get_bone_count() == 16, "Generated detailed feather rig and left shoulder resolve")
	wing.manifest_wing(1.0)
	require(not wing.visible, "Wing cannot grant a contract")
	eye.activate_singularity(1.0)
	require(not eye.visible, "Activation cannot grant a contract")
	player.contract_with_zero_sealed = true
	eye.activate_singularity(0.65)
	wing.manifest_wing(0.65)
	require(eye.visible and eye.is_singularity_active, "Accepted contract shows real iris")
	require(wing.visible and wing.is_wing_manifested, "Accepted contract shows actual single detailed wing")
	require(wing.supports_cinematic_framing(), "Bounded generated wing can remain in pact framing")
	require(eye.iris.mesh.get_surface_count() == 1, "Iris has real mesh surface")
	require(not eye.attachment.eyelid_meshes.is_empty(), "Actual avatar eyelid morphs are bound")
	var lid_mesh: MeshInstance3D = eye.attachment.eyelid_meshes[0]
	var lid_index: int = lid_mesh.find_blend_shape_by_name("Blink_L")
	lid_mesh.set_blend_shape_value(lid_index, 1.0)
	eye._process(0.01)
	require(not eye.iris.visible and eye.eye_light.light_energy == 0.0, "Closed actual eyelid hides and dims the contract iris")
	lid_mesh.set_blend_shape_value(lid_index, 0.0)
	eye._process(0.01)
	require(eye.iris.visible, "Opening actual eyelid restores iris")
	require(eye.eye_light.omni_range <= 0.140001, "Eye light remains physically bounded")
	var skeleton: Skeleton3D = eye.attachment.skeleton
	var head: int = eye.attachment.bone_index
	print("HEAD_CAPTURE_DIAGNOSTICS ", JSON.stringify({"show_rest_only":skeleton.show_rest_only,"initial_head_pose":var_to_str(skeleton.get_bone_pose(head)),"head_rest":var_to_str(skeleton.get_bone_rest(head))}))
	var source_animator := avatar.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if source_animator: print("AVATAR_ANIMATOR ", source_animator.is_playing(), " autoplay=", source_animator.autoplay)
	var before: Vector3 = eye.global_position
	skeleton.set_bone_pose_rotation(head, Quaternion(Vector3.UP, 0.25))
	skeleton.force_update_all_bone_transforms()
	eye.attachment.update_socket()
	require(eye.global_position.distance_to(before) > 0.001, "Eye follows a moving actual Head bone")
	skeleton.reset_bone_pose(head)
	skeleton.force_update_all_bone_transforms()
	eye.attachment.update_socket()
	require(eye.global_position.distance_to(before) < 0.00001, "Head socket returns exactly to rest")
	eye._process(0.05)
	var time_before: float = eye.local_time
	player.reduced_motion = true
	eye._process(0.08)
	wing._process(0.08)
	require(eye.local_time == time_before, "Reduced motion freezes iris animation")
	for bone in wing.feather_skeleton.get_bone_count():
		require(wing.feather_skeleton.get_bone_pose_rotation(bone).is_equal_approx(wing.rest_rotations[bone]), "Reduced motion restores actual imported feather rest %d" % bone)
	require(not wing.shadow_particles.emitting, "Reduced motion suppresses motes")
	player.reduced_motion = false
	paused = true
	var wing_time_before: float = wing.local_time
	await process_frame
	await process_frame
	require(eye.local_time == time_before, "Scene pause freezes local effect time")
	require(wing.local_time == wing_time_before, "Scene pause freezes feather time")
	paused = false
	eye.pulse_singularity(0.8)
	eye.deactivate_singularity()
	eye._process(1.0)
	require(not eye.visible and eye.pulse_remaining == 0, "Cancelled pulse cannot revive eye")
	eye.activate_singularity(INF)
	require(not eye.visible, "Non-finite intensity fails closed")
	eye.activate_singularity(999.0)
	require(eye.current_intensity <= 1.8 and eye.eye_light.light_energy <= 0.55, "Legacy long Void Sight argument cannot blow out iris")
	wing.manifest_wing(999.0)
	wing._process(0.1)
	require(wing.current_intensity <= 1.8 and wing.wing_mesh.scale.x <= 1.000001, "High intensity cannot enlarge the wing into the camera")
	var feather: int = wing.feather_skeleton.find_bone("Feather_2_2")
	var first_pose: Quaternion = wing.feather_skeleton.get_bone_pose_rotation(feather)
	for frame in 10: wing._process(1.0 / 30.0)
	require(not wing.feather_skeleton.get_bone_pose_rotation(feather).is_equal_approx(first_pose), "Actual generated fin skeleton moves independently")
	wing.set_quality_tier(0)
	wing._process(0.03)
	require(not wing.shadow_particles.emitting, "Low tier bounds secondary effects")
	for trail in wing.tip_trails:
		require(trail.get("emitting") == false, "Low tier suppresses native trails")
	wing.dismiss_wing()
	wing.manifest_wing(0.7)
	wing._process(0.04)
	require(wing.visible, "Rapid dismiss/reopen has no stale tween hiding new wing")
	player.contract_with_zero_sealed = false
	eye._process(0.03)
	wing._process(0.03)
	require(not eye.visible, "Revoked contract immediately suppresses eye")
	require(not wing.visible and not wing.is_wing_manifested, "Revoked contract immediately suppresses wing")
	player.queue_free()
	await process_frame
	print("ZERO_MANIFESTATION_REVIEW ", JSON.stringify({"checks":checks,"failures":failures,"status":"PASS" if failures.is_empty() else "FAIL"}))
	quit(0 if failures.is_empty() else 1)
