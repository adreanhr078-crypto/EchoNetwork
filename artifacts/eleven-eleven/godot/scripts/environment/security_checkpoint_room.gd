extends Node3D

## Local human stealth room. Route authority remains with the journey controller.
signal passage_ready
signal discovery_observed(id: String)
signal retry_requested(anchor: Vector3)
signal warning_changed(amount: float)

const SERVICE_MODULE = preload("res://assets/environment/sector11_service_module_v1.glb")
const CEILING_TILE = preload("res://assets/environment/sector11_ceiling_tile_v1.glb")
const CERAMIC = preload("res://assets/environments/maintenance_jutsu_v1_Maintenance ceramic grain 512.png")
const GRAPHITE = preload("res://assets/environments/maintenance_jutsu_v1_Maintenance brushed graphite 512.png")
const STATION = preload("res://scripts/environment/security_station.gd")
const RELAY_AUDIO = preload("res://assets/audio/maintenance_service_release_v1.ogg")
var player: CharacterBody3D
var gate_open := false
var service_trace := false
var scanner_trace := false
var warning := 0.0
var diversion_remaining := 0.0
var elapsed := 0.0
var reduced_motion := false
var _scanner: Node3D
var _lamp: SpotLight3D
var _gate: StaticBody3D
var _gate_shape: CollisionShape3D
var _signal: StandardMaterial3D
var _audio: AudioStreamPlayer3D
var _retry_cooldown := 0.0
var _stations: Dictionary = {}
var _language := "ar"
var _passage_reported := false

func _ready() -> void:
	_build_room()
	set_language(_language)

func _physics_process(delta: float) -> void:
	elapsed += delta
	diversion_remaining = maxf(0, diversion_remaining - delta)
	_retry_cooldown = maxf(0, _retry_cooldown - delta)
	_scanner.rotation.y = PI + sin(elapsed * 0.55) * 0.78
	_lamp.light_color = Color(1,0.48,0.13) if diversion_remaining <= 0 else Color(0.3,0.75,1)
	_lamp.light_energy = 1.2 if diversion_remaining <= 0 else 0.15
	if not is_instance_valid(player): return
	var local := to_local(player.global_position)
	if local.y < -1 or (local.z <= 0.1 and local.z >= -18 and absf(local.x) > 4.6):
		_request_retry()
		return
	if local.z > 0.1 or local.z < -18 or absf(local.x) > 4.4 or _passage_reported: return
	var seen := diversion_remaining <= 0 and _retry_cooldown <= 0 and _scanner_sees(player)
	var previous := warning
	warning = move_toward(warning, 1.0 if seen else 0.0, delta * (0.6 if seen else 1.2))
	if not is_equal_approx(previous,warning): warning_changed.emit(warning)
	if warning >= 1.0:
		_request_retry()
	if local.x > 2.6 and local.y > 2.2 and local.z < -8 and not service_trace:
		service_trace = true
		discovery_observed.emit("security_service_trace")
	if gate_open and local.z < -17 and absf(local.x) < 0.8 and player.is_on_floor():
		_passage_reported = true
		passage_ready.emit()

func _request_retry() -> void:
	if _retry_cooldown > 0: return
	warning = 0
	_retry_cooldown = 2.0
	retry_requested.emit(to_global(Vector3(-2.6,0.1,-1.4)))

