extends SceneTree

func _init() -> void:
	var player_scene = load("res://scenes/player/echo_player.tscn")
	var player = player_scene.instantiate()
	root.add_child(player)
	
	await create_timer(0.05).timeout
	var anim_player = player.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var socket = player.find_child("RightHandWeaponSocket", true, false) as Node3D
	var katana = player.find_child("KatanaBlade", true, false) as Node3D
	
	print("AnimPlayer: ", anim_player != null)
	print("Socket: ", socket != null)
	
	if anim_player and socket:
		print("Initial Socket global pos: ", socket.global_position)
		var anims = anim_player.get_animation_list()
		var run_anim = ""
		for a in anims:
			if "walk" in a.to_lower() or "run" in a.to_lower() or "attack" in a.to_lower() or "slash" in a.to_lower():
				run_anim = a
				break
		print("Playing anim: ", run_anim)
		if run_anim != "":
			anim_player.play(run_anim)
			for step in range(5):
				await create_timer(0.1).timeout
				print("Step ", step, " - Socket pos: ", socket.global_position, " Katana pos: ", katana.global_position if katana else "none")
	
	quit(0)
