extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var lib = load("res://assets/animations/echo_parkour_v1.res") as AnimationLibrary
	print("OWN-RIG ACTIONS ",lib.get_animation_list())
	for path in ["res://assets/animations/Great_Sword_Slash.fbx","res://assets/characters/echo_opening_uniform_v13.glb"]:
		var inst = load(path).instantiate()
		root.add_child(inst)
		var skel = inst.find_child("Skeleton3D",true,false) as Skeleton3D
		var ap = inst.find_child("AnimationPlayer",true,false) as AnimationPlayer
		print("RIG ",path," clips=",ap.get_animation_list()," skeleton=",skel.transform)
		for i in skel.get_bone_count(): print(skel.get_bone_name(i)," rest_point=",skel.get_bone_global_rest(i).origin)
		for clip in ap.get_animation_list():
			var a = ap.get_animation(clip)
			print("CLIP ",clip," length=",a.length," tracks=",a.get_track_count())
			if clip == "preset_idle":
				for t in range(3): print("TRACK ",a.track_get_path(t)," type=",a.track_get_type(t)," value=",a.track_get_key_value(t,0))
		inst.free()
	var player = load("res://scenes/player/echo_player.tscn").instantiate()
	root.add_child(player)
	player.finish_opening_recovery()
	for i in range(5): await process_frame
	var s = player.find_child("Skeleton3D",true,false)
	print("PLAYER SKELETON TRANSFORM ",s.global_transform)
	for name in ["tripo__Root","tripo__1_Left_Limb_0","tripo__1_Left_Limb_3"]:
		var i = s.find_bone(name)
		print("PLAYER ",name," localrest=",s.get_bone_rest(i)," pose=",s.get_bone_pose(i)," world_pose=",s.global_transform*s.get_bone_global_pose(i))
	player.queue_free()
	await process_frame
	quit()
