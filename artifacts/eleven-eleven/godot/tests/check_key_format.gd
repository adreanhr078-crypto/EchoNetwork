extends SceneTree

func _init() -> void:
	var glb_path := "res://assets/animations/golden/single-walk.glb"
	var packed = load(glb_path) as PackedScene
	if packed:
		var inst = packed.instantiate()
		var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var skel: Skeleton3D = inst.find_child("Skeleton3D", true, false) as Skeleton3D
		if ap and skel:
			var anim = ap.get_animation("Walk_Source_Retarget")
			var b_idx = skel.find_bone("mixamorig_LeftUpLeg")
			print("mixamorig_LeftUpLeg rest rot: ", skel.get_bone_rest(b_idx).basis.get_rotation_quaternion())
			for t in anim.get_track_count():
				if anim.track_get_path(t).get_concatenated_subnames() == "mixamorig_LeftUpLeg" and anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
					print("track key 0 rot: ", anim.track_get_key_value(t, 0))
					break
		inst.free()
	quit(0)
