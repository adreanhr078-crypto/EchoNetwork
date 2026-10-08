extends Node3D

## Local presentation of the existing three contacts. No animation keys,
## damage, interaction or progression is authored by this visual controller.
var skeleton: Skeleton3D
var reduced_motion := false
var contacts := 0
var collar := false
var _phase := 0.0
var _impact_age := 3.0
var _bones: Dictionary = {}
var _axes: Dictionary = {}
var _rests: Dictionary = {}

func setup(rig: Skeleton3D) -> bool:
	skeleton=rig
	for label in ["Spine","Spine1","Chest","Neck","Head","LeftShoulder","RightShoulder","LeftArm","RightArm","LeftForeArm","RightForeArm"]:
		var index:=rig.find_bone(label)
		if index<0: return false
		_bones[label]=index
		_axes[label]=rig.get_bone_global_rest(index).basis.inverse()
		_rests[label]=rig.get_bone_rest(index).basis.get_rotation_quaternion()
	for column in 5:
		for row in 2:
			var label:="Coat_%d_%d"%[column,row]
			var index:=rig.find_bone(label)
			if index<0: return false
			_bones[label]=index
			_axes[label]=rig.get_bone_global_rest(index).basis.inverse()
			_rests[label]=rig.get_bone_rest(index).basis.get_rotation_quaternion()
	_apply_pose()
	return true

func set_contact_count(value: int) -> void:
	contacts=clampi(value,0,3)
	_impact_age=0.0
	_apply_pose()

func begin_collar() -> void:
	collar=true
	_impact_age=3.0
	_apply_pose()

func _process(delta: float) -> void:
	if not is_instance_valid(skeleton): return
	if not reduced_motion:
		_phase+=delta
		_impact_age+=delta
	_apply_pose()

func _rotation(label: String, axis: Vector3, degrees: float) -> void:
	var local: Vector3=(_axes[label]*axis).normalized()
	skeleton.set_bone_pose_rotation(_bones[label],_rests[label]*Quaternion(local,deg_to_rad(degrees)))

func _apply_pose() -> void:
	if not is_instance_valid(skeleton): return
	# A Godot bone pose is a parent-relative local transform. Its imported
	# nonidentity rest must stay in that transform; identity is not rest for a
	# down-arm source. Restore once, then compose a bounded local delta.
	for index in _bones.values(): skeleton.reset_bone_pose(index)
	var breath: float=0.0 if reduced_motion else sin(_phase*1.55)*0.24
	var tremor: float=0.0 if reduced_motion else sin(_phase*5.1)*0.16*contacts
	var impact: float=0.0 if reduced_motion else maxf(0.0,sin(minf(_impact_age/0.16,1.0)*PI*0.5)*(1.0-smoothstep(0.16,0.85,_impact_age)))
	var settled: float=contacts*2.2+(3.0 if collar else 0.0)
	var recoil: float=impact*(8.0+contacts*1.5)-settled
	# Source front is +X, source up is +Y. These axes are converted through
	# actual imported global rests; the original asymmetric arm bind is kept.
	_rotation("Spine",Vector3.BACK,recoil*0.36+breath)
	_rotation("Spine1",Vector3.BACK,recoil*0.22)
	_rotation("Chest",Vector3.BACK,recoil*0.42-breath*0.4)
	_rotation("Neck",Vector3.BACK,-settled*0.10)
	_rotation("Head",Vector3.BACK,-settled*0.42+impact*5.0+breath*0.6)
	var head_index: int=_bones["Head"]
	var local_roll: Vector3=(_axes["Head"]*Vector3.RIGHT).normalized()
	skeleton.set_bone_pose_rotation(head_index,skeleton.get_bone_pose_rotation(head_index)*Quaternion(local_roll,deg_to_rad(-contacts*1.1+tremor)))
	_rotation("LeftShoulder",Vector3.RIGHT,-contacts*0.8-tremor)
	_rotation("RightShoulder",Vector3.RIGHT,contacts*0.8+tremor)
	_rotation("LeftArm",Vector3.BACK,impact*5.0+(4.0 if collar else 0.0))
	_rotation("RightArm",Vector3.BACK,impact*8.0+(8.0 if collar else contacts*0.8))
	_rotation("LeftForeArm",Vector3.BACK,impact*6.0+(8.0 if collar else 0.0))
	_rotation("RightForeArm",Vector3.BACK,impact*10.0+(22.0 if collar else contacts*1.8))
	for column in 5:
		for row in 2:
			_rotation("Coat_%d_%d"%[column,row],Vector3.BACK,0.0 if reduced_motion else sin(_phase*1.4+column*0.7)*0.20)
