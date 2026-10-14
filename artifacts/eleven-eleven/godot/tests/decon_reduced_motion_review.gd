extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var room = load("res://scenes/environment/decontamination_quarantine_wing.tscn").instantiate()
	root.add_child(room)
	for unused in 15: await physics_frame
	var normal: float = room._uv_pulse_light.light_energy
	for unused in 15: await physics_frame
	if is_equal_approx(normal, room._uv_pulse_light.light_energy):
		push_error("Normal presentation should still have its clinical pulse")
		quit(1)
		return
	room.reduced_motion = true
	await physics_frame
	var steady: float = room._uv_pulse_light.light_energy
	var state: Dictionary = room.get_state()
	for unused in 90: await physics_frame
	if not is_equal_approx(steady, room._uv_pulse_light.light_energy) or state != room.get_state():
		push_error("Reduced Motion must stop the cosmetic pulse without changing quarantine state")
		quit(1)
		return
	room.queue_free()
	await process_frame
	print("PASS quarantine: live Reduced Motion stops cosmetic light pulse; room authority and gate state unchanged")
	quit(0)
