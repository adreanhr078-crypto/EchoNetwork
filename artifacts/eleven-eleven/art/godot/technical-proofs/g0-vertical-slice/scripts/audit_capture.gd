extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--audit-output="):
			output = arg.trim_prefix("--audit-output=")
	if output.is_empty():
		push_error("Missing --audit-output absolute PNG path")
		quit(1)
		return
	var scene := load("res://main.tscn") as PackedScene
	root.add_child(scene.instantiate())
	for frame in range(90):
		await process_frame
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	var result := screenshot.save_png(output)
	print("G0_RENDER_CAPTURE_RESULT=", result)
	quit(0 if result == OK else 1)
