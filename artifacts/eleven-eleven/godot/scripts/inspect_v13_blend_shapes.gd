extends SceneTree

func _init() -> void:
	print("--- INSPECTING V13 BLEND SHAPES IN GODOT ---")
	var scene = load("res://assets/characters/echo_opening_uniform_v13.glb")
	if not scene:
		printerr("FAILED to load v13 glb")
		quit(1)
		return
	var inst = scene.instantiate()
	print("Instantiated: ", inst.name)
	_dump(inst, "")
	quit(0)

func _dump(node: Node, indent: String) -> void:
	print(indent, "- ", node.name, " (", node.get_class(), ")")
	if node is MeshInstance3D and node.mesh:
		var count = node.mesh.get_blend_shape_count()
		print(indent, "  [MESH] blend shapes count: ", count)
		for i in range(count):
			print(indent, "    #", i, ": ", node.mesh.get_blend_shape_name(i))
	if node is AnimationPlayer:
		print(indent, "  [ANIMATION_PLAYER] Animations:")
		for anim_name in node.get_animation_list():
			var anim = node.get_animation(anim_name)
			print(indent, "    - ", anim_name, " (len: ", anim.length, "s, loop: ", anim.loop_mode, ")")
	for c in node.get_children():
		_dump(c, indent + "  ")
