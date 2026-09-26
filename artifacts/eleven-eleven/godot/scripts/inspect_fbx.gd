@tool
extends SceneTree

func _initialize() -> void:
	call_deferred("_inspect")

func _inspect() -> void:
	var f = FileAccess.open("user://fbx_tracks.txt", FileAccess.WRITE)
	var scene = load("res://assets/animations/Flip Kick.fbx")
	if scene:
		var inst = scene.instantiate()
		var ap = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			f.store_line("FOUND AnimationPlayer in Flip Kick:")
			for a in ap.get_animation_list():
				var anim = ap.get_animation(a)
				f.store_line("ANIM: " + a + " tracks=" + str(anim.get_track_count()))
				for i in range(mini(10, anim.get_track_count())):
					f.store_line("  track " + str(i) + ": " + str(anim.track_get_path(i)))
		else:
			f.store_line("NO AnimationPlayer in Flip Kick")
		inst.free()
	else:
		f.store_line("FAILED to load Flip Kick.fbx")
	f.close()
	quit(0)
