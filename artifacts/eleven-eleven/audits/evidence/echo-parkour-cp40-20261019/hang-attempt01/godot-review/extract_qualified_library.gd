extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var gate:Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if gate.get("status") != "PASS" or gate.get("sample_count") != 29:
		push_error("1972-joint source gate must pass before library extraction")
		quit(1)
		return
	var model:Node = load("res://single-motion.glb").instantiate()
	var mixer := model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	var clip:Animation = mixer.get_animation("Hang_Source_Retarget")
	var library := AnimationLibrary.new()
	library.add_animation("Hang_Source_Retarget",clip.duplicate(true))
	var error := ResourceSaver.save(library,args[1])
	print("QUALIFIED_HANG_LIBRARY result=",error," tracks=",clip.get_track_count()," length=",clip.length)
	model.free()
	quit(0 if error==OK else 1)
