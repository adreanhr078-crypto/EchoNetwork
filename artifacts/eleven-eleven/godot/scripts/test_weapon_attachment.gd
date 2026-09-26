extends SceneTree

func _init() -> void:
	var player_scene = load("res://scenes/player/echo_player.tscn")
	var player = player_scene.instantiate()
	root.add_child(player)
	
	print("Player added to tree")
	# Process one frame so deferred calls run
	await create_timer(0.1).timeout
	
	var skeleton = player.find_child("Skeleton3D", true, false) as Skeleton3D
	print("Skeleton found: ", skeleton != null)
	if skeleton:
		print("Bone count: ", skeleton.get_bone_count())
		var bone_idx = skeleton.find_bone("tripo__0_Right_Limb_2")
		print("Hand bone tripo__0_Right_Limb_2 idx: ", bone_idx)
		var socket = skeleton.get_node_or_null("RightHandWeaponSocket")
		print("RightHandWeaponSocket exists: ", socket != null)
		if socket:
			print("Socket parent: ", socket.get_parent().name)
			print("Socket children count: ", socket.get_child_count())
			for c in socket.get_children():
				print(" - Socket child: ", c.name, " (", c.get_class(), ")")
	
	var katana = player.find_child("KatanaBlade", true, false)
	if katana:
		print("KatanaBlade parent: ", katana.get_parent().name)
		print("KatanaBlade visible: ", katana.visible)
	
	var shadow_katana = player.find_child("ShadowKatana", true, false)
	if shadow_katana:
		print("ShadowKatana parent: ", shadow_katana.get_parent().name)
		print("ShadowKatana visible: ", shadow_katana.visible)
		
	# Now test equipping shadow katana
	print("--- Calling equip_shadow_katana() ---")
	player.equip_shadow_katana()
	if shadow_katana:
		print("After equip - ShadowKatana parent: ", shadow_katana.get_parent().name)
		print("After equip - ShadowKatana visible: ", shadow_katana.visible)
		
	quit(0)
