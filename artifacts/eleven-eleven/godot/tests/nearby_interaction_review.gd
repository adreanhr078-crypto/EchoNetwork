extends "res://tests/opening_player_journey_review.gd"
## Regression for the prompt and activation disagreeing inside overlapping areas.

func _capture(id: String) -> void:
	if id == "overlap-target-b":
		await super._capture(id)

func _before_room_exit() -> bool:
	var prompt := main.hud.find_child("InteractionPromptHUD", true, false) as InteractionPromptHUD
	var touch = main.hud.find_child("MobileTouchControls", true, false)
	var use_button := touch.use_btn as Button
	var activations: Array[String] = []
	var left := _add_target("Target A", Vector3(-0.75, 0.6, -12.0), activations)
	var right := _add_target("Target B", Vector3(0.75, 0.6, -12.0), activations)
	if not await _walk(Vector3(-0.75, 0, -12.0)): return false
	if not _check(left.current_interactor == player and right.current_interactor == player, "Fixture needs two overlapping public interactables"): return false
	if not _check(prompt.current_interactable == left and touch._interaction_available, "First target did not advertise input"): return false
	if not await _walk(Vector3(0.75, 0, -12.0)): return false
	if not _check(left.current_interactor == player and right.current_interactor == player, "Target changed because an area exited"): return false
	if not _check(prompt.current_interactable == right and prompt.prompt_label.text.contains("Target B"), "HUD target stayed stale inside overlapping areas"): return false
	await _capture("overlap-target-b")

	player.set_process_unhandled_input(true)
	await _press_interact()
	if not _check(activations == ["Target B"], "First interact key did not activate the advertised target"): return false
	player.control_locked = true
	await _frames(3)
	if not _check(prompt.current_interactable == null and not touch._interaction_available, "Interaction stayed advertised while gameplay input was locked"): return false
	await _press_interact()
	if not _check(activations.size() == 1, "Locked input activated an interactable"): return false
	player.control_locked = false
	await _frames(3)
	if not _check(prompt.current_interactable == right and touch._interaction_available, "Unlock did not restore the advertised target"): return false
	right.is_enabled = false
	if not _check(prompt.current_interactable == left, "Disabled device did not yield its prompt immediately"): return false
	use_button.pressed.emit()
	if not _check(activations == ["Target B", "Target A"], "Touch activation did not use the current advertised target"): return false
	left.is_enabled = false
	if not _check(prompt.current_interactable == null and not touch._interaction_available, "No eligible targets left an active prompt"): return false
	player.set_process_unhandled_input(false)

	var report := FileAccess.open(folder.path_join("interaction-focus.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({
		"status": "PASS_NATIVE_OVERLAPPING_INTERACTION",
		"keyboard_and_touch_activations": activations,
		"display": DisplayServer.get_name(),
		"source_hashes": {
			"player": FileAccess.get_sha256("res://scripts/player/echo_player.gd"),
			"hud": FileAccess.get_sha256("res://scripts/ui/interaction_prompt_hud.gd"),
			"fixture": FileAccess.get_sha256(get_script().resource_path)
		}
	}, "\t") + "\n")
	report.close()
	left.queue_free()
	right.queue_free()
	return true

func _add_target(label: String, position: Vector3, activations: Array[String]) -> InteractableComponent:
	var target := InteractableComponent.new()
	target.position = position
	target.prompt_target_name = label
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.2
	collision.shape = sphere
	target.add_child(collision)
	target.interaction_requested.connect(func(_interactor: Node3D): activations.append(label))
	main.add_child(target)
	return target

func _press_interact() -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = "interact"
		event.pressed = pressed
		event.strength = 1.0 if pressed else 0.0
		root.push_input(event, true)
		await process_frame
