extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _window() -> Control:
	var window: Control = load("res://scenes/ui/system_window.tscn").instantiate()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): window.set_script(load(args[0]))
	root.add_child(window)
	return window

func _run() -> void:
	var window = _window()
	window.show_system_window(0,"Old","Old",[],0.05)
	window.show_system_window(0,"Current","Current",[],0.2)
	await create_timer(0.1).timeout
	if not window.visible:
		push_error("An obsolete notification timer closed the current notification")
		quit(1)
		return
	window.queue_free()
	await create_timer(0.3).timeout
	window = _window()
	window.show_system_window(0,"Auto close","Auto close",[],0.05)
	await create_timer(0.3).timeout
	if window.visible:
		push_error("Current notification did not close")
		quit(1)
		return
	window.queue_free()
	await process_frame
	print("PASS notification lifetime: obsolete timer ignored, active timer closes, receiver safely released")
	quit()
