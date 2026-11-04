extends Node3D
## Candidate only. Libraries retain the independently qualified source keys.
const RigProfile = preload("res://scripts/player/echo_rig_profile.gd")
const LIBRARIES := {
	"IDLE": preload("res://assets/animations/school65/idle_qualified.res"),
	"WALK": preload("res://assets/animations/school65/walk_qualified.res"),
	"RUN": preload("res://assets/animations/school65/run_qualified.res"),
	"preset_jump": preload("res://assets/animations/school65/jump_qualified.res"),
	"PARKOUR_HANG": preload("res://assets/animations/school65/hang_qualified.res"),
	"PARKOUR_MANTLE": preload("res://assets/animations/school65/mantle_qualified.res"),
	"PARKOUR_STAND": preload("res://assets/animations/school65/stand_qualified.res"),
	"preset_biped_roll_001": preload("res://assets/animations/school65/roll_qualified.res"),
	"preset_wakeup": preload("res://assets/animations/school65/wake_qualified.res"),
	"MELEE_HORIZONTAL": preload("res://assets/animations/school65/attack_horizontal_qualified.res"),
}
const ACTIONS := {"IDLE":"Idle_Source_Retarget", "WALK":"Walk_Source_Retarget",
	"RUN":"Run_Source_Retarget", "preset_jump":"Jump_Source_Retarget",
	"PARKOUR_HANG":"Hang_Source_Retarget","PARKOUR_MANTLE":"Mantle_Source_Retarget","PARKOUR_STAND":"Stand_Source_Retarget","preset_biped_roll_001":"Roll_Source_Retarget","preset_wakeup":"Wake_Source_Retarget","MELEE_HORIZONTAL":"Attack_Source_Retarget"}
var _skeleton: Skeleton3D
var _mixer: AnimationPlayer
var _body: CharacterBody3D
var _hips := -1
var _base_position := Vector3.ZERO
var _left_hand := -1
var _right_hand := -1
var _hang_offset := Vector3.ZERO
var _native_return_remaining := 0.0
var _native_return_duration := 0.2
var _native_return_origin := Vector3.ZERO
var _wake_contacts: Dictionary = {}
var _roll_skin_floor_profile: Dictionary = {}

func source_libraries() -> Dictionary: return LIBRARIES
func source_actions() -> Dictionary: return ACTIONS
func source_profile_id() -> String: return RigProfile.SCHOOL65_ID
func supports_inverted_hull_outline() -> bool:
	# School's single atlas includes very close garment folds. An expanded
	# backface pass pushes through those folds as black slashes. Keep the cel
	# and rim materials; the source mesh, maps and motion keys stay untouched.
	# Derived profiles retain their own existing outline policy until reviewed.
	return source_profile_id() != RigProfile.SCHOOL65_ID
func align_additional_presentation() -> void:
	if _mixer.current_animation!="preset_biped_roll_001" or _roll_skin_floor_profile.is_empty():return
	var offsets:Array=_roll_skin_floor_profile.offsets
	var sample:=clampf(_mixer.current_animation_position*float(_roll_skin_floor_profile.fps),0.0,offsets.size()-1)
	var low:=int(floor(sample))
	position.y+=lerpf(float(offsets[low]),float(offsets[mini(low+1,offsets.size()-1)]),sample-low)
func bind_source_paths(source: Animation, _root: Node) -> Animation:return source

func _ready() -> void:
	if source_profile_id()==RigProfile.SCHOOL65_ID:
		_roll_skin_floor_profile=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animations/school65/roll-skin-floor-profile.json"))
	_skeleton = find_child("Skeleton3D",true,false) as Skeleton3D
	_mixer = find_child("AnimationPlayer",true,false) as AnimationPlayer
	if not _mixer or RigProfile.identify(_skeleton).get("id") != source_profile_id():
		push_error("School65 candidate identity unavailable; foreign clips refused")
		return
	var library := _mixer.get_animation_library("") if _mixer.has_animation_library("") else AnimationLibrary.new()
	if not _mixer.has_animation_library(""): _mixer.add_animation_library("",library)
	var animation_root := _mixer.get_node(_mixer.root_node)
	var libraries := source_libraries()
	var actions := source_actions()
	for alias: String in libraries:
		var original: Animation = libraries[alias].get_animation(actions[alias])
		original=bind_source_paths(original,animation_root)
		for track in original.get_track_count():
			var path := original.track_get_path(track)
			var target := animation_root.get_node_or_null(NodePath(path.get_concatenated_names()))
			if not target or (target is Skeleton3D and target.find_bone(str(path.get_subname(0))) < 0):
				push_error("School65 source track unresolved: " + str(path))
				return
		var clip: Animation = original.duplicate()
		clip.loop_mode = Animation.LOOP_LINEAR if alias in ["IDLE","WALK","RUN"] else Animation.LOOP_NONE
		if alias == "PARKOUR_HANG": clip.set_meta("wall_support_pose_seconds",0.0)
		if alias == "preset_biped_roll_001": clip.set_meta("runtime_action_duration_seconds",LocomotionAnimController.ROLL_DURATION)
		if alias == "MELEE_HORIZONTAL":
			clip.set_meta("melee_contact_seconds",.95)
			clip.set_meta("melee_cancel_seconds",1.2)
			clip.set_meta("melee_physical_blade",true)
			clip.set_meta("melee_window_open_seconds",.8)
			clip.set_meta("melee_window_close_seconds",1.1)
		if alias == "preset_wakeup":
			_wake_contacts = clip.get_meta("source_skin_contacts",{})
			if _wake_contacts.get("offsets",[]).size() != 481 or _wake_contacts.get("fixed_anchor_xz",[]).size() != 2:
				push_error("School65 Wake requires its measured native skin contacts")
				return
		library.add_animation(alias,clip)
	for mesh in find_children("*","MeshInstance3D",true,false):
		if mesh.skin: mesh.name = "EchoSchoolBody"
	set_meta("motion_support",{"idle":"qualified","walk":"qualified","run":"qualified Jog source",
		"jump":"qualified","wake":"qualified native24Hz;measured skin contacts","traversal":"native Hang/Mantle/Stand qualified;runtime contact gate separate","combat":"qualified horizontal source;physical blade window","face":"deferred by Owner"})
	var owner_body := get_parent().get_parent() if get_parent() else null
	if owner_body is CharacterBody3D:
		_body = owner_body
		_hips = _skeleton.find_bone("mixamorig_Hips")
		_left_hand = _skeleton.find_bone("mixamorig_LeftHand")
		_right_hand = _skeleton.find_bone("mixamorig_RightHand")
		_base_position = position
		_mixer.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
		_mixer.mixer_applied.connect(_sync_capsule_alignment)
		_mixer.animation_started.connect(_reset_unkeyed_body_properties)

