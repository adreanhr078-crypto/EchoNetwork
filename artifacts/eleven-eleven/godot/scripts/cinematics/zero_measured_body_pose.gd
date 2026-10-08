extends RefCounted

## Source-preserving articulation only for a measured exact rig map. This
## fallback authors no clip keys and never changes the imported bone rests.
var skeleton: Skeleton3D
var _indices: Dictionary = {}
var _rests: Dictionary = {}
var _axes: Dictionary = {}
var _pact_weight := 0.0
var _front := Vector3.RIGHT
var _up := Vector3.UP

func setup(rig: Skeleton3D, profile: Dictionary) -> bool:
	skeleton=rig
	var map=profile.get("articulation_bones",{})
	if not map is Dictionary: return false
	var front_data=profile.get("source_front",[1.0,0.0,0.0])
	if front_data.size()!=3: return false
	_front=Vector3(front_data[0],front_data[1],front_data[2]).normalized()
	if _front.length()<0.9 or absf(_front.dot(_up))>0.2: return false
	for role in ["spine","chest","head","left_arm","left_forearm","left_hand","right_arm","right_forearm","right_hand"]:
		var label: String=str(map.get(role,""))
		var index:=rig.find_bone(label)
		if index<0: return false
		_indices[role]=index
		_rests[role]=rig.get_bone_rest(index).basis.get_rotation_quaternion()
		_axes[role]=rig.get_bone_global_rest(index).basis.inverse()
	return true

func tick(phase: float, still: bool, accepted: bool, delta: float) -> void:
	if not is_instance_valid(skeleton): return
	var target:=1.0 if accepted else 0.0
	_pact_weight=target if still else move_toward(_pact_weight,target,delta/0.85)
	# Feet, hips and root retain their measured source poses. The hovering
	# giant speaks through head/chest and separate arm/hand motion only.
	for index in _indices.values(): skeleton.reset_bone_pose(index)
	var side:=_front.cross(_up).normalized()
	_rotate("spine",side,sin(phase*1.12)*0.36)
	_rotate("chest",side,sin(phase*1.12+0.3)*0.45+_pact_weight*0.50)
	_rotate("head",side,0.65+sin(phase*0.48)*0.70+_pact_weight*1.15)
	_append("head",_up,sin(phase*0.31)*0.90)
	_rotate("left_arm",side,sin(phase*0.53+0.9)*1.9+_pact_weight*4.0)
	_rotate("left_forearm",side,sin(phase*0.63+1.4)*1.6+_pact_weight*3.2)
	_rotate("left_hand",_front,sin(phase*0.71+0.3)*2.1+_pact_weight*2.2)
	_rotate("right_arm",side,-sin(phase*0.42+0.5)*1.7-_pact_weight*3.5)
	_rotate("right_forearm",side,-sin(phase*0.50+1.1)*1.8-_pact_weight*3.8)
	_rotate("right_hand",_front,-sin(phase*0.67+1.2)*1.9-_pact_weight*1.8)

func _rotate(role: String, axis: Vector3, degrees: float) -> void:
	var local: Vector3=(_axes[role]*axis).normalized()
	skeleton.set_bone_pose_rotation(_indices[role],_rests[role]*Quaternion(local,deg_to_rad(degrees)))

func _append(role: String, axis: Vector3, degrees: float) -> void:
	var local: Vector3=(_axes[role]*axis).normalized()
	var index: int=_indices[role]
	skeleton.set_bone_pose_rotation(index,skeleton.get_bone_pose_rotation(index)*Quaternion(local,deg_to_rad(degrees)))
