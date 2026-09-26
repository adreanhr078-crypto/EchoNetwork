@tool
extends MainLoop

func _process(_delta: float) -> bool:
	var f = FileAccess.open("C:/Users/yasmo/EchoNetwork/fbx_out.txt", FileAccess.WRITE)
	if not f:
		return true
	var path = "res://assets/animations/Flip Kick.fbx"
	var scene = load(path)
	if scene:
		var node = scene.instantiate()
		var ap = node.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			f.store_line("Found AnimationPlayer:")
			for a in ap.get_animation_list():
				var anim = ap.get_animation(a)
				f.store_line("Anim: " + a + " tracks=" + str(anim.get_track_count()))
				for i in range(mini(15, anim.get_track_count())):
					f.store_line("  track " + str(i) + ": " + str(anim.track_get_path(i)))
		else:
			f.store_line("No AnimationPlayer in " + path)
		node.free()
	else:
		f.store_line("Failed to load " + path)
	f.close()
	return true
