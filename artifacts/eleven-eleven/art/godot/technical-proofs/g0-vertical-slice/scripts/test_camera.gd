extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var player = load("res://scripts/player.gd").new()
	world.add_child(player)
	player.set_physics_process(false)
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 8.0, 0.2)
	collision.shape = box
	wall.add_child(collision)
	wall.position = Vector3(0.0, 2.0, 1.5)
	world.add_child(wall)
	await physics_frame
	await physics_frame
	player._update_camera(1.0 / 60.0)
	_check(player.camera.global_position.z < 1.23, "Camera clipped through rear wall")
	_check(player.camera.global_position.z > 0.8, "Camera retracted unnecessarily far")
	# Rotate the obstruction and orbit together to cover all four directions.
	for angle in [PI / 2.0, PI, -PI / 2.0]:
		wall.position = Vector3(0, 2, 1.5).rotated(Vector3.UP, angle)
		wall.rotation.y = angle
		player.camera_yaw = angle
		await physics_frame
		await physics_frame
		player._update_camera(0.016)
		var local_camera: Vector3 = player.camera.global_position.rotated(Vector3.UP, -angle)
		_check(local_camera.z < 1.23, "Camera clipped at orbit angle " + str(angle))
	wall.position.y = 100.0
	await physics_frame
	await physics_frame
	for i in range(120):
		player._update_camera(1.0 / 60.0)
	var pivot: Vector3 = player.global_position + Vector3(0, 1.45, 0)
	_check(player.camera.global_position.distance_to(pivot) > 2.6, "Camera failed to return after obstruction cleared")
	player.camera_yaw = PI / 2.0
	_check(player.movement_direction(Vector2(0, -1)).is_equal_approx(Vector3.LEFT), "Forward movement did not follow camera yaw")
	_check(is_equal_approx(player.movement_direction(Vector2(1, 1)).length(), 1.0), "Diagonal speed boost")
	player.reset_camera()
	_check(is_zero_approx(player.camera_yaw), "Reset retained orbit angle")
	_check(player.authored_animation != null, "Animated Echo missing")
	world.queue_free()
	await process_frame
	print("G0_CAMERA_TEST_PASS" if failures.is_empty() else "G0_CAMERA_TEST_FAIL")
	quit(0 if failures.is_empty() else 1)