func _scanner_sees(actor: CharacterBody3D) -> bool:
	var origin := _scanner.global_position
	var chest := actor.global_position + Vector3.UP * 0.95
	var offset := chest - origin
	if offset.length() > 13 or offset.length() < 0.1: return false
	var facing := -_scanner.global_basis.z
	if facing.dot(offset.normalized()) < cos(deg_to_rad(12)): return false
	var ray := PhysicsRayQueryParameters3D.create(origin,chest,1,[actor.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func request_station(action: String, actor: Node3D, station: Node3D) -> Dictionary:
	if not is_instance_valid(actor) or actor != player or actor.global_position.distance_to(station.global_position) > 2.1:
		return {"accepted": false}
	if not player.is_on_floor() or (player is EchoPlayer and player.control_locked) or not _stations.has(action) or _stations[action] != station:
		return {"accepted":false}
	match action:
		"divert":
			diversion_remaining = 8.0
			warning = 0
			if not scanner_trace:
				scanner_trace = true
				discovery_observed.emit("security_scanner_trace")
			_audio.play()
		"gate":
			if gate_open: return {"accepted": false}
			gate_open = true
			_signal.albedo_color = Color(0.12,0.85,0.75)
			_signal.emission = _signal.albedo_color
			_stations.gate.get_node("InteractionArea").is_enabled = false
			_audio.play()
			if reduced_motion:
				_gate.position.y = 4.3
				_gate_shape.set_deferred("disabled",true)
			else:
				var opening := create_tween()
				opening.tween_property(_gate,"position:y",4.3,0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
				opening.tween_callback(func(): _gate_shape.set_deferred("disabled",true))
		_: return {"accepted": false}
	return {"accepted":true,"action":action}

func restore_state(state: Dictionary) -> bool:
	if state.size() != 3 or not state.get("gate_open") is bool or not state.get("service_trace") is bool or not state.get("scanner_trace") is bool: return false
	gate_open = state.gate_open
	service_trace = state.service_trace
	scanner_trace = state.scanner_trace
	_gate_shape.set_deferred("disabled",gate_open)
	_gate.position.y = 4.3 if gate_open else 1.4
	_stations.gate.get_node("InteractionArea").is_enabled = not gate_open
	_signal.albedo_color = Color(0.12,0.85,0.75) if gate_open else Color(1,0.48,0.13)
	_signal.emission = _signal.albedo_color
	return true

func get_state() -> Dictionary:
	return {"gate_open":gate_open,"service_trace":service_trace,"scanner_trace":scanner_trace}

func set_language(language: String) -> void:
	_language = "en" if language == "en" else "ar"
	if _stations.is_empty(): return
	_stations.divert.get_node("InteractionArea").prompt_target_name = "محوّل إشارة المراقبة" if _language == "ar" else "Surveillance signal diversion"
	_stations.gate.get_node("InteractionArea").prompt_target_name = "قفل الحاجز الأمني" if _language == "ar" else "Security passage latch"

func set_audio_muted(muted: bool) -> void:
	if _audio: _audio.volume_db = -80 if muted else -22

func _exit_tree() -> void:
	# Release compressed playback before the room is unloaded or retried.
	if is_instance_valid(_audio):
		_audio.stop()
		_audio.stream = null

func _material(color: Color, metal: float = 0.0, rough: float = 0.7, emission: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = rough
	if emission:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.6
	return mat

func _box(label: String, center: Vector3, size: Vector3, material: Material, solid := false, climb := false) -> Node3D:
	var node: Node3D = StaticBody3D.new() if solid else Node3D.new()
	node.name = label
	node.position = center
	var visual := MeshInstance3D.new()
	visual.mesh = BoxMesh.new()
	visual.mesh.size = size
	visual.material_override = material
	node.add_child(visual)
	if solid:
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		collision.shape = BoxShape3D.new()
		collision.shape.size = size
		node.add_child(collision)
		if climb: node.add_to_group("climbable")
	add_child(node)
	return node

func _build_room() -> void:
	var wall := _material(Color(0.3,0.35,0.4),0.15)
	wall.albedo_texture = CERAMIC
	wall.uv1_scale = Vector3(2,2,1)
	var floor_mat := _material(Color(0.25,0.3,0.33),0.15,0.8)
	var metal := _material(Color(0.18,0.22,0.25),0.45,0.55)
	metal.albedo_texture = GRAPHITE
	var ivory := _material(Color(0.7,0.73,0.70),0.0,0.8)
	var cyan := _material(Color(0.12,0.72,0.76),0,0.5,true)
	var amber := _material(Color(1,0.48,0.13),0,0.5,true)
	_box("Floor",Vector3(0,-0.15,-9),Vector3(8.8,0.3,18.4),floor_mat,true)
	for x in [-4.5,4.5]:
		_box("Wall",Vector3(x,2.4,-9),Vector3(0.2,4.8,18),wall,true)
		for z in range(1,18,3):
			_box("BayFrame",Vector3(x*0.98,2.25,-z),Vector3(0.16,4.5,0.12),metal)
			_box("WallInset",Vector3(x*0.97,2.6,-z-0.9),Vector3(0.08,1.45,1.6),ivory)
		_box("ServiceLight",Vector3(x*0.95,3.85,-9),Vector3(0.05,0.06,17.6),cyan)
		for z in [-5.8,-11.8]:
			var module: Node3D = SERVICE_MODULE.instantiate()
			module.name = "ReusedServiceBay"
			module.position = Vector3(x*0.98,0.2,z)
			module.rotation.y = -signf(x)*PI/2
			module.scale = Vector3.ONE*0.6
			add_child(module)
	_box("ExitRecoveryBoundary",Vector3(0,2.2,-18.22),Vector3(8.8,4.4,0.12),wall,true)
	# Hermetic entrance bulkhead with 1.8m x 2.8m portal matching Airlock exit
	for x in [-2.7, 2.7]:
		_box("EntrancePier", Vector3(x, 2.2, 0.0), Vector3(3.6, 4.4, 0.4), wall, true)
	_box("EntranceLintel", Vector3(0.0, 3.8, 0.0), Vector3(1.8, 1.2, 0.4), metal, true)
	# Hermetic ceiling slab
	_box("Ceiling", Vector3(0.0, 4.8, -9.0), Vector3(8.8, 0.4, 18.4), wall, true)
	for z in [-2.5,-9,-15.5]:
		var tile: Node3D = CEILING_TILE.instantiate()
		tile.position = Vector3(0,4.4,z)
		tile.scale = Vector3(0.9,1,0.9)
		add_child(tile)
	for z in range(0,19,2):
		_box("FloorJoint",Vector3(0,0.004,-z),Vector3(8.7,0.012,0.025),metal)
	for x in [-1.45,1.45]:
		_box("FloorLane",Vector3(x,0.009,-9),Vector3(0.035,0.012,18),metal)
	for z in [-4.2,-8.2,-12.2]:
		for x in [-1.9,1.9]:
			_box("CoverPlinth",Vector3(x,0.85,z),Vector3(1.6,1.7,1.1),metal,true)
			_box("CoverPanel",Vector3(x,0.9,z+0.559),Vector3(1.36,1.4,0.025),wall)
			_box("CoverEdge",Vector3(x,1.69,z),Vector3(1.48,0.025,1.03),ivory)
			_box("CoverIndicator",Vector3(x-0.52,1.06,z+0.574),Vector3(0.18,0.04,0.025),cyan)
	# One authored climb face, a service walkway and a grounded descent.
	_box("ServiceClimb",Vector3(3.6,1.2,-3.1),Vector3(1.3,2.4,1.6),metal,true,true)
	for y in [0.3,0.65,1.0,1.35,1.7,2.05]:
		_box("Grip",Vector3(3.6,y,-2.29),Vector3(0.9,0.055,0.06),ivory)
	_box("ServiceWalkway",Vector3(3.6,2.28,-8.4),Vector3(1.3,0.24,9.2),metal,true)
	for z in range(4,14,2):
		_box("ServiceRailPost",Vector3(4.12,2.75,-z),Vector3(0.04,0.7,0.04),ivory)
	_box("ServiceRail",Vector3(4.12,3.05,-8.5),Vector3(0.04,0.04,10),ivory)
	_box("DescentPlatform",Vector3(3.6,1.25,-14.2),Vector3(1.3,0.18,1.6),metal,true)
	# Exit wall frames a genuine 1.8m opening, with a movable collision gate.
	for x in [-2.7,2.7]: _box("ExitPier",Vector3(x,2.2,-16.5),Vector3(3.6,4.4,0.25),wall,true)
	_box("ExitLintel",Vector3(0,3.6,-16.5),Vector3(1.8,1.6,0.25),metal,true)
	_signal = _material(Color(1,0.48,0.13),0,0.5,true)
	_gate = _box("SecurityGate",Vector3(0,1.4,-16.5),Vector3(1.76,2.8,0.18),metal,true) as StaticBody3D
	_gate_shape = _gate.get_node("CollisionShape3D") as CollisionShape3D
	var strip := MeshInstance3D.new()
	strip.mesh = BoxMesh.new()
	strip.mesh.size = Vector3(0.035,2.4,0.2)
	strip.material_override = _signal
	_gate.add_child(strip)
	_stations.divert = _station("DivertStation",Vector3(-3.5,0.9,-1.8),"divert",amber,metal)
	_stations.gate = _station("GateStation",Vector3(-1.3,0.9,-15.6),"gate",cyan,metal)
	_scanner = Node3D.new()
	_scanner.name = "Scanner"
	_scanner.position = Vector3(0,2.0,-14.5)
	_scanner.rotation.x = deg_to_rad(-6)
	add_child(_scanner)
	var scanner_body := MeshInstance3D.new()
	scanner_body.mesh = SphereMesh.new()
	scanner_body.mesh.radius = 0.17
	scanner_body.mesh.height = 0.24
	scanner_body.material_override = metal
	_scanner.add_child(scanner_body)
	var lens := MeshInstance3D.new()
	lens.mesh = CylinderMesh.new()
	lens.mesh.top_radius = 0.08
	lens.mesh.bottom_radius = 0.08
	lens.mesh.height = 0.05
	lens.rotation.x = PI/2
	lens.position.z = -0.17
	lens.material_override = amber
	_scanner.add_child(lens)
	_lamp = SpotLight3D.new()
	_lamp.spot_range = 13
	_lamp.spot_angle = 12
	_lamp.shadow_enabled = true
	_scanner.add_child(_lamp)
	_box("ScannerMount",Vector3(0,3.3,-14.5),Vector3(0.08,2.6,0.08),metal)
	for z in [-2.5,-9,-15.5]:
		var light := OmniLight3D.new()
		light.position = Vector3(0,4,z)
		light.light_color = Color(0.78,0.85,0.92)
		light.light_energy = 0.7
		light.omni_range = 7
		add_child(light)
	_audio = AudioStreamPlayer3D.new()
	_audio.stream = RELAY_AUDIO
	_audio.volume_db = -22
	_audio.position = Vector3(-1.3,1,-15.6)
	_audio.max_distance = 15
	add_child(_audio)

func _station(label: String, center: Vector3, action: String, face: Material, housing: Material) -> Node3D:
	var station := Node3D.new()
	station.name = label
	station.set_script(STATION)
	station.action = action
	station.position = center
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = Vector3(0.4,0.6,0.22)
	mesh.material_override = housing
	station.add_child(mesh)
	var plate := MeshInstance3D.new()
	plate.mesh = BoxMesh.new()
	plate.mesh.size = Vector3(0.24,0.28,0.025)
	plate.position.z = 0.13
	plate.material_override = face
	station.add_child(plate)
	var interaction := InteractableComponent.new()
	interaction.name = "InteractionArea"
	interaction.verb = InteractableComponent.InteractionVerb.OPEN
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	shape.shape.radius = 1.4
	interaction.add_child(shape)
	station.add_child(interaction)
	add_child(station)
	return station
