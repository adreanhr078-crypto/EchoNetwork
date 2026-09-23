extends SkeletonModifier3D

## Two-bone leg solve applied after the imported locomotion clip. Contact probes
## are refreshed by ProceduralFootIK during physics ticks, then the planted ankle
## is solved here in skeleton space without moving Echo's collision capsule.

const PROBE_ABOVE: float = 0.28
const PROBE_BELOW: float = 0.52
const TOE_CLEARANCE: float = 0.012
const CONTACT_HEIGHT: float = 0.055
const TOE_LIFT_RELEASE: float = 0.15
const MAX_PLANT_DRIFT: float = 0.62
const MAX_FLOOR_SLOPE_DOT: float = 0.48
const IK_REACH_MARGIN: float = 0.004

class FootChain:
	var thigh: int = -1
	var shin: int = -1
	var foot: int = -1
	var toe: int = -1
	var planted: bool = false
	var target_world: Vector3 = Vector3.ZERO
	var ground_normal: Vector3 = Vector3.UP

var _player: CharacterBody3D
var _skeleton: Skeleton3D
var _collision_mask: int = 1
var _left: FootChain
var _right: FootChain

func configure(player: CharacterBody3D, collision_mask: int) -> void:
	_player = player
	_collision_mask = collision_mask
	_skeleton = player.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton:
		_left = _create_chain("tripo__1_Left_Limb_3")
		_right = _create_chain("tripo__1_Right_Limb_3")

func update_foot_contacts(_delta: float) -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_skeleton):
		_clear_contacts()
		return
	if _player.get("opening_recovery_active") or not _player.is_on_floor() or not _is_locomotion_clip():
		_clear_contacts()
		return

	var horizontal_speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	if horizontal_speed < 0.2:
		_clear_contacts()
		return
	_update_chain_contact(_left)
	_update_chain_contact(_right)

func _process_modification_with_delta(_delta: float) -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_skeleton):
		return
	var has_contact := false
	if _left and _left.planted:
		_apply_leg_target(_left)
		has_contact = true
	if _right and _right.planted:
		_apply_leg_target(_right)
		has_contact = true
	influence = 1.0 if has_contact else 0.0

func _create_chain(toe_name: String) -> FootChain:
	var chain := FootChain.new()
	chain.toe = _skeleton.find_bone(toe_name)
	if chain.toe < 0:
		return chain
	chain.foot = _skeleton.get_bone_parent(chain.toe)
	chain.shin = _skeleton.get_bone_parent(chain.foot)
	chain.thigh = _skeleton.get_bone_parent(chain.shin)
	if chain.thigh < 0 or chain.shin < 0 or chain.foot < 0:
		chain.toe = -1
	return chain

func _update_chain_contact(chain: FootChain) -> void:
	if not chain or chain.toe < 0:
		return
	var toe_pose := _skeleton.get_bone_global_pose(chain.toe)
	var toe_world := _skeleton.global_transform * toe_pose.origin
	var toe_hit := _ground_hit(toe_world)
	if toe_hit.is_empty():
		chain.planted = false
		return
	var toe_point: Vector3 = toe_hit["position"]
	var toe_normal: Vector3 = toe_hit["normal"].normalized()
	if toe_normal.dot(Vector3.UP) < MAX_FLOOR_SLOPE_DOT:
		chain.planted = false
		return
	var toe_height := (toe_world - toe_point).dot(toe_normal)
	if chain.planted:
		var drift := Vector2(toe_world.x - chain.target_world.x, toe_world.z - chain.target_world.z).length()
		if toe_height > TOE_LIFT_RELEASE or drift > MAX_PLANT_DRIFT:
			chain.planted = false
	if not chain.planted and toe_height <= CONTACT_HEIGHT and toe_height >= -0.11:
		chain.planted = true
		chain.target_world = toe_point + toe_normal * TOE_CLEARANCE
		chain.ground_normal = toe_normal
	if not chain.planted:
		return

	var anchor_hit := _ground_hit(chain.target_world)
	if anchor_hit.is_empty():
		chain.planted = false
		return
	var anchor_normal: Vector3 = anchor_hit["normal"].normalized()
	if anchor_normal.dot(Vector3.UP) < MAX_FLOOR_SLOPE_DOT:
		chain.planted = false
		return
	var ground_position: Vector3 = anchor_hit["position"]
	chain.target_world = ground_position + anchor_normal * TOE_CLEARANCE
	chain.ground_normal = anchor_normal

