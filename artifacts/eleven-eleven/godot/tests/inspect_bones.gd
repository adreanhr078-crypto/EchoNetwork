extends SceneTree

func _init() -> void:
	var inst = load("res://scenes/player/echo_player.tscn").instantiate()
	var anim: AnimationPlayer = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim:
		print("Animations: ", anim.get_animation_list())
	var skel: Skeleton3D = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel:
		var bone_names: Array = []
		for i in range(skel.get_bone_count()):
			bone_names.append(str(i) + ":" + skel.get_bone_name(i))
		print("Bones: ", bone_names)
	inst.free()
	quit(0)
