extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	for path in ["res://assets/animations/golden/run-motion.glb", "res://assets/characters/echo_opening_uniform_v13.glb"]:
		var inst := (load(path) as PackedScene).instantiate()
		root.add_child(inst)
		var skel := inst.find_child("Skeleton3D", true, false) as Skeleton3D
		var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		print("RIG ", path, " transform=", skel.global_transform)
		for mesh in inst.find_children("*", "MeshInstance3D", true, false):
			print("MESH ", mesh.name, " aabb=", mesh.global_transform * mesh.get_aabb())
		for i in skel.get_bone_count():
			print(i, " ", skel.get_bone_name(i), " parent=", skel.get_bone_parent(i), " rest=", skel.get_bone_global_rest(i))
		for name in ap.get_animation_list():
			var anim := ap.get_animation(name)
			print("CLIP ", name, " length=", anim.length)
			if name.to_lower().contains("run"):
				for t in anim.get_track_count():
					print("TRACK ", anim.track_get_path(t), " type=", anim.track_get_type(t), " first=", anim.track_get_key_value(t, 0))
		inst.free()
	quit()
