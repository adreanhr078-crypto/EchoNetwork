extends CharacterBody3D

signal movement_sampled(speed: float)

@export var walk_speed := 3.4
@export var sprint_speed := 5.2
@export var acceleration := 18.0
@export var gravity := 18.0

var camera: Camera3D
var visual: Node3D
var authored_animation: AnimationPlayer
var using_authored_character := false
var _bob_time := 0.0
var camera_yaw := 0.0
var camera_pitch := 0.29
var _camera_distance := 2.65
var _camera_shape := SphereShape3D.new()
var _orbiting := false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_orbiting = event.pressed
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _orbiting else Input.MOUSE_MODE_VISIBLE
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_release_camera()
	if event is InputEventMouseMotion and _orbiting:
		camera_yaw -= event.relative.x * 0.003
		camera_pitch = clampf(camera_pitch + event.relative.y * 0.003, -0.25, 0.85)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_camera()


func _release_camera() -> void:
	_orbiting = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func reset_camera() -> void:
	_release_camera()
	camera_yaw = 0.0
	camera_pitch = 0.29
	_camera_distance = 2.65


func movement_direction(input_axis: Vector2) -> Vector3:
	return Vector3(input_axis.x, 0.0, input_axis.y).limit_length(1.0).rotated(Vector3.UP, camera_yaw)


func _update_camera(delta: float) -> void:
	var pivot := global_position + Vector3(0.0, 1.45, 0.0)
	var offset := Vector3(0.55, sin(camera_pitch) * 2.65, cos(camera_pitch) * 2.65).rotated(Vector3.UP, camera_yaw)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _camera_shape
	query.transform = Transform3D(Basis.IDENTITY, pivot)
	query.motion = offset
	query.exclude = [get_rid()]
	query.collision_mask = collision_mask
	var fractions := get_world_3d().direct_space_state.cast_motion(query)
	var safe_distance := maxf(0.01, offset.length() * fractions[0] - 0.04)
	# Retract immediately; only the return to full distance is smoothed.
	_camera_distance = minf(safe_distance, move_toward(_camera_distance, safe_distance, delta * 4.0))
	camera.global_position = pivot + offset.normalized() * _camera_distance
	camera.look_at(pivot, Vector3.UP)


func _ready() -> void:
	_build_body()


func _build_body() -> void:
	visual = Node3D.new()
	visual.name = "EchoMotionProxyVisual"
	visual.rotation.y = PI
	add_child(visual)
	var authored_scene := load("res://assets/echo-g0-motion-study.glb") as PackedScene
	if authored_scene:
		var authored_instance := authored_scene.instantiate()
		authored_instance.name = "EchoMotionProxy_NotCanon"
		authored_instance.scale = Vector3.ONE
		authored_instance.position.y = 0.0
		visual.add_child(authored_instance)
		authored_animation = _find_animation_player(authored_instance)
		if authored_animation:
			for clip in ["IDLE", "WALK", "RUN"]:
				if authored_animation.has_animation(clip):
					authored_animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		using_authored_character = true
		_play_authored_animation("IDLE")
	else:
		_build_fallback_body(visual)

	var collision := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.38
	capsule_shape.height = 1.8
	collision.shape = capsule_shape
	collision.position.y = 0.9
	collision.name = "PlayerCollision"
	add_child(collision)

	camera = Camera3D.new()
	_camera_shape.radius = 0.18
	camera.name = "ThirdPersonCamera"
	camera.position = Vector3(0.55, 2.2, 2.5)
	camera.fov = 58.0
	camera.near = 0.05
	camera.far = 80.0
	camera.current = true
	add_child(camera)

	var fill := OmniLight3D.new()
	fill.name = "PlayerFill"
	fill.light_color = Color("#6c8dff")
	fill.light_energy = 0.45
	fill.omni_range = 4.0
	fill.position = Vector3(0.0, 1.6, 0.2)
	add_child(fill)


func _build_fallback_body(parent: Node3D) -> void:
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color("#d7e4ff")
	body_material.metallic = 0.18
	body_material.roughness = 0.32

	var capsule := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.38
	capsule_mesh.height = 1.8
	capsule.material_override = body_material
	capsule.mesh = capsule_mesh
	capsule.position.y = 0.9
	capsule.name = "PrototypeBody"

	var mark := MeshInstance3D.new()
	var mark_mesh := BoxMesh.new()
	mark_mesh.size = Vector3(0.12, 0.12, 0.035)
	var mark_material := StandardMaterial3D.new()
	mark_material.albedo_color = Color("#f34c78")
	mark_material.emission_enabled = true
	mark_material.emission = Color("#e81855")
	mark_material.emission_energy_multiplier = 2.4
	mark.material_override = mark_material
	mark.mesh = mark_mesh
	mark.position = Vector3(0.0, 1.12, -0.39)
	mark.name = "EX011PrototypeMark"
	parent.add_child(capsule)
	parent.add_child(mark)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result:
			return result
	return null


func _play_authored_animation(clip: String) -> void:
	if authored_animation and authored_animation.has_animation(clip):
		if authored_animation.current_animation != clip:
			authored_animation.play(clip, 0.18)


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input.y += 1.0

	var direction := movement_direction(input)
	var target_speed := sprint_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed
	var target_velocity := direction * target_speed
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1

	move_and_slide()
	global_position.x = clamp(global_position.x, -5.35, 5.35)
	global_position.z = clamp(global_position.z, -11.2, 11.2)
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	movement_sampled.emit(planar_speed)
	if using_authored_character:
		var clip := "RUN" if Input.is_key_pressed(KEY_SHIFT) and planar_speed > 0.2 else ("WALK" if planar_speed > 0.2 else "IDLE")
		_play_authored_animation(clip)
	_bob_time += delta * (5.0 if planar_speed > 0.2 else 1.5)
	if visual:
		visual.position.y = 0.0 if using_authored_character else sin(_bob_time) * (0.035 if planar_speed > 0.2 else 0.012)
		if planar_speed > 0.15:
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), delta * 8.0)
	if camera:
		_update_camera(delta)