func _ground_hit(world_position: Vector3) -> Dictionary:
	if _collision_mask == 0:
		return {}
	var query := PhysicsRayQueryParameters3D.create(
		world_position + Vector3.UP * PROBE_ABOVE,
		world_position - Vector3.UP * PROBE_BELOW,
		_collision_mask
	)
	query.exclude = [_player.get_rid()]
	query.collide_with_areas = false
	return _player.get_world_3d().direct_space_state.intersect_ray(query)

func _apply_leg_target(chain: FootChain) -> void:
	var thigh_pose := _skeleton.get_bone_global_pose(chain.thigh)
	var shin_pose := _skeleton.get_bone_global_pose(chain.shin)
	var foot_pose := _skeleton.get_bone_global_pose(chain.foot)
	var toe_pose := _skeleton.get_bone_global_pose(chain.toe)
	var hip := thigh_pose.origin
	var knee := shin_pose.origin
	var ankle := foot_pose.origin
	var upper_length := hip.distance_to(knee)
	var lower_length := knee.distance_to(ankle)
	if upper_length < 0.001 or lower_length < 0.001:
		return

	var local_foot_toe := foot_pose.affine_inverse() * toe_pose
	var target_toe := _skeleton.global_transform.affine_inverse() * chain.target_world
	var target_ankle := target_toe - foot_pose.basis * local_foot_toe.origin
	var hip_to_ankle := target_ankle - hip
	var raw_distance := hip_to_ankle.length()
	if raw_distance < 0.001:
		return
	var minimum_distance := absf(upper_length - lower_length) + IK_REACH_MARGIN
	var maximum_distance := upper_length + lower_length - IK_REACH_MARGIN
	var reach := clampf(raw_distance, minimum_distance, maximum_distance)
	var axis := hip_to_ankle / raw_distance
	target_ankle = hip + axis * reach

	var pole := knee - hip
	pole -= axis * pole.dot(axis)
	if pole.length_squared() < 0.00001:
		pole = Vector3.FORWARD - axis * Vector3.FORWARD.dot(axis)
	if pole.length_squared() < 0.00001:
		pole = Vector3.RIGHT - axis * Vector3.RIGHT.dot(axis)
	pole = pole.normalized()
	var along := (upper_length * upper_length - lower_length * lower_length + reach * reach) / (2.0 * reach)
	var bend := sqrt(maxf(0.0, upper_length * upper_length - along * along))
	var solved_knee := hip + axis * along + pole * bend

	var current_upper := knee - hip
	var desired_upper := solved_knee - hip
	if current_upper.length_squared() > 0.00001 and desired_upper.length_squared() > 0.00001:
		var upper_rotation := Quaternion(current_upper.normalized(), desired_upper.normalized())
		thigh_pose.basis = Basis(upper_rotation) * thigh_pose.basis.orthonormalized()
		_skeleton.set_bone_global_pose(chain.thigh, thigh_pose)
		_skeleton.force_update_bone_child_transform(chain.thigh)

	var solved_shin := _skeleton.get_bone_global_pose(chain.shin)
	var solved_foot := _skeleton.get_bone_global_pose(chain.foot)
	var current_lower := solved_foot.origin - solved_shin.origin
	var desired_lower := target_ankle - solved_shin.origin
	if current_lower.length_squared() > 0.00001 and desired_lower.length_squared() > 0.00001:
		var lower_rotation := Quaternion(current_lower.normalized(), desired_lower.normalized())
		solved_shin.basis = Basis(lower_rotation) * solved_shin.basis.orthonormalized()
		_skeleton.set_bone_global_pose(chain.shin, solved_shin)
		_skeleton.force_update_bone_child_transform(chain.shin)

	var final_foot := _skeleton.get_bone_global_pose(chain.foot)
	final_foot.origin = target_ankle
	final_foot.basis = foot_pose.basis
	_skeleton.set_bone_global_pose(chain.foot, final_foot)

func _is_locomotion_clip() -> bool:
	var active_animation := String(_player.get("current_anim")).to_lower()
	return active_animation.contains("walk") or active_animation.contains("run")

func _clear_contacts() -> void:
	if _left:
		_left.planted = false
	if _right:
		_right.planted = false
