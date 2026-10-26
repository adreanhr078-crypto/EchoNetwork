class_name ShadowWaveProjectile
extends Area3D

## Solo Leveling style Sumi Ink / Dark Void cutting wave projectile.
## Slices forward from the Katana, cutting through enemies and leaving dark smoke.

@export var speed: float = 24.0
@export var damage: int = 85
@export var lifetime: float = 1.8

var direction: Vector3 = Vector3.FORWARD
var _distance_traveled: float = 0.0
var visual_only := false

func _ready() -> void:
	if visual_only: lifetime=.22
	collision_layer = 0
	collision_mask = 2 # Enemies / Boss
	monitoring = not visual_only
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
	quad.size = Vector2(1.7, 0.35)
	mesh_instance.mesh = quad
	
	var mat := ShaderMaterial.new()
	mat.shader=preload("res://engine_visuals/shaders/signal_cut.gdshader")
	mat.set_shader_parameter("shape_kind",1)
	mat.set_shader_parameter("signal_color",Color(.45,.06,.95))
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
	if visual_only: return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	
	# Spawn impact sparks
	var parent := get_parent()
	if parent:
		var ImpactSpawner = load("res://scripts/combat/impact_spawner.gd")
		if ImpactSpawner:
			ImpactSpawner.spawn_katana_sparks(parent, global_position, Vector3.UP, true)
			ImpactSpawner.spawn_damage_number(parent, global_position + Vector3(0, 0.5, 0), damage, true)
