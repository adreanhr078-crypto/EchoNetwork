extends SceneTree

const Profile = preload("res://scripts/player/echo_rig_profile.gd")

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var legacy = load("res://assets/characters/echo_opening_uniform_v13.glb").instantiate()
	var skeleton: Skeleton3D = legacy.find_child("Skeleton3D",true,false)
	var profile: Dictionary = Profile.identify(skeleton)
	assert(profile.get("id") == Profile.LEGACY_ID and profile.get("legacy_clips"))
	assert(Profile.bone(skeleton,"weapon_hand") == "tripo__0_Left_Limb_1")
	_check_heading(profile)
	legacy.free()
	var authored := Skeleton3D.new()
	_add_chain(authored,["Root","Hips","Spine","Spine1","Spine2","Neck","Head"])
	for side in ["Left","Right"]:
		_add_chain(authored,["Spine2",side+"Shoulder",side+"Arm",side+"ForeArm",side+"Hand"])
		_add_chain(authored,["Hips",side+"UpLeg",side+"Leg",side+"Foot",side+"ToeBase"])
		for finger in ["Thumb","Index","Middle","Ring","Pinky"]:
			_add_chain(authored,[side+"Hand",side+"Hand"+finger+"1",side+"Hand"+finger+"2",side+"Hand"+finger+"3"])
	for column in 5: _add_chain(authored,["Hips","Cape_%d_0"%column,"Cape_%d_1"%column,"Cape_%d_2"%column])
	assert(authored.get_bone_count() == 68)
	profile = Profile.identify(authored)
	assert(profile.get("id") == Profile.V31_ID and not profile.get("legacy_clips"))
	_check_heading(profile)
	assert(profile.local_forward == Vector3.BACK and profile.yaw_offset == 0.0)
	# This is the measured physical +Z facing; the algebra test alone cannot prove asset facing.
	for name in ["Hips","LeftUpLeg","RightShoulder","LeftHandIndex1","RightHandPinky3"]:
		var bone_index := authored.find_bone(name)
		var correct_parent := authored.get_bone_parent(bone_index)
		authored.set_bone_parent(bone_index,authored.find_bone("Head"))
		assert(Profile.identify(authored).is_empty(),"Malformed ancestry must fail: "+name)
		authored.set_bone_parent(bone_index,correct_parent)
	_check_clip_isolation(authored)
	# A cape parented to a leg must not pass as this authored production rig.
	authored.set_bone_parent(authored.find_bone("Cape_0_0"),authored.find_bone("LeftUpLeg"))
	assert(Profile.identify(authored).is_empty())
	authored.free()
	var unknown := Skeleton3D.new()
	unknown.add_bone("Hips")
	assert(Profile.identify(unknown).is_empty() and Profile.bone(unknown,"head").is_empty())
	unknown.free()
	print("PASS rig profiles: current source identity preserved, V31 parent chains, four world headings, independent cape ancestry, unknown-rig rejection")
	quit(0)

func _add_chain(skeleton: Skeleton3D, names: Array) -> void:
	var previous := -1
	for name in names:
		var index := skeleton.find_bone(name)
		if index < 0:
			skeleton.add_bone(name)
			index = skeleton.find_bone(name)
			if previous >= 0: skeleton.set_bone_parent(index,previous)
		previous = index

func _check_heading(profile: Dictionary) -> void:
	for direction in [Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.RIGHT]:
		var yaw := atan2(direction.x,direction.z)+float(profile.yaw_offset)
		var actual: Vector3 = Basis(Vector3.UP,yaw)*profile.local_forward
		assert(actual.dot(direction)>0.99999,"A model replacement must preserve movement facing in all four headings")

func _check_clip_isolation(skeleton: Skeleton3D) -> void:
	var host := Node3D.new()
	host.add_child(skeleton)
	var player := AnimationPlayer.new()
	host.add_child(player)
	var library := AnimationLibrary.new()
	var authored := Animation.new()
	var track := authored.add_track(Animation.TYPE_ROTATION_3D)
	authored.track_set_path(track,NodePath("Skeleton3D:Head"))
	authored.track_insert_key(track,0.0,Quaternion.IDENTITY)
	authored.track_insert_key(track,0.5,Quaternion(Vector3.UP,0.2))
	library.add_animation("IDLE",authored)
	player.add_animation_library("",library)
	preload("res://scripts/player/mixamo_animation_bridge.gd").inject_animations(player)
	assert(player.get_animation_list() == PackedStringArray(["IDLE"]),"A 68-bone target must not receive legacy traversal clips")
	assert(player.get_animation("IDLE") == authored and authored.track_get_key_count(0) == 2)
	assert(authored.track_get_key_value(0,1).is_equal_approx(Quaternion(Vector3.UP,0.2)),"Original target rotation keys must survive bridge rejection")
	host.remove_child(skeleton)
	host.free()
