extends RefCounted

## Bone roles and local facing only. Identifying a rig does not approve its clips.
## Unknown skeletons fail closed instead of receiving another rig's animation.
const LEGACY_ID := "echo_opening_v13"
const V31_ID := "echo_v31_authored_68"
const SCHOOL65_ID := "echo_school_mixamo_65"
const PACT72_ID := "echo_pact_mixamo_72"
const SCHOOL65_BONES := {
	"neck":"mixamorig_Neck", "head":"mixamorig_Head", "pelvis":"mixamorig_Hips",
	"left_hand":"mixamorig_LeftHand", "right_hand":"mixamorig_RightHand",
	"left_foot":"mixamorig_LeftFoot", "right_foot":"mixamorig_RightFoot",
	"left_toe":"mixamorig_LeftToeBase", "right_toe":"mixamorig_RightToeBase", "weapon_hand":"mixamorig_RightHand",
}
const LEGACY_BONES := {
	"neck":"tripo__Head_0", "head":"tripo__Head_1", "pelvis":"tripo__Spine_0",
	"left_toe":"tripo__1_Left_Limb_3", "right_toe":"tripo__1_Right_Limb_3",
	"weapon_hand":"tripo__0_Left_Limb_1",
}
const V31_BONES := {
	"neck":"Neck", "head":"Head", "pelvis":"Hips",
	"left_hand":"LeftHand", "right_hand":"RightHand",
	"left_foot":"LeftFoot", "right_foot":"RightFoot",
	"left_toe":"LeftToeBase", "right_toe":"RightToeBase", "weapon_hand":"RightHand",
}
const LEGACY_SERVICE_ARMS := [
	["tripo__0_Right_Limb_0","tripo__0_Right_Limb_1","tripo__0_Right_Limb_2"],
	["tripo__Spine_4","tripo__0_Left_Limb_0","tripo__0_Left_Limb_1"],
]
const V31_SERVICE_ARMS := [["RightArm","RightForeArm","RightHand"],["LeftArm","LeftForeArm","LeftHand"]]

static func identify(skeleton: Skeleton3D) -> Dictionary:
	if not skeleton: return {}
	if _has_roles(skeleton,LEGACY_BONES) and skeleton.find_bone("tripo__Root") >= 0:
		return {"id":LEGACY_ID,"bones":LEGACY_BONES,"service_arms":LEGACY_SERVICE_ARMS,
			"local_forward":Vector3.RIGHT,"yaw_offset":-PI*0.5,"legacy_clips":true}
	if skeleton.get_bone_count() == 68 and _has_roles(skeleton,V31_BONES) \
		and _chain(skeleton,["Root","Hips","Spine","Spine1","Spine2","Neck","Head"]):
		for side in ["Left","Right"]:
			if not _chain(skeleton,["Hips",side+"UpLeg",side+"Leg",side+"Foot",side+"ToeBase"]): return {}
			if not _chain(skeleton,["Spine2",side+"Shoulder",side+"Arm",side+"ForeArm",side+"Hand"]): return {}
			for finger in ["Thumb","Index","Middle","Ring","Pinky"]:
				if not _chain(skeleton,[side+"Hand",side+"Hand"+finger+"1",side+"Hand"+finger+"2",side+"Hand"+finger+"3"]): return {}
		for column in 5:
			var cape := ["Hips","Cape_%d_0"%column,"Cape_%d_1"%column,"Cape_%d_2"%column]
			if not _chain(skeleton,cape): return {}
		return {"id":V31_ID,"bones":V31_BONES,"service_arms":V31_SERVICE_ARMS,
			"local_forward":Vector3.BACK,"yaw_offset":0.0,"legacy_clips":false}
	if skeleton.get_bone_count() in [65,72] and _has_roles(skeleton,SCHOOL65_BONES) \
		and _chain(skeleton,["mixamorig_Hips","mixamorig_Spine","mixamorig_Spine1","mixamorig_Spine2","mixamorig_Neck","mixamorig_Head"]):
		for side in ["Left","Right"]:
			if not _chain(skeleton,["mixamorig_Hips","mixamorig_"+side+"UpLeg","mixamorig_"+side+"Leg","mixamorig_"+side+"Foot","mixamorig_"+side+"ToeBase"]): return {}
			if not _chain(skeleton,["mixamorig_Spine2","mixamorig_"+side+"Shoulder","mixamorig_"+side+"Arm","mixamorig_"+side+"ForeArm","mixamorig_"+side+"Hand"]): return {}
			for finger in ["Thumb","Index","Middle","Ring","Pinky"]:
				var hand: String = "mixamorig_"+str(side)+"Hand"
				if not _chain(skeleton,[hand,hand+finger+"1",hand+finger+"2",hand+finger+"3",hand+finger+"4"]): return {}
		if skeleton.get_bone_count()==72:
			if not _chain(skeleton,["mixamorig_Spine2","WingRootLeft","WingInnerLeft","WingOuterLeft","WingTipLeft","WingFanOuterLeft"]): return {}
			if not _chain(skeleton,["WingInnerLeft","WingFanInnerLeft"]) or not _chain(skeleton,["WingOuterLeft","WingFanMidLeft"]):return {}
		return {"id":PACT72_ID if skeleton.get_bone_count()==72 else SCHOOL65_ID,"bones":SCHOOL65_BONES,
			"body_mesh":"EchoSchoolBody","service_arms":[["mixamorig_RightArm","mixamorig_RightForeArm","mixamorig_RightHand"],["mixamorig_LeftArm","mixamorig_LeftForeArm","mixamorig_LeftHand"]],
			"local_forward":Vector3.BACK,"yaw_offset":0.0,"legacy_clips":false}
	return {}

static func body_name(profile: Dictionary) -> String:
	if profile.get("id") in [SCHOOL65_ID,PACT72_ID]: return "EchoSchoolBody"
	return "EchoV31BodyAndCoat" if profile.get("id") == V31_ID else "EchoOpeningUniformBody"

static func bone(skeleton: Skeleton3D, role: String) -> String:
	var profile := identify(skeleton)
	return str(profile.get("bones",{}).get(role,""))

static func _has_roles(skeleton: Skeleton3D, roles: Dictionary) -> bool:
	for name in roles.values():
		if skeleton.find_bone(name) < 0: return false
	return true

static func _chain(skeleton: Skeleton3D, names: Array) -> bool:
	var previous := -1
	for name in names:
		var index := skeleton.find_bone(str(name))
		if index < 0: return false
		if previous >= 0 and skeleton.get_bone_parent(index) != previous: return false
		previous = index
	return true
