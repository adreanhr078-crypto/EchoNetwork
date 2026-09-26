class_name MixamoAnimationBridge
extends RefCounted

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
	"mixamorig_RightShoulder": "bone_6",
	"mixamorig_RightArm": "tripo__0_Right_Limb_0",
	"mixamorig_RightForeArm": "tripo__0_Right_Limb_1",
	"mixamorig_RightHand": "tripo__0_Right_Limb_2",
	"mixamorig_LeftShoulder": "tripo__Spine_3",
	"mixamorig_LeftArm": "tripo__0_Left_Limb_0",
	"mixamorig_LeftForeArm": "tripo__0_Left_Limb_1",
	"mixamorig_LeftHand": "tripo__0_Left_Limb_1",
	"mixamorig_LeftUpLeg": "tripo__1_Left_Limb_0",
	"mixamorig_LeftLeg": "tripo__1_Left_Limb_1",
	"mixamorig_LeftFoot": "tripo__1_Left_Limb_2",
	"mixamorig_LeftToeBase": "tripo__1_Left_Limb_3",
	"mixamorig_RightUpLeg": "tripo__1_Right_Limb_0",
	"mixamorig_RightLeg": "tripo__1_Right_Limb_1",
	"mixamorig_RightFoot": "tripo__1_Right_Limb_2",
	"mixamorig_RightToeBase": "tripo__1_Right_Limb_3",
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

static func inject_animations(ap: AnimationPlayer) -> void:
	if not ap:
		return

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

	for anim_name in ANIM_DEFS:
		if lib.has_animation(anim_name):
			continue

		var retargeted_anim: Animation = _cached_anims.get(anim_name, null)
		if not retargeted_anim:
			var candidates: Array = ANIM_DEFS[anim_name]
			for fbx_path in candidates:
				if not ResourceLoader.exists(fbx_path):
					continue
				var packed: PackedScene = load(fbx_path) as PackedScene
				if not packed:
					continue
				var inst = packed.instantiate()
				var fbx_ap = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
				if fbx_ap and fbx_ap.get_animation_list().size() > 0:
					var src_anim: Animation = fbx_ap.get_animation(fbx_ap.get_animation_list()[0])
					retargeted_anim = _retarget_animation(src_anim, skel_prefix)
					if retargeted_anim:
						_cached_anims[anim_name] = retargeted_anim
				inst.free()
				if retargeted_anim:
					break

		if retargeted_anim:
			lib.add_animation(anim_name, retargeted_anim)

static func _retarget_animation(src: Animation, skel_prefix: String = "EchoOpeningUniformRig/Skeleton3D") -> Animation:
	if not src:
		return null

	var retargeted: Animation = Animation.new()
	retargeted.length = src.length
	retargeted.loop_mode = Animation.LOOP_NONE

	for i in range(src.get_track_count()):
		var path_str: String = String(src.track_get_path(i))
		for mix_bone in BONE_MAP:
			if path_str.ends_with(":" + mix_bone):
				var tripo_bone: String = BONE_MAP[mix_bone]
				var new_path := NodePath(skel_prefix + ":" + tripo_bone)
				var new_idx := retargeted.add_track(src.track_get_type(i))
				retargeted.track_set_path(new_idx, new_path)
				retargeted.track_set_interpolation_type(new_idx, src.track_get_interpolation_type(i))
				for k in range(src.track_get_key_count(i)):
					var k_time: float = src.track_get_key_time(i, k)
					var k_val = src.track_get_key_value(i, k)
					var k_trans: float = src.track_get_key_transition(i, k)
					retargeted.track_insert_key(new_idx, k_time, k_val, k_trans)
				break

	return retargeted
