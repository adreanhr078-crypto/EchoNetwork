extends Node3D

## Layered, room-local motion. All state is presentation from real room events.
const FIELD = preload("res://shaders/opening_energy_field.gdshader")
const CIRCUIT = preload("res://shaders/opening_circuit_particles.gdshader")
const RINGS = preload("res://shaders/opening_discovery_rings.gdshader")
var reduced_motion := false
var event_age := 4.0
var _fields: Array[MultiMeshInstance3D] = []
var _materials: Array[ShaderMaterial] = []
var _circuit: MultiMeshInstance3D
var _circuit_material: ShaderMaterial
var _rings: MultiMeshInstance3D
var _ring_material: ShaderMaterial
var event_count := 0

func _ready() -> void:
	# The approved room geometry owns the pod position. Keep its visible cold-air
	# bed below the clue/face line instead of filling the upper player silhouette.
	_build_field("CryoVapor", 14, 0, Vector3(-1.95,0.22,2.35), Vector3(1.05,0.10,0.95), Vector2(1.55,0.72), Color(0.34,0.70,0.84))
	_build_field("ObservationMotes", 32, 1, Vector3(6.1,2.0,-5.5), Vector3(1.1,1.4,2.0), Vector2(0.055,0.055), Color(0.34,0.55,0.96))
	_build_field("SignalFragments", 12, 2, Vector3(2.8,1.15,2.4), Vector3(0.48,0.22,0.10), Vector2(0.24,0.06), Color(0.12,0.72,0.80))
	var grain := SphereMesh.new()
	grain.radius = 0.021
	grain.height = 0.042
	grain.radial_segments = 4
	grain.rings = 2
	_circuit_material = ShaderMaterial.new()
	_circuit_material.shader = CIRCUIT
	_circuit = _instances("ConduitEnergyPackets", 24, grain, _circuit_material)
	_circuit.custom_aabb = AABB(Vector3(-4,0,-18),Vector3(5,1,15))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.74
	ring.outer_radius = 0.76
	ring.rings = 40
	ring.ring_segments = 6
	_ring_material = ShaderMaterial.new()
	_ring_material.shader = RINGS
	_rings = _instances("DiscoveryEchoRings", 3, ring, _ring_material)
	_rings.custom_aabb = AABB(Vector3(-3.5,0,-3.5),Vector3(7,2,7))

func _instances(id: String, count: int, mesh: Mesh, material: ShaderMaterial) -> MultiMeshInstance3D:
	var visual := MultiMeshInstance3D.new()
	visual.name = id
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.multimesh = MultiMesh.new()
	visual.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	visual.multimesh.use_custom_data = true
	visual.multimesh.mesh = mesh
	visual.multimesh.instance_count = count
	for index in count:
		visual.multimesh.set_instance_transform(index,Transform3D.IDENTITY)
		visual.multimesh.set_instance_custom_data(index,Color(float(index)/count,float((index*17)%count)/count,0,1))
	visual.material_override = material
	add_child(visual)
	return visual

func _build_field(id: String, count: int, kind: int, center: Vector3, spread: Vector3, size: Vector2, tint: Color) -> void:
	var quad := QuadMesh.new()
	quad.size = size
	var material := ShaderMaterial.new()
	material.shader = FIELD
	material.set_shader_parameter("kind",kind)
	material.set_shader_parameter("tint",tint)
	var visual := _instances(id,count,quad,material)
	visual.position = center
	var rng := RandomNumberGenerator.new()
	rng.seed = 111120+kind
	for index in count:
		var offset := Vector3(rng.randf_range(-spread.x,spread.x),rng.randf_range(-spread.y,spread.y),rng.randf_range(-spread.z,spread.z))
		visual.multimesh.set_instance_transform(index,Transform3D(Basis.IDENTITY,offset))
	visual.custom_aabb = AABB(-spread-Vector3.ONE*2,spread*2+Vector3.ONE*5)
	_fields.append(visual)
	_materials.append(material)

func react_at(world_position: Vector3, personal: bool) -> void:
	event_count += 1
	if reduced_motion: return
	event_age = 0.0
	_rings.global_position = world_position
	_ring_material.set_shader_parameter("tint",Color(0.58,0.33,0.88) if personal else Color(0.12,0.72,0.90))

func sync(time: float, delta: float, room_phase: int, power: float, reduced: bool, active: bool) -> void:
	reduced_motion = reduced
	visible = active
	if not reduced: event_age = minf(4.0,event_age+minf(delta,0.1))
	else: event_age = 4.0
	for index in _fields.size():
		_fields[index].visible = not reduced and (index != 2 or room_phase >= 3)
		_materials[index].set_shader_parameter("motion_time",time)
		_materials[index].set_shader_parameter("strength",0.90 if index == 0 else 0.62 if index == 1 else 0.55)
	_circuit.visible = power > 0.5 and not reduced
	_circuit_material.set_shader_parameter("motion_time",time)
	_circuit_material.set_shader_parameter("strength",power)
	_rings.visible = not reduced and event_age < 2.2
	_ring_material.set_shader_parameter("event_age",event_age)

func diagnostics() -> Dictionary:
	return {"instances":85,"draw_groups":5,"event_count":event_count,"reduced_motion":reduced_motion,"active":visible,"extra_lights":0,"colliders":0}
