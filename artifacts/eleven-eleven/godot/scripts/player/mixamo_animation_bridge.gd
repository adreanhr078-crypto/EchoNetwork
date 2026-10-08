class_name MixamoAnimationBridge
extends RefCounted

const AUTHORED_TRAVERSAL = preload("res://assets/animations/echo_parkour_v1.res")


## MixamoAnimationBridge
## Dynamically loads authored Mixamo FBX animations, retargets their humanoid tracks
## to Echo's Tripo skeleton bones, and registers them into Echo's AnimationPlayer.

const BONE_MAP: Dictionary = {
	"mixamorig_Hips": "tripo__Root",
	"mixamorig_Spine": "tripo__Spine_0",
	"mixamorig_Spine1": "tripo__Spine_1",
	"mixamorig_Spine2": "tripo__Spine_2",
	"mixamorig_Neck": "tripo__Head_0",
	"mixamorig_Head": "tripo__Head_1",
	# Historical candidate mapping, unverified; not used by runtime.
	"mixamorig_LeftShoulder": "bone_6",
	"mixamorig_LeftArm": "tripo__0_Right_Limb_0",
	"mixamorig_LeftForeArm": "tripo__0_Right_Limb_1",
	"mixamorig_LeftHand": "tripo__0_Right_Limb_2",
	"mixamorig_RightShoulder": "tripo__Spine_3",
	"mixamorig_RightArm": "tripo__Spine_4",
	"mixamorig_RightForeArm": "tripo__0_Left_Limb_0",
	"mixamorig_RightHand": "tripo__0_Left_Limb_1",
	"mixamorig_LeftUpLeg": "tripo__1_Right_Limb_0",
	"mixamorig_LeftLeg": "tripo__1_Right_Limb_1",
	"mixamorig_LeftFoot": "tripo__1_Right_Limb_2",
	"mixamorig_LeftToeBase": "tripo__1_Right_Limb_3",
	"mixamorig_RightUpLeg": "tripo__1_Left_Limb_0",
	"mixamorig_RightLeg": "tripo__1_Left_Limb_1",
	"mixamorig_RightFoot": "tripo__1_Left_Limb_2",
	"mixamorig_RightToeBase": "tripo__1_Left_Limb_3",
}

const ANIM_DEFS: Dictionary = {
	"ATTACK_1": ["res://assets/animations/Great_Sword_Slash.fbx", "res://assets/animations/Great Sword Slash.fbx"],
	"ATTACK_2": ["res://assets/animations/Standing Melee Attack Downward.fbx", "res://assets/animations/Melee_Attack_Downward.fbx"],
	"ATTACK_3": ["res://assets/animations/Flip Kick.fbx", "res://assets/animations/Standing Melee Attack Kick Ver. 2.fbx"],
	"DODGE_ROLL": ["res://assets/animations/Stand To Roll.fbx", "res://assets/animations/Run_To_Rolling.fbx", "res://assets/animations/Run To Rolling.fbx"],
	"WALL_RUN": ["res://assets/animations/Wall Run.fbx"],
	"CLIMB": ["res://assets/animations/Climbing_Up_Wall.fbx", "res://assets/animations/Climbing Up Wall.fbx"],
	"BACKFLIP": ["res://assets/animations/Backflip.fbx"],
	"HARD_LANDING": ["res://assets/animations/Hard_Landing.fbx", "res://assets/animations/Hard Landing.fbx"],
}

static var _cached_anims: Dictionary = {}

static func inject_animations(ap: AnimationPlayer, bypass_baked: bool=false) -> void:
	if not ap:
		return
	var target := ap.get_parent().find_child("Skeleton3D", true, false) as Skeleton3D
	if not target: return
	# This library was authored on the legacy rest rig. Foreign targets keep their own clips.
	var profile := preload("res://scripts/player/echo_rig_profile.gd").identify(target)
	if not profile.get("legacy_clips",false): return
	var rig_key := ""
	for bone in target.get_bone_count():
		rig_key += target.get_bone_name(bone) + str(target.get_bone_rest(bone))

	var lib: AnimationLibrary = ap.get_animation_library("")
	if not lib:
		lib = AnimationLibrary.new()
		ap.add_animation_library("", lib)

	var skel_prefix: String = "EchoOpeningUniformRig/Skeleton3D"
	for existing_name in ap.get_animation_list():
		var sample_anim = ap.get_animation(existing_name)
		if sample_anim and sample_anim.get_track_count() > 0:
			var sample_track = String(sample_anim.track_get_path(0))
			if sample_track.contains(":"):
				skel_prefix = sample_track.split(":")[0]
				break
	# These clips are baked on Echo's own rest rig, rather than transferred
	# as raw quaternions from a different skeleton. Keep the original model.
	var authored := AUTHORED_TRAVERSAL as AnimationLibrary
	if authored:
		for name in authored.get_animation_list():
			if lib.has_animation(name): continue
			var clip := authored.get_animation(name).duplicate(true) as Animation
			for track in range(clip.get_track_count()):
				var path := String(clip.track_get_path(track))
				if path.contains(":"):
					clip.track_set_path(track, NodePath(skel_prefix + ":" + path.get_slice(":", 1)))
			lib.add_animation(name, clip)

	# Foreign-rig clips remain quarantined until Golden verification and explicit rig compatibility evidence.
	# Do not copy foreign local quaternions or load the rejected fitted/resampled library.
	return
