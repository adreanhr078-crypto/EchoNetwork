@tool
extends SceneTree

func _initialize() -> void:
	var f = FileAccess.open("C:/Users/yasmo/EchoNetwork/artifacts/eleven-eleven/godot/anim_debug.txt", FileAccess.WRITE)
	var scene = load("res://assets/characters/echo_opening_uniform_v13.glb")
	if scene:
		var inst = scene.instantiate()
		var ap = inst.find_child("AnimationPlayer", true, false)
		if ap:
			f.store_line("Found AnimationPlayer in v13 glb:")
			for a in ap.get_animation_list():
				var anim = ap.get_animation(a)
				f.store_line("  - " + a + " (length: " + str(anim.length) + ", loop: " + str(anim.loop_mode) + ")")
		else:
			f.store_line("No AnimationPlayer in v13 glb")
	else:
		f.store_line("Failed to load v13 glb")
	f.close()
	quit(0)
