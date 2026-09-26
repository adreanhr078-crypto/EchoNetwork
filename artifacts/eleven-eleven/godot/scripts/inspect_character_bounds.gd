extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- INSPECTING CHARACTER BOUNDS ---")
	var scenes = {
		"Echo Player": "res://scenes/player/echo_player.tscn",
		"Echo GLB": "res://assets/characters/echo_opening_uniform_v13.glb",
		"Specimen EX000": "res://scenes/enemies/specimen_ex000.tscn",
		"Dr Kinga": "res://scenes/characters/dr_kinga.tscn"
	}
	for name in scenes:
		var sc = load(scenes[name]) as PackedScene
		if not sc:
			print("Could not load ", name)
			continue
		var inst = sc.instantiate()
		print("\n=== ", name, " ===")
		_print_meshes(inst, "")
		inst.free()
	quit(0)

func _print_meshes(node: Node, indent: String) -> void:
	if node is VisualInstance3D:
		var aabb = node.get_aabb()
		print(indent, node.name, " (", node.get_class(), "): pos=", node.position, " scale=", node.scale, " AABB=", aabb)
	for c in node.get_children():
		_print_meshes(c, indent + "  ")
