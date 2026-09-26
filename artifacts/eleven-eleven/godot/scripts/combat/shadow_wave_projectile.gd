class_name ShadowWaveProjectile
extends Area3D

## Solo Leveling style Sumi Ink / Dark Void cutting wave projectile.
## Slices forward from the Katana, cutting through enemies and leaving dark smoke.

@export var speed: float = 24.0
@export var damage: int = 85
@export var lifetime: float = 1.8

var direction: Vector3 = Vector3.FORWARD
var _distance_traveled: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Enemies / Boss
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	
	_create_visuals()
	
	# Auto-destroy after lifetime
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)

func _create_visuals() -> void:
	# Crescent blade mesh
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "WaveMesh"
	
	var quad := QuadMesh.new()
	quad.size = Vector2(2.4, 0.4)
	mesh_instance.mesh = quad
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.05, 0.02, 0.12, 1.0) # Obsidian black
	mat.emission_enabled = true
	mat.emission = Color(0.72, 0.12, 0.95, 1.0) # Blazing violet void rim
	mat.emission_energy_multiplier = 4.2
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = mat
	add_child(mesh_instance)
	
	# Collision Shape
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 0.6, 0.6)
	col.shape = shape
	add_child(col)

func _physics_process(delta: float) -> void:
	var move := direction * speed * delta
	global_position += move
	_distance_traveled += move.length()

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	
	# Spawn impact sparks
	var parent := get_parent()
	if parent:
		var ImpactSpawner = load("res://scripts/combat/impact_spawner.gd")
		if ImpactSpawner:
			ImpactSpawner.spawn_katana_sparks(parent, global_position, Vector3.UP, true)
			ImpactSpawner.spawn_damage_number(parent, global_position + Vector3(0, 0.5, 0), damage, true)
