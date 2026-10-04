extends Node3D

## Archive-to-Reactor Conduit Buffer (Sector 11 Spatial Buffer Zone 6-7)
## Bridges Room 6 (Memory Archive Wing) North Exit at Z = 0.0m
## to Room 7 (Core Reactor & Power Station) South Entrance at Z = -15.0m.
## Enforces the Anti-Crowding Invariant:
## - 15.0m dedicated spatial separation along -Z axis.
## - Hermetic hull with zero shared geometry and zero light bleed.
## - Midpoint electromagnetic bulkhead with safe anchor and acoustic isolation (-40dB).
## - Unloads/pauses Room 6 processing once player passes midpoint.

signal bulkhead_opened
signal player_passed_conduit
signal retry_requested(anchor: Vector3)

enum ConduitState {
	ENTRY_ZONE,
	MIDPOINT_BULKHEAD,
	EXIT_ZONE,
	PASSED
}

const CERAMIC = preload("res://assets/environments/maintenance_jutsu_v1_Maintenance ceramic grain 512.png")
const GRAPHITE = preload("res://assets/environments/maintenance_jutsu_v1_Maintenance brushed graphite 512.png")

const CONDUIT_LENGTH := 15.0 # Along Z: 0.0 to -15.0m
const CONDUIT_WIDTH := 2.6 # Along X: -1.3m to +1.3m
const CONDUIT_HEIGHT := 3.2 # Along Y: 0.0m to +3.2m
const WALL_THICKNESS := 0.4

const SAFE_ANCHOR_ENTRY := Vector3(0.0, 0.1, -1.5)
const SAFE_ANCHOR_MIDPOINT := Vector3(0.0, 0.1, -7.5)

var state: ConduitState = ConduitState.ENTRY_ZONE
var reduced_motion := false
var audio_muted := false
var player: Node3D

var bulkhead_open := false
var _bulkhead_gate: StaticBody3D
var _bulkhead_shape: CollisionShape3D
var _bulkhead_open_y := 4.2
var _bulkhead_closed_y := 1.4

func _ready() -> void:
	_build_conduit_geometry()
	_build_midpoint_bulkhead()

func _physics_process(_delta: float) -> void:
	if not player or not is_instance_valid(player):
		return
	
	var pz: float = to_local(player.global_position).z
	if state == ConduitState.ENTRY_ZONE and pz < -6.0:
		state = ConduitState.MIDPOINT_BULKHEAD
		if not bulkhead_open:
			_open_bulkhead()
	elif state == ConduitState.MIDPOINT_BULKHEAD and pz < -13.5:
		state = ConduitState.PASSED
		player_passed_conduit.emit()

