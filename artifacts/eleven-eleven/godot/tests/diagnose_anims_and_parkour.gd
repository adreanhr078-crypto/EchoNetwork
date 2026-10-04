extends SceneTree

func _init() -> void:
	print("--- DIAGNOSE ANIMATIONS & PARKOUR ---")
	var player_scene = load("res://scenes/player/echo_player.tscn")
	var player = player_scene.instantiate()
	var root = Node3D.new()
	root.add_child(player)
	
	var ap: AnimationPlayer = player.find_child("AnimationPlayer", true, false)
	if ap:
		print("AnimationPlayer found! Animations in player:")
		for anim in ap.get_animation_list():
			print("  - ", anim)
	else:
		print("NO AnimationPlayer found on player!")
		
	print("\n--- DIAGNOSE OPENING ROOM INTERACTION & OBJECTIVES ---")
	var opening_scene = load("res://scenes/opening_native_room.tscn")
	var opening = opening_scene.instantiate()
	root.add_child(opening)
	
	var interactables = opening.find_children("", "Area3D", true, false)
	print("Interactable Area3D objects in opening room: ", interactables.size())
	for a in interactables:
		print("  Area: ", a.name, " parent: ", a.get_parent().name, " collision_layer: ", a.collision_layer, " collision_mask: ", a.collision_mask)
		
	var evidences = opening.find_children("", "", true, false)
	for e in evidences:
		if e.get_script() and "opening_evidence" in e.get_script().resource_path:
			print("  Evidence node: ", e.name, " path: ", e.get_path(), " active: ", e.is_inside_tree())
			
	print("\n--- DIAGNOSE TRAVERSAL / PARKOUR ---")
	print("Player surface_traversal_enabled: ", player.surface_traversal_enabled)
	print("Player traversal: ", player.traversal)
	if player.traversal:
		print("Traversal script: ", player.traversal.get_script().resource_path)
		
	player.free()
	opening.free()
	root.free()
	quit()
