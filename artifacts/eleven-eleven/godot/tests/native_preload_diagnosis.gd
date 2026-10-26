extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	const PATH:="res://scenes/native_journey.tscn"
	var resource:PackedScene
	if OS.get_cmdline_user_args().has("--threaded"):
		ResourceLoader.load_threaded_request(PATH)
		while ResourceLoader.load_threaded_get_status(PATH)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:await process_frame
		resource=ResourceLoader.load_threaded_get(PATH)
	else:resource=load(PATH)
	print("PRELOAD_ONLY ",resource!=null," threaded=",OS.get_cmdline_user_args().has("--threaded"))
	resource=null
	for i in 8:await process_frame
	quit(0)