func _reset_unkeyed_body_properties(alias: StringName) -> void:
	if not _mixer.has_animation(alias):return
	var clip:=_mixer.get_animation(alias)
	var keyed:Dictionary={}
	for track in clip.get_track_count():
		var path:=clip.track_get_path(track)
		if path.get_subname_count()!=1:continue
		keyed[str(path.get_subname(0))+":"+str(clip.track_get_type(track))]=true
	for bone in _skeleton.get_bone_count():
		var name:=_skeleton.get_bone_name(bone)
		if name.begins_with("Wing"):continue
		var rest:=_skeleton.get_bone_rest(bone)
		if not keyed.has(name+":"+str(Animation.TYPE_POSITION_3D)):_skeleton.set_bone_pose_position(bone,rest.origin)
		if not keyed.has(name+":"+str(Animation.TYPE_ROTATION_3D)):_skeleton.set_bone_pose_rotation(bone,rest.basis.get_rotation_quaternion())
		if not keyed.has(name+":"+str(Animation.TYPE_SCALE_3D)):_skeleton.set_bone_pose_scale(bone,rest.basis.get_scale())

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_body): return
	if _native_return_remaining > 0.0:
		_native_return_remaining = maxf(0.0,_native_return_remaining-delta)
		_hang_offset = _native_return_origin*(_native_return_remaining/_native_return_duration)
	elif not _body.surface_motor.hanging and not _body.surface_motor.native_mantle_active:
		_hang_offset = _hang_offset.move_toward(Vector3.ZERO,delta*5.0)

func locomotion_reference_speed(clip: String, fallback: float) -> float:
	if not _mixer or not _mixer.has_animation(clip): return fallback
	var value := float(_mixer.get_animation(clip).get_meta("source_ground_speed_mps",0.0))
	var speed := value * _skeleton.global_basis.x.length()
	return speed if is_finite(speed) and speed > 0.01 else fallback

func opening_contact_alignment(phase: float) -> Vector3:
	if _wake_contacts.is_empty() or not is_finite(phase): return Vector3.ZERO
	var offsets: Array = _wake_contacts.offsets
	var sample := clampf(phase,0.0,1.0)*(offsets.size()-1)
	var lower := int(floor(sample))
	var height := lerpf(float(offsets[lower]),float(offsets[mini(lower+1,offsets.size()-1)]),sample-lower)
	# A fixed translation anchors the final stance to the capsule while preserving
	# the entire authored horizontal path and all bone keys during the rise.
	return Vector3(float(_wake_contacts.fixed_anchor_xz[0]),height,float(_wake_contacts.fixed_anchor_xz[1]))

func _sync_capsule_alignment() -> void:
	if not is_instance_valid(_body) or _hips < 0: return
	if _body.surface_motor.native_mantle_active:
		_body.surface_motor.sync_native_visual()
		return
	if _mixer.current_animation == "PARKOUR_HANG" and _body.surface_motor.hanging:
		position = _base_position
		var grip := (_skeleton.to_global(_skeleton.get_bone_global_pose(_left_hand).origin)+_skeleton.to_global(_skeleton.get_bone_global_pose(_right_hand).origin))*0.5
		_hang_offset = get_parent().to_local(_body.surface_motor.hang_grip_world)-get_parent().to_local(grip)
		position = _base_position+_hang_offset
		return
	position = _base_position+_hang_offset
	align_additional_presentation()
	_body.sync_native_blade_contact()
	if _body.opening_recovery_active and _mixer.current_animation == "preset_wakeup":
		# Align the current physics sample before skeleton/skin evaluation, rather
		# than waiting for the next process-frame recovery coroutine.
		_body._align_recovery_feet_to_floor()
		return
	if _mixer.current_animation not in ["WALK","RUN","preset_biped_roll_001"]: return
	# Keep capsule displacement authoritative, retaining vertical gait and every bone key.
	var delta := _skeleton.get_bone_global_pose(_hips).origin - _skeleton.get_bone_global_rest(_hips).origin
	var local_delta: Vector3 = get_parent().global_basis.inverse() * (_skeleton.global_basis * delta)
	position -= Vector3(local_delta.x,0.0,local_delta.z)

func release_native_traversal() -> float:
	_native_return_origin = position-_base_position
	_hang_offset = _native_return_origin
	_native_return_duration = maxf(0.2,_native_return_origin.length()/2.0)
	_native_return_remaining = _native_return_duration
	return _native_return_duration
