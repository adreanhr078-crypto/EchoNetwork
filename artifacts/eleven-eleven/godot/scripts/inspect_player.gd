extends SceneTree

func _init() -> void:
	var f = FileAccess.open("res://inspect_output.txt", FileAccess.WRITE)
	var player_scene = load("res://scenes/player/echo_player.tscn")
	if not player_scene:
		f.store_line("FAILED to load echo_player.tscn")
		f.close()
		quit(1)
		return
	var player = player_scene.instantiate()
	var anim_player = player.find_child("AnimationPlayer", true, false)
	if anim_player:
		f.store_line("AnimationPlayer found: " + str(anim_player.get_path()))
		var anims = anim_player.get_animation_list()
		f.store_line("Total animations: " + str(anims.size()))
		for a in anims:
			f.store_line(" - " + str(a))
	else:
		f.store_line("No AnimationPlayer found in echo_player.tscn")

	var model_root = player.find_child("ModelRoot", true, false)
	if model_root:
		f.store_line("ModelRoot found. Children:")
		_dump_children(model_root, "  ", f)
	f.close()
	quit(0)

func _dump_children(node: Node, indent: String, f: FileAccess) -> void:
	for c in node.get_children():
		var extra = ""
		if c is MeshInstance3D:
			var mat = c.get_active_material(0)
			extra = " [Mesh: " + str(c.mesh.get_class() if c.mesh else "none") + ", Mat: " + str(mat.get_class() if mat else "none") + "]"
		f.store_line(indent + c.name + " (" + c.get_class() + ")" + extra)
		_dump_children(c, indent + "  ", f)

func _print_children(node: Node, indent: String) -> void:
	for c in node.get_children():
		var extra = ""
		if c is MeshInstance3D:
			var mat = c.get_active_material(0)
			extra = " [Mesh: " + str(c.mesh.get_class() if c.mesh else "none") + ", Mat: " + str(mat.get_class() if mat else "none") + "]"
		print(indent, c.name, " (", c.get_class(), ")", extra)
		_print_children(c, indent + "  ")
