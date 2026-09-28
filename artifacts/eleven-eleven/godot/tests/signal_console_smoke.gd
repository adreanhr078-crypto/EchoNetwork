extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for reduced in [false, true]:
		var terminal: Node3D = load("res://scenes/environment/substation_terminal.tscn").instantiate()
		root.add_child(terminal)
		await process_frame
		terminal.set_reduced_motion(reduced)
		var key := terminal.find_child("EchoSignalConsole_AcknowledgmentKey", true, false) as Node3D
		var animation := terminal.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if not _check(key != null and animation != null and animation.has_animation("Console_Acknowledge"), "portable confirmation animation missing"): return
		if not _check(not animation.is_playing(), "console animation starts before interaction"): return
		var rest := key.position
		terminal.complete_hack()
		if not _check(terminal.is_hacked and not terminal.get_node("InteractionArea").is_enabled, "presentation changed terminal completion contract"): return
		if not _check(animation.is_playing() != reduced, "confirmation ignored reduced motion preference"): return
		if not reduced:
			animation.seek(0.17, true)
			animation.advance(0.0)
			var travel := rest.distance_to(key.position)
			if not _check(travel > 0.007 and travel < 0.015, "portable button motion was lost or distorted"): return
			animation.seek(animation.current_animation_length, true)
			animation.advance(0.0)
			if not _check(key.position.distance_to(rest) < 0.00001, "button final pose does not return to rest"): return
			terminal.set_reduced_motion(true)
			if not _check(not animation.is_playing() and key.position.distance_to(rest) < 0.00001, "switching reduced motion failed to reset confirmation"): return
		terminal.set_presentation_language("en")
		if not _check(terminal.get_node("ScreenReadout").text.contains("SIGNAL ALIGNED"), "live English readout lost"): return
		terminal.set_presentation_language("ar")
		if not _check(terminal.get_node("ScreenReadout").text.contains("الإشارة مستقرة"), "live Arabic readout lost"): return
		if not _check(terminal.has_node("TerminalCollider/ConsoleCollision"), "console collision disappeared"): return
		terminal.queue_free()
		await process_frame
	print("PASS console: portable motion, rest/peak/final poses, reduced motion, completion, collision, live AR/EN")
	quit(0)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
