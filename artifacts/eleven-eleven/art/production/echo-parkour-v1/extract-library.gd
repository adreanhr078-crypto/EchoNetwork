extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Expected absolute source GLB and output animation library paths")
		quit(1)
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(args[0], state)
	if error != OK:
		push_error("Cannot import authored traversal clips")
		quit(1)
		return
	var scene := document.generate_scene(state)
	var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var library := AnimationLibrary.new()
	for name in player.get_animation_list():
		if not String(name).begins_with("PARKOUR_"): continue
		var animation := player.get_animation(name).duplicate(true) as Animation
		animation.loop_mode = Animation.LOOP_NONE if name == "PARKOUR_MANTLE" else Animation.LOOP_LINEAR
		library.add_animation(name, animation)
		print(name, " tracks=", animation.get_track_count(), " length=", animation.length)
	if library.get_animation_list().size() != 3:
		push_error("Expected the three authored traversal clips")
		quit(1)
		return
	var saved := ResourceSaver.save(library, args[1])
	scene.free()
	quit(0 if saved == OK else 1)
