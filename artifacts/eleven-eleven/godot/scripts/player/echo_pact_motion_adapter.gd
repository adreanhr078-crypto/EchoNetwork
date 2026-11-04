extends "res://scripts/player/echo_school_motion_adapter.gd"

## Qualified Pact72 body sources; eligible wing presentation is independent.
const PACT_FILES := {"IDLE":"idle","WALK":"walk","RUN":"run","preset_jump":"jump","PARKOUR_HANG":"hang","PARKOUR_MANTLE":"mantle","PARKOUR_STAND":"stand","preset_biped_roll_001":"roll","MELEE_HORIZONTAL":"attack-horizontal"}
var floor_profiles: Dictionary = {}
var wing_profile: Dictionary = {}
var wing_requested := false
var wing_reveal := 0.0
var wing_time := 0.0
var wing_intensity := 1.0
var wing_root := -1
var resonance: Node3D
var attachment: PactAttachment

class PactAttachment extends RefCounted:
	var skeleton: Skeleton3D
	var body: EchoPlayer
	var is_manifested := false
	func contract_is_sealed() -> bool:return is_instance_valid(body) and body.contract_with_zero_sealed

func source_profile_id() -> String:return RigProfile.PACT72_ID
func bind_source_paths(source: Animation, animation_root: Node) -> Animation:
	var clip: Animation=source.duplicate()
	var skeleton_path:=str(animation_root.get_path_to(_skeleton))
	for track in clip.get_track_count():
		var path:=clip.track_get_path(track)
		if path.get_subname_count()!=1 or _skeleton.find_bone(str(path.get_subname(0)))<0:
			push_error("Pact72 contains a foreign source track: "+str(path))
			return source
		clip.track_set_path(track,NodePath(skeleton_path+":"+str(path.get_subname(0))))
	return clip
func source_actions() -> Dictionary:
	var actions:=ACTIONS.duplicate()
	actions.erase("preset_wakeup")
	return actions
func source_libraries() -> Dictionary:
	var libraries := {}
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animations/pact72/candidate-manifest.json"))
	for alias in PACT_FILES:
		var path: String="res://assets/animations/pact72/"+PACT_FILES[alias]+"_qualified.res"
		if not ResourceLoader.exists(path) or FileAccess.get_sha256(path)!=manifest.get("libraries",{}).get(alias,{}).get("sha256",""):
			push_error("Qualified Pact72 source missing: "+path)
			return {}
		libraries[alias]=load(path)
	return libraries

func _ready() -> void:
	super._ready()
	if not is_instance_valid(_body):return
	floor_profiles=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animations/pact72/skin-floor-profiles.json"))
	wing_profile=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animations/pact72/wing-clearance-profile.json"))
	wing_root=_skeleton.find_bone("WingRootLeft")
	attachment=PactAttachment.new()
	attachment.skeleton=_skeleton
	attachment.body=_body
	var socket:=BoneAttachment3D.new()
	socket.name="NativePactResonanceSocket"
	socket.bone_name="WingRootLeft"
	_skeleton.add_child(socket)
	resonance=preload("res://scripts/player/echo_contract_resonance.gd").new()
	socket.add_child(resonance)
	resonance.configure(attachment)
	_apply_wing_presentation()
	set_meta("wing_solver","Measured source-phase wing clearance;no SpringBone until separate animated contact gate")

func set_wing_manifested(enabled: bool, intensity: float=1.0) -> void:
	wing_requested=enabled and is_instance_valid(_body) and _body.contract_with_zero_sealed
	wing_intensity=clampf(intensity,0.0,1.35)
	if is_instance_valid(_body) and _body.reduced_motion:wing_reveal=1.0 if wing_requested else 0.0
	_apply_wing_presentation()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_instance_valid(_body):return
	var traversal_hidden:bool=_body.is_dodging or _body.surface_motor.hanging or _body.surface_motor.native_mantle_active
	var target:=1.0 if wing_requested and not traversal_hidden and _body.contract_with_zero_sealed else 0.0
	if traversal_hidden or _body.reduced_motion:wing_reveal=target
	else:wing_reveal=move_toward(wing_reveal,target,delta*5.0)
	if not _body.reduced_motion:wing_time+=delta
	_apply_wing_presentation()
	attachment.is_manifested=wing_reveal>.01
	resonance.present(wing_time,wing_reveal,wing_intensity,_body.reduced_motion)

func align_additional_presentation() -> void:
	if not is_instance_valid(_body) or not _mixer:return
	var clip:=_mixer.current_animation
	if (_body.is_on_floor() or clip=="preset_biped_roll_001") and clip in ["IDLE","WALK","RUN","MELEE_HORIZONTAL","preset_biped_roll_001"] and floor_profiles.has(clip):
		var profile: Dictionary=floor_profiles[clip]
		var offsets: Array=profile.offsets
		var sample:=clampf(_mixer.current_animation_position*float(profile.fps),0.0,offsets.size()-1)
		var low:=int(floor(sample))
		position.y+=lerpf(float(offsets[low]),float(offsets[mini(low+1,offsets.size()-1)]),sample-low)
	_apply_wing_presentation()

func _apply_wing_presentation() -> void:
	if not _skeleton or wing_root<0:return
	_skeleton.set_bone_pose_scale(wing_root,Vector3.ONE*maxf(.001,wing_reveal))
	# Phase profile is measured on this exact target and source,not body posing.
	if wing_profile.is_empty():return
	var rotation:=Quaternion.IDENTITY
	if _mixer.current_animation=="MELEE_HORIZONTAL":
		var sample:=clampf(_mixer.current_animation_position*float(wing_profile.fps),0.0,wing_profile.rotations.size()-1)
		var index:=int(floor(sample))
		var a: Array=wing_profile.rotations[index]
		var b: Array=wing_profile.rotations[mini(index+1,wing_profile.rotations.size()-1)]
		rotation=Quaternion(a[0],a[1],a[2],a[3]).slerp(Quaternion(b[0],b[1],b[2],b[3]),sample-index)
	_skeleton.set_bone_pose_rotation(wing_root,_skeleton.get_bone_rest(wing_root).basis.get_rotation_quaternion()*rotation)
