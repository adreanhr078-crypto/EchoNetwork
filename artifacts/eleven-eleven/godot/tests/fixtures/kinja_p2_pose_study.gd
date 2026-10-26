extends Node3D

## ISOLATED STUDY. Not referenced by the runtime Kinja actor. Replays the raw
## 24Hz source before adding upper-body reaction deltas. No rest reset, root
## extraction, foot edits, face rig claims or progression authority.
var skeleton: Skeleton3D
var animation: AnimationPlayer
var reduced_motion := false
var contacts := 0
var collar := false
var _clip := ""
var _source_time := 1.0/24.0
var _impact_age := 3.0
var _bones := {}
var _base := {}
var _axes := {}

func setup(rig: Skeleton3D, mixer: AnimationPlayer) -> bool:
	if rig == null or mixer == null or mixer.get_animation_list().size() != 1: return false
	skeleton = rig
	animation = mixer
	for label in ["Spine","Spine1","Spine2","Neck","Head","LeftShoulder","RightShoulder","LeftArm","RightArm","LeftForeArm","RightForeArm"]:
		var index := rig.find_bone("mixamorig_"+label)
		if index<0: index=rig.find_bone("mixamorig:"+label)
		if index<0: return false
		_bones[label]=index
	_clip=animation.get_animation_list()[0]
	animation.active=true
	animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animation.root_motion_track=NodePath("")
	# Playback mode is local to this candidate, source keys are untouched.
	animation.get_animation(_clip).loop_mode=Animation.LOOP_NONE
	evaluate_source(_source_time)
	return true

func set_contact_count(value: int) -> void:
	contacts=clampi(value,0,3)
	_impact_age=0.0
	evaluate_source(_source_time)

func begin_collar() -> void:
	collar=true
	_impact_age=3.0
	evaluate_source(_source_time)

func _process(delta: float) -> void:
	if not is_instance_valid(skeleton): return
	# Event age continues while ambient movement is reduced. Re-enabling motion
	# must not replay a contact which happened several seconds earlier.
	_impact_age+=delta
	if not reduced_motion:
		_source_time=1.0/24.0+fposmod(_source_time-1.0/24.0+delta,animation.get_animation(_clip).length-1.0/24.0)
	evaluate_source(_source_time)

func evaluate_source(time: float) -> void:
	if not is_instance_valid(animation): return
	_source_time=time
	animation.play(_clip,0.0)
	animation.seek(time,true)
	animation.pause()
	skeleton.force_update_all_bone_transforms()
	for label in _bones:
		var index: int=_bones[label]
		_base[label]=skeleton.get_bone_pose_rotation(index)
		_axes[label]=skeleton.get_bone_global_pose(index).basis.orthonormalized().inverse()
	_apply_reaction()

func _rotation(label: String, axis: Vector3, degrees: float) -> void:
	var local: Vector3=(_axes[label]*axis).normalized()
	skeleton.set_bone_pose_rotation(_bones[label],_base[label]*Quaternion(local,deg_to_rad(degrees)))

func _apply_reaction() -> void:
	# This source faces +Z. Positive rotation around +X bends toward its front.
	var impact := 0.0 if reduced_motion else maxf(0.0,sin(minf(_impact_age/0.16,1.0)*PI*0.5)*(1.0-smoothstep(0.16,0.85,_impact_age)))
	var settled := contacts*2.2+(3.0 if collar else 0.0)
	var bend := settled-impact*(8.0+contacts*1.5)
	_rotation("Spine",Vector3.RIGHT,bend*0.36)
	_rotation("Spine1",Vector3.RIGHT,bend*0.22)
	_rotation("Spine2",Vector3.RIGHT,bend*0.42)
	_rotation("Neck",Vector3.RIGHT,settled*0.10)
	_rotation("Head",Vector3.RIGHT,settled*0.42-impact*5.0)
	var head: int=_bones["Head"]
	var roll: Vector3=(_axes["Head"]*Vector3.BACK).normalized()
	skeleton.set_bone_pose_rotation(head,skeleton.get_bone_pose_rotation(head)*Quaternion(roll,deg_to_rad(-contacts*1.1)))
	_rotation("LeftShoulder",Vector3.BACK,-contacts*0.8)
	_rotation("RightShoulder",Vector3.BACK,contacts*0.8)
	_rotation("LeftArm",Vector3.RIGHT,impact*5.0+(4.0 if collar else 0.0))
	_rotation("RightArm",Vector3.RIGHT,impact*8.0+(8.0 if collar else contacts*0.8))
	_rotation("LeftForeArm",Vector3.RIGHT,impact*6.0+(8.0 if collar else 0.0))
	_rotation("RightForeArm",Vector3.RIGHT,impact*10.0+(22.0 if collar else contacts*1.8))
