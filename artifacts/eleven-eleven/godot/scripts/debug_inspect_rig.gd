extends SceneTree

func _init() -> void:
	var player_scene = load("res://scenes/player/echo_player.tscn")
	if not player_scene:
		print("Failed to load player scene")
		quit(1)
		return
	var player = player_scene.instantiate()
	root.add_child(player)
	
	print("--- SKELETON INSPECTION ---")
	var skel = player.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel:
		print("Skeleton found: ", skel.get_path())
		print("Bone count: ", skel.get_bone_count())
		for i in range(skel.get_bone_count()):
			var bname = skel.get_bone_name(i)
			if "hand" in bname.to_lower() or "arm" in bname.to_lower() or "right" in bname.to_lower() or "spine" in bname.to_lower() or "pelvis" in bname.to_lower() or "hip" in bname.to_lower() or "limb" in bname.to_lower():
				print("Bone [", i, "]: ", bname, " rest: ", skel.get_bone_rest(i))
	else:
		print("No Skeleton3D found!")

	print("--- CHILDREN OF ECHOPLAYER ---")
	_print_tree(player, "  ")

	quit(0)

func _print_tree(n: Node, prefix: String) -> void:
	print(prefix, n.name, " (", n.get_class(), ") visible=", n.get("visible") if "visible" in n else "N/A", " transform=", n.get("transform") if "transform" in n else "")
	for c in n.get_children():
		_print_tree(c, prefix + "  ")
