extends Node3D

## Local, collision-free airborne dust and pneumatic release particles.
## The parent room owns activation/pause and Reduced Motion; no authority here.
var anchors: Array[Vector3] = []
var extent := Vector3(1.3,1.2,1.3)
var particles_per_anchor := 18
var tint := Color(0.52,0.73,0.8,0.25)
var seed_value := 111104
var motion_time := 0.0
var release_count := 0
var _air: MultiMeshInstance3D
var _release: MultiMeshInstance3D
var _release_start := -10.0

func _ready() -> void:
	_air = _batch(anchors,particles_per_anchor,false)
	_air.name = "AirborneDust"
	_release = _batch([Vector3.ZERO],24,true)
	_release.name = "PneumaticRelease"
	_release.visible = false

func _batch(points: Array[Vector3],count: int,release: bool) -> MultiMeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.045,0.045) if not release else Vector2(0.12,0.12)
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	instances.mesh = mesh
	instances.instance_count = points.size()*count
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + (1 if release else 0)
	var bounds := AABB()
	for i in instances.instance_count:
		var origin: Vector3 = points[i/count]
		var span := Vector3(0.5,0.15,0.25) if release else extent
		var point := origin+Vector3(rng.randf_range(-span.x,span.x),rng.randf_range(-span.y,span.y),rng.randf_range(-span.z,span.z))
		var size := rng.randf_range(0.65,1.25)
		instances.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),point))
		instances.set_instance_custom_data(i,Color(rng.randf(),rng.randf(),rng.randf(),1))
		bounds = AABB(point,Vector3.ZERO) if i==0 else bounds.expand(point)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/room_motes.gdshader")
	material.set_shader_parameter("mote_color",tint)
	material.set_shader_parameter("release_mode",release)
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = instances
	batch.material_override = material
	batch.custom_aabb = bounds.grow(2.0)
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)
	return batch

func _process(delta: float) -> void:
	var reduced: bool = get_parent().reduced_motion
	_air.visible = not reduced
	if reduced:
		_release.visible = false
		return
	motion_time += minf(delta,0.1)
	_air.material_override.set_shader_parameter("motion_time",motion_time)
	_release.material_override.set_shader_parameter("motion_time",motion_time)
	if motion_time-_release_start>=1.6: _release.visible = false

func emit_release(point: Vector3) -> void:
	if get_parent().reduced_motion: return
	release_count += 1
	_release.position = point
	_release_start = motion_time
	_release.material_override.set_shader_parameter("release_start",motion_time)
	_release.visible = true
