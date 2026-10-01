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


func _ready() -> void:
	_build_body()


func _build_body() -> void:
	visual = Node3D.new()
	visual.name = "EchoPrototypeVisual"
	visual.rotation.y = PI
	add_child(visual)
	var authored_scene := load("res://assets/echo-g0-motion-study.glb") as PackedScene
	if authored_scene:
		var authored_instance := authored_scene.instantiate()
		authored_instance.name = "EchoVRoidPrototype"
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

	var direction := Vector3(input.x, 0.0, input.y)
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	var target_speed := sprint_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed
	var target_velocity := direction * target_speed
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1

	move_and_slide()
	global_position.x = clamp(global_position.x, -6.6, 6.6)
	global_position.z = clamp(global_position.z, -6.6, 6.6)
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
		camera.look_at(global_position + Vector3(0.0, 1.45, 0.0), Vector3.UP)
