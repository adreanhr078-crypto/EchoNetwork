extends SceneTree

func _initialize() -> void:
	call_deferred("_inspect")

func _inspect() -> void:
	var player_scene := load("res://scenes/player/echo_player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	await process_frame
	var skeleton := player.find_child("Skeleton3D", true, false) as Skeleton3D
	print("PLAYER ", player.global_position, " ROOT ", player.get_node("ModelRoot").global_transform)
	print("SKELETON_TRANSFORM ", skeleton.global_transform)
	print("IK_CLASSES ", ClassDB.class_exists("FABRIK3D"), " ", ClassDB.class_exists("SkeletonIK3D"), " MODIFIER ", ClassDB.class_exists("SkeletonModifier3D"))
	var anim_player := player.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player:
		print("ANIMATION_PLAYER: ", anim_player.get_animation_list())
		for anim_name in anim_player.get_animation_list():
			var anim := anim_player.get_animation(anim_name)
			print("ANIM: ", anim_name, " len=", anim.length, " loop=", anim.loop_mode, " tracks=", anim.get_track_count())
	for index in range(skeleton.get_bone_count()):
		var name := skeleton.get_bone_name(index)
		var parent := skeleton.get_bone_parent(index)
		var rest := skeleton.get_bone_rest(index)
		var pose := skeleton.get_bone_global_pose(index)
		print("BONE ", index, " ", name, " PARENT ", parent, " REST ", rest.origin, " POSE ", pose.origin)
	quit()