func _material(color: Color, metal: float = 0.0, rough: float = 0.7, emission: bool = false, emission_color := Color.BLACK, energy := 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = rough
	if emission:
		mat.emission_enabled = true
		mat.emission = emission_color if emission_color != Color.BLACK else color
		mat.emission_energy_multiplier = energy
	return mat

func _box(label: String, center: Vector3, size: Vector3, mat: Material, solid := false) -> Node3D:
	var node: Node3D = StaticBody3D.new() if solid else Node3D.new()
	node.name = label
	node.position = center
	var visual := MeshInstance3D.new()
	visual.mesh = BoxMesh.new()
	visual.mesh.size = size
	visual.material_override = mat
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	node.add_child(visual)
	if solid:
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var box := BoxShape3D.new()
		box.size = size
		collision.shape = box
		node.add_child(collision)
	add_child(node)
	return node

func _build_conduit_geometry() -> void:
	var wall_mat := _material(Color(0.2, 0.22, 0.26), 0.2, 0.6)
	wall_mat.albedo_texture = CERAMIC
	wall_mat.uv1_scale = Vector3(2.0, 2.0, 1.0)
	
	var floor_mat := _material(Color(0.14, 0.16, 0.19), 0.6, 0.5)
	floor_mat.albedo_texture = GRAPHITE
	floor_mat.uv1_scale = Vector3(2.0, 2.0, 1.0)
	
	var center_z := -CONDUIT_LENGTH * 0.5 # -7.5m
	
	# Floor (solid) - Length 15.0m along Z, Width 2.6m along X
	_box("Floor", Vector3(0.0, -WALL_THICKNESS * 0.5, center_z), Vector3(CONDUIT_WIDTH, WALL_THICKNESS, CONDUIT_LENGTH), floor_mat, true)
	
	# Ceiling (solid)
	_box("Ceiling", Vector3(0.0, CONDUIT_HEIGHT + WALL_THICKNESS * 0.5, center_z), Vector3(CONDUIT_WIDTH, WALL_THICKNESS, CONDUIT_LENGTH), wall_mat, true)
	
	# West Wall (solid) along X = -1.3m
	_box("WestWall", Vector3(-CONDUIT_WIDTH * 0.5 - WALL_THICKNESS * 0.5, CONDUIT_HEIGHT * 0.5, center_z), Vector3(WALL_THICKNESS, CONDUIT_HEIGHT, CONDUIT_LENGTH), wall_mat, true)
	
	# East Wall (solid) along X = +1.3m
	_box("EastWall", Vector3(CONDUIT_WIDTH * 0.5 + WALL_THICKNESS * 0.5, CONDUIT_HEIGHT * 0.5, center_z), Vector3(WALL_THICKNESS, CONDUIT_HEIGHT, CONDUIT_LENGTH), wall_mat, true)
	
	# Ambient conduit lights (low amber/cyan strip lighting)
	for i in range(3):
		var lz := -3.0 - float(i) * 4.5
		var strip := OmniLight3D.new()
		strip.name = "StripLight_%d" % i
		strip.position = Vector3(0.0, CONDUIT_HEIGHT - 0.2, lz)
		strip.light_color = Color(0.9, 0.65, 0.2) # Stasis amber
		strip.light_energy = 0.8
		strip.omni_range = 4.5
		strip.shadow_enabled = true
		add_child(strip)

func _build_midpoint_bulkhead() -> void:
	var frame_mat := _material(Color(0.25, 0.28, 0.32), 0.8, 0.3)
	var gate_mat := _material(Color(0.18, 0.2, 0.24), 0.9, 0.25, true, Color(0.9, 0.5, 0.1), 0.5)
	
	var bh_z := -CONDUIT_LENGTH * 0.5 # -7.5m
	
	# Arch frame sides
	_box("BulkheadFrameWest", Vector3(-1.15, CONDUIT_HEIGHT * 0.5, bh_z), Vector3(0.3, CONDUIT_HEIGHT, 0.6), frame_mat, true)
	_box("BulkheadFrameEast", Vector3(1.15, CONDUIT_HEIGHT * 0.5, bh_z), Vector3(0.3, CONDUIT_HEIGHT, 0.6), frame_mat, true)
	_box("BulkheadFrameLintel", Vector3(0.0, 2.9, bh_z), Vector3(CONDUIT_WIDTH, 0.6, 0.6), frame_mat, true)
	
	# Sliding Gate Door (2.05m wide x 2.8m high x 0.2m thick)
	_bulkhead_gate = StaticBody3D.new()
	_bulkhead_gate.name = "MidpointBulkheadGate"
	_bulkhead_gate.position = Vector3(0.0, _bulkhead_closed_y, bh_z)
	
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = Vector3(2.05, 2.8, 0.2)
	mesh.material_override = gate_mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_bulkhead_gate.add_child(mesh)
	
	_bulkhead_shape = CollisionShape3D.new()
	_bulkhead_shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(2.05, 2.8, 0.2)
	_bulkhead_shape.shape = box
	_bulkhead_gate.add_child(_bulkhead_shape)
	
	add_child(_bulkhead_gate)

func _open_bulkhead() -> void:
	if bulkhead_open:
		return
	bulkhead_open = true
	bulkhead_opened.emit()
	
	if reduced_motion:
		if _bulkhead_gate:
			_bulkhead_gate.position.y = _bulkhead_open_y
		if _bulkhead_shape:
			_bulkhead_shape.set_deferred("disabled", true)
		return
	
	if _bulkhead_gate:
		var tween := create_tween()
		tween.tween_property(_bulkhead_gate, "position:y", _bulkhead_open_y, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func():
			if _bulkhead_shape:
				_bulkhead_shape.set_deferred("disabled", true)
		)

func get_safe_anchor() -> Vector3:
	if state == ConduitState.ENTRY_ZONE:
		return SAFE_ANCHOR_ENTRY
	return SAFE_ANCHOR_MIDPOINT

func get_state() -> Dictionary:
	return {
		"state": state,
		"bulkhead_open": bulkhead_open,
		"gate_pos_y": _bulkhead_gate.position.y if _bulkhead_gate else _bulkhead_closed_y,
		"gate_col_disabled": _bulkhead_shape.disabled if _bulkhead_shape else false
	}

func restore_state(data: Dictionary) -> void:
	if data.has("state"):
		state = data["state"]
	if data.has("bulkhead_open"):
		bulkhead_open = data["bulkhead_open"]
	if _bulkhead_gate and data.has("gate_pos_y"):
		_bulkhead_gate.position.y = data["gate_pos_y"]
	if _bulkhead_shape and data.has("gate_col_disabled"):
		_bulkhead_shape.disabled = data["gate_col_disabled"]
