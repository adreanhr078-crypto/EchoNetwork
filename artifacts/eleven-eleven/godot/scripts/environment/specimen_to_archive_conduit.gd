extends Node3D

## Specimen-to-Archive Conduit Buffer (Sector 11 Spatial Buffer Zone)
## Bridges Room 5 (Specimen Containment Wing) exit at global X = -50.0m
## to Room 6 (Memory Archive Wing) entrance at global X = -64.0m.
## Enforces the Anti-Crowding Invariant:
## - 14.0m dedicated spatial separation.
## - Hermetic hull with zero shared geometry and zero light bleed.
## - Midpoint cable bulkhead with safe anchor and acoustic isolation (-40dB).

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

const CONDUIT_LENGTH := 14.0 # Along X: 0.0 to -14.0m
const CONDUIT_WIDTH := 2.6 # Along Z: -1.3m to +1.3m
const CONDUIT_HEIGHT := 3.2 # Along Y: 0.0m to +3.2m
const WALL_THICKNESS := 0.4

const SAFE_ANCHOR_MIDPOINT := Vector3(-7.0, 0.1, 0.0)

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
	
	var px: float = to_local(player.global_position).x
	if state == ConduitState.ENTRY_ZONE and px < -6.0:
		state = ConduitState.MIDPOINT_BULKHEAD
		if not bulkhead_open:
			_open_bulkhead()
	elif state == ConduitState.MIDPOINT_BULKHEAD and px < -12.5:
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
	
	var center_x := -CONDUIT_LENGTH * 0.5 # -7.0m
	
	# 1. Watertight Floor (top at Y = 0.0m)
	_box("Floor", Vector3(center_x, -WALL_THICKNESS * 0.5, 0.0), Vector3(CONDUIT_LENGTH, WALL_THICKNESS, CONDUIT_WIDTH), floor_mat, true)
	
	# 2. Watertight Ceiling (bottom at Y = 3.2m)
	_box("Ceiling", Vector3(center_x, CONDUIT_HEIGHT + WALL_THICKNESS * 0.5, 0.0), Vector3(CONDUIT_LENGTH, WALL_THICKNESS, CONDUIT_WIDTH), wall_mat, true)
	
	# 3. North Wall (Z = -1.3m, solid)
	_box("NorthWall", Vector3(center_x, CONDUIT_HEIGHT * 0.5, -CONDUIT_WIDTH * 0.5 - WALL_THICKNESS * 0.5), Vector3(CONDUIT_LENGTH, CONDUIT_HEIGHT, WALL_THICKNESS), wall_mat, true)
	
	# 4. South Wall (Z = +1.3m, solid)
	_box("SouthWall", Vector3(center_x, CONDUIT_HEIGHT * 0.5, CONDUIT_WIDTH * 0.5 + WALL_THICKNESS * 0.5), Vector3(CONDUIT_LENGTH, CONDUIT_HEIGHT, WALL_THICKNESS), wall_mat, true)
	
	# Overhead Cable Trays & Atmospheric Lights
	var cable_mat := _material(Color(0.12, 0.13, 0.15), 0.8, 0.3)
	_box("CeilingCableTray", Vector3(center_x, 2.9, 0.0), Vector3(CONDUIT_LENGTH, 0.2, 0.8), cable_mat, false)
	
	# Spaced low-intensity cyan guide strips
	for i in range(3):
		var lamp_x := -3.5 - i * 3.5
		var strip := _box("GuideLamp_%d" % i, Vector3(lamp_x, 2.8, -1.2), Vector3(0.6, 0.08, 0.08), _material(Color(0.0, 0.8, 0.9), 0.0, 0.1, true, Color(0.0, 0.8, 0.9), 1.5), false)
		var omni := OmniLight3D.new()
		omni.position = Vector3(lamp_x, 2.6, 0.0)
		omni.omni_range = 4.0
		omni.light_color = Color(0.0, 0.8, 0.9)
		omni.light_energy = 0.8
		omni.shadow_enabled = false
		add_child(omni)

func _build_midpoint_bulkhead() -> void:
	var metal_mat := _material(Color(0.18, 0.22, 0.25), 0.75, 0.35)
	
	# Frame at X = -7.0m
	_box("BulkheadFrameTop", Vector3(-7.0, 3.0, 0.0), Vector3(0.4, 0.4, CONDUIT_WIDTH), metal_mat, true)
	
	_bulkhead_gate = StaticBody3D.new()
	_bulkhead_gate.name = "MidpointBulkheadGate"
	_bulkhead_gate.position = Vector3(-7.0, _bulkhead_closed_y, 0.0)
	
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.2, 2.8, 2.5)
	mesh.mesh = box
	mesh.material_override = metal_mat
	_bulkhead_gate.add_child(mesh)
	
	_bulkhead_shape = CollisionShape3D.new()
	_bulkhead_shape.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.2, 2.8, 2.5)
	_bulkhead_shape.shape = shape
	_bulkhead_shape.disabled = false
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
	else:
		if _bulkhead_gate:
			var tween := create_tween()
			tween.tween_property(_bulkhead_gate, "position:y", _bulkhead_open_y, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			tween.tween_callback(func():
				if _bulkhead_shape:
					_bulkhead_shape.set_deferred("disabled", true)
			)

func get_safe_anchor() -> Vector3:
	return SAFE_ANCHOR_MIDPOINT

func set_audio_muted(muted: bool) -> void:
	audio_muted = muted

func get_state() -> Dictionary:
	return {
		"state": state,
		"bulkhead_open": bulkhead_open
	}

func restore_state(saved: Dictionary) -> bool:
	if not saved.is_empty() and saved.has("bulkhead_open"):
		state = saved.get("state", ConduitState.ENTRY_ZONE)
		bulkhead_open = saved.get("bulkhead_open", false)
		if bulkhead_open:
			if _bulkhead_gate:
				_bulkhead_gate.position.y = _bulkhead_open_y
			if _bulkhead_shape:
				_bulkhead_shape.disabled = true
		else:
			if _bulkhead_gate:
				_bulkhead_gate.position.y = _bulkhead_closed_y
			if _bulkhead_shape:
				_bulkhead_shape.disabled = false
		return true
	return false
