class_name ProceduralSecondaryMotion
extends Node3D

## Procedural Secondary Motion / Spring Bones (Genshin / NieR tier physics)
## Simulates realistic inertia, gravity, and oscillation for hair, tassels, scabbards, and accessories.

@export var stiffness: float = 140.0 # Spring return strength
@export var damping: float = 12.0 # Oscillation friction
@export var inertia_influence: float = 0.08 # Responsiveness to parent movement
@export var max_angle_degrees: float = 38.0 # Angular limit to prevent clipping
@export var gravity_influence: float = 0.15

var angular_velocity: Vector3 = Vector3.ZERO
var current_rotation: Vector3 = Vector3.ZERO
var prev_parent_position: Vector3 = Vector3.ZERO
var is_initialized: bool = false

func _ready() -> void:
	if get_parent() is Node3D:
		prev_parent_position = (get_parent() as Node3D).global_position
		is_initialized = true

func _physics_process(delta: float) -> void:
	if not is_inside_tree() or delta <= 0.0:
		return

	var parent_node := get_parent() as Node3D
	if not parent_node:
		return

	if not is_initialized:
		prev_parent_position = parent_node.global_position
		is_initialized = true
		return

	# 1. Calculate parent linear movement delta (Inertia force)
	var current_pos: Vector3 = parent_node.global_position
	var parent_motion: Vector3 = current_pos - prev_parent_position
	prev_parent_position = current_pos

	# Transform motion into local coordinate frame
	var local_motion: Vector3 = parent_node.global_basis.inverse() * parent_motion

	# 2. Inertia torque: acceleration opposes velocity
	var inertia_torque: Vector3 = Vector3(
		-local_motion.z * inertia_influence * 60.0,
		local_motion.x * inertia_influence * 30.0,
		local_motion.x * inertia_influence * 60.0
	)

	# 3. Spring physics: F = -k*x - c*v
	var spring_force: Vector3 = -stiffness * current_rotation
	var damping_force: Vector3 = -damping * angular_velocity

	var total_torque: Vector3 = spring_force + damping_force + inertia_torque

	# 4. Integrate angular velocity & position
	angular_velocity += total_torque * delta
	current_rotation += angular_velocity * delta

	# 5. Clamp to physical bounds
	var max_rad: float = deg_to_rad(max_angle_degrees)
	current_rotation.x = clamp(current_rotation.x, -max_rad, max_rad)
	current_rotation.y = clamp(current_rotation.y, -max_rad * 0.5, max_rad * 0.5)
	current_rotation.z = clamp(current_rotation.z, -max_rad, max_rad)

	# 6. Apply rotation to node
	rotation = current_rotation

func apply_impulse(impulse: Vector3) -> void:
	angular_velocity += impulse
