extends SceneTree
## Native clock/static tracks only; frozen optimizer/retarget/root profile retained.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Expected isolated candidate and measured Blender reference")
		quit(1)
		return
	var project := ProjectSettings.globalize_path("res://").replace("\\", "/")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	if not project.contains("/.tmp/echo-character-lab/cases/") or not data is Dictionary or data.get("status") != "PASS" or data.get("fps") != 24:
		push_error("Only measured24Hz source in the isolated character lab is supported")
		quit(1)
		return
	var config := ConfigFile.new()
	if config.load(args[0]+".import") != OK:
		quit(1)
		return
	var before: float = config.get_value("params", "animation/fps", 30)
	config.set_value("params", "animation/fps", int(data.fps))
	# Keep authored constant tracks too: a prior Idle must not leave its finger
	# pose on the supporting hand when Wake contains constant finger keys.
	config.set_value("params", "animation/remove_immutable_tracks", false)
	var result := config.save(args[0]+".import")
	print("NATIVE_IMPORT_CLOCK ", before, "->", int(data.fps), " result=", result)
	quit(0 if result == OK else 1)
