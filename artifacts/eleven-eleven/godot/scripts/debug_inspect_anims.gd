extends SceneTree

func _init() -> void:
	var player_scene = load("res://scenes/player/echo_player.tscn")
	var player = player_scene.instantiate()
	root.add_child(player)
	
	var anim_player = player.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player:
		print("AnimationPlayer found: ", anim_player.get_path())
		for lib_name in anim_player.get_animation_library_list():
			var lib = anim_player.get_animation_library(lib_name)
			print("Library: '", lib_name, "'")
			for anim_name in lib.get_animation_list():
				print("  Anim: ", anim_name, " len: ", lib.get_animation(anim_name).length)
	else:
		print("AnimationPlayer not found")

	quit(0)
