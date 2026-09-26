extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var f := FileAccess.open("user://anim_list.txt", FileAccess.WRITE)
	if not f:
		print("Cannot open file")
		quit(1)
		return
	
	var player_scene := load("res://scenes/player/echo_player.tscn") as PackedScene
	if player_scene:
		var p := player_scene.instantiate()
		var ap := p.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			f.store_line("ANIMATIONS_IN_ECHO_PLAYER:")
			for a in ap.get_animation_list():
				var anim := ap.get_animation(a)
				f.store_line(a + " | length: " + str(anim.length) + " | tracks: " + str(anim.get_track_count()))
		else:
			f.store_line("NO_ANIMATION_PLAYER_IN_ECHO_PLAYER")
		p.free()
	else:
		f.store_line("FAILED_TO_LOAD_ECHO_PLAYER")
	
	f.close()
	quit(0)
