extends SceneTree

func _init() -> void:
	var glb = load("res://assets/characters/echo_opening_uniform_v13.glb")
	if not glb:
		print("glb not found")
		quit(1)
		return
	var inst = glb.instantiate()
	var skel = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	if not skel:
		for child in inst.get_children():
			if child is Skeleton3D:
				skel = child
				break
	if skel:
		print("Bone count: ", skel.get_bone_count())
		for i in range(skel.get_bone_count()):
			print("Bone ", i, ": ", skel.get_bone_name(i))
	else:
		print("No Skeleton3D found in model root")
	quit(0)
