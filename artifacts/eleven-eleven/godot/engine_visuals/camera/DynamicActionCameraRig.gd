class_name DynamicActionCameraRig
extends Node3D

## Analytic critically damped springs. External mode shares Echo's existing
## collision/orbit/cinematic ownership; standalone mode owns a SpringArm.
@export var base_fov := 70.0
@export var maximum_fov := 92.0
@export var maximum_bank_degrees := 3.5
@export var follow_frequency := 7.0
@export var arm_length := 3.0
var target: CharacterBody3D
var camera: Camera3D
var arm: SpringArm3D
var external := false
var reduced_motion := false
var lock_target: Node3D
var trauma := 0.0
var _phase := 0.0
var _follow := Vector3.ZERO
var _follow_velocity := Vector3.ZERO
var _compression := 0.0
var _compression_velocity := 0.0
var _punch := Vector3.ZERO
var _noise := FastNoiseLite.new()

func _ready() -> void:
	_noise.seed = 111148
	_noise.frequency = 1.0
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH

func configure(body: CharacterBody3D, existing_camera: Camera3D = null, existing_arm: SpringArm3D = null) -> void:
	target = body
	external = existing_camera != null and existing_arm != null
	if external:
		camera = existing_camera
		arm = existing_arm
	else:
		arm = SpringArm3D.new()
		arm.spring_length = arm_length
		arm.margin = 0.22
		arm.collision_mask = 1
		var shape := SphereShape3D.new()
		shape.radius = 0.18
		arm.shape = shape
		add_child(arm)
		camera = Camera3D.new()
		camera.near = 0.08
		arm.add_child(camera)
		camera.make_current()
	if target: arm.add_excluded_object(target.get_rid())
	set_process(not external)

static func spring(position: Vector3, velocity: Vector3, goal: Vector3, frequency: float, delta: float) -> Array[Vector3]:
	var omega := TAU * maxf(0.01, frequency)
	var offset := position - goal
	var impulse := velocity + offset * omega
	var decay := exp(-omega * maxf(0.0, delta))
	return [goal + (offset + impulse * delta) * decay, (velocity - impulse * omega * delta) * decay]

func follow_offset(delta: float, disabled: bool) -> Vector3:
	if not is_instance_valid(target): return Vector3.ZERO
	var velocity := target.velocity
	velocity.y = 0.0
	var goal := velocity.limit_length(9.8) * 0.035
	if disabled or reduced_motion: goal = Vector3.ZERO
	var result := spring(_follow, _follow_velocity, goal, follow_frequency, delta)
	_follow = result[0].limit_length(0.24)
	_follow_velocity = result[1]
	var landing := spring(Vector3(0,_compression,0), Vector3(0,_compression_velocity,0), Vector3.ZERO, 5.0, delta)
	_compression = landing[0].y
	_compression_velocity = landing[1].y
	return Vector3.ZERO if disabled or reduced_motion else _follow + Vector3.UP * clampf(_compression,-0.10,0.03)

func landed(impact_speed: float) -> void:
	if reduced_motion: return
	_compression_velocity -= clampf(impact_speed / 18.0,0.0,1.0) * 2.0
	add_trauma(clampf((impact_speed-4.0)/30.0,0.0,0.25), Vector3.DOWN)

func add_trauma(amount: float, direction: Vector3 = Vector3.ZERO) -> void:
	if reduced_motion or not is_finite(amount) or not direction.is_finite(): return
	trauma = clampf(trauma + amount,0.0,1.0)
	_punch = direction.limit_length(1.0)

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if enabled:
		trauma = 0.0
		_compression = 0.0
		_compression_velocity = 0.0
		_follow = Vector3.ZERO
		_follow_velocity = Vector3.ZERO
		if is_instance_valid(camera):
			camera.rotation = Vector3.ZERO
			if camera.current: camera.fov=base_fov

func tick_lens(delta: float, suspended: bool = false) -> void:
	if not is_instance_valid(camera): return
	if suspended or not camera.current:
		trauma = 0.0
		camera.rotation = Vector3.ZERO
		return
	_phase += delta
	trauma = maxf(0.0,trauma-delta*1.8)
	if reduced_motion:
		camera.rotation = Vector3.ZERO
		camera.fov = base_fov
		return
	var speed := Vector2(target.velocity.x,target.velocity.z).length() if is_instance_valid(target) else 0.0
	var ratio := smoothstep(1.55,9.8,speed)
	var side := target.velocity.dot(arm.global_basis.x) / 9.8 if is_instance_valid(target) else 0.0
	var bank := -deg_to_rad(maximum_bank_degrees) * clampf(side,-1.0,1.0) * ratio
	var shake := trauma * trauma
	var low := _noise.get_noise_1d(_phase * 13.0)
	var high := _noise.get_noise_1d(_phase * 37.0 + 91.0)
	var angles := Vector3(low*0.012, high*0.014,bank+low*shake*0.012)
	angles.x *= shake
	angles.y *= shake
	angles += _punch * shake * 0.008
	camera.rotation = camera.rotation.lerp(angles,1.0-exp(-22.0*delta))
	var wanted := lerpf(base_fov,maximum_fov,ratio) + shake * 1.3
	camera.fov = lerpf(camera.fov,clampf(wanted,base_fov,maximum_fov),1.0-exp(-6.0*delta))

func _process(delta: float) -> void:
	if external or not is_instance_valid(target): return
	var offset := follow_offset(delta,false)
	global_position = target.global_position + Vector3.UP * 1.4 + offset
	if is_instance_valid(lock_target):
		var aim := (target.global_position + lock_target.global_position)*0.5 + Vector3.UP
		if global_position.distance_squared_to(aim)>0.01: look_at(aim)
	tick_lens(delta)
