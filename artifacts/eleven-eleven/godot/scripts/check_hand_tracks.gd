extends SceneTree

func _init() -> void:
	var player_scene = load("res://scenes/player/echo_player.tscn")
	var player = player_scene.instantiate()
	root.add_child(player)
	await create_timer(0.05).timeout
	
	var anim_player = player.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player:
		var lib_names = anim_player.get_animation_library_list()
		print("Libraries: ", lib_names)
		for anim_name in anim_player.get_animation_list():
			var anim = anim_player.get_animation(anim_name)
			var has_hand_track = false
			for track_idx in range(anim.get_track_count()):
				var path = str(anim.track_get_path(track_idx))
				if "tripo__0_Right_Limb_2" in path or "Right_Limb_2" in path or "RightHand" in path:
					has_hand_track = true
					break
			print("Anim: ", anim_name, " | Hand Track Present: ", has_hand_track)
	quit(0)
