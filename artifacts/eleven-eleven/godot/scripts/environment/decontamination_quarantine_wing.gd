extends Node3D

## Room 8: Decontamination & Quarantine Wing (Sector 11 Bio-Containment & Sterilization)
## Connects from Buffer 7-8 (Reactor-to-Decon Conduit) South Entrance at Z = 0.0m
## to Room 9 North Exit Blast Gate at Z = -32.0m.
## Enforces the Anti-Crowding and Quality Gate Invariants:
## - Watertight Hull (24.0m x 32.0m x 7.2m), solid collision envelope, zero light bleed.
## - Narrative & Gameplay Flow:
##   * Decon Chamber 1: Sterilization archway with UV pulses (#7209B7 UV / #D8F3DC Clinical Teal).
##   * Central Quarantine Pod Row: 6 reinforced bio-quarantine tanks.
##   * Elevated Observation Catwalk Bridge at Y = +3.2m with access stairs.
##   * Central Quarantine Override Terminal implementing trigger_interaction(player).
##   * Unlocking the North Exit Blast Gate to Room 9.
## - 3-Tier Safe Anchors (Entry, Catwalk, Exit).
## - Full accessibility: reduced motion, audio mute, durable state save/restore.

signal quarantine_override_initiated
signal quarantine_cleared
signal exit_gate_opened
signal retry_requested(anchor: Vector3)

enum RoomState {
	ENTRY_STERILIZATION,
	POD_OBSERVATION,
	OVERRIDE_ACTIVE,
	QUARANTINE_CLEARED,
	EXIT_CORRIDOR
}

const CERAMIC = preload("res://assets/environments/maintenance_jutsu_v1_Maintenance ceramic grain 512.png")
const GRAPHITE = preload("res://assets/environments/maintenance_jutsu_v1_Maintenance brushed graphite 512.png")
const SIGNAL_CONSOLE_PROP = preload("res://assets/props/signal_console_jutsu.glb")

const ROOM_WIDTH := 24.0 # X: -12.0m to +12.0m (center = 0.0m)
const ROOM_LENGTH := 32.0 # Z: 0.0m to -32.0m (center = -16.0m)
const ROOM_HEIGHT := 7.2 # Y: 0.0m to +7.2m
const WALL_THICKNESS := 0.4

const SAFE_ANCHOR_ENTRY := Vector3(0.0, 0.1, -2.0)
const SAFE_ANCHOR_CATWALK := Vector3(0.0, 3.3, -16.0)
const SAFE_ANCHOR_EXIT := Vector3(0.0, 0.1, -29.0)

var state: RoomState = RoomState.ENTRY_STERILIZATION
var current_anchor: Vector3 = SAFE_ANCHOR_ENTRY
var reduced_motion := false
var audio_muted := false
var player: Node3D

var override_done := false
var gate_open := false

var _gate: StaticBody3D
var _gate_shape: CollisionShape3D
var _gate_closed_y := 1.4
var _gate_open_y := 4.8

var _terminal_body: StaticBody3D
var _terminal_light: OmniLight3D
var _uv_pulse_light: OmniLight3D
var _uv_timer := 0.0

func _ready() -> void:
	_build_room_hull()
	_build_decon_arches()
	_build_quarantine_pods()
	_build_observation_catwalk()
	_build_override_terminal()
	_build_exit_gate()
	preload("res://scripts/environment/room_service_lighting.gd").install(self,Rect2(-12,-32,24,32),7.2)

func _physics_process(delta: float) -> void:
	_update_uv_pulses(delta)
	
	if not player or not is_instance_valid(player):
		return
	
	var pz: float = to_local(player.global_position).z
	var py: float = to_local(player.global_position).y
	
	# Monotonic checkpoint progression
	if pz < -26.0 and gate_open:
		current_anchor = SAFE_ANCHOR_EXIT
	elif pz < -12.0 and py > 2.0:
		if current_anchor != SAFE_ANCHOR_EXIT:
			current_anchor = SAFE_ANCHOR_CATWALK
	elif current_anchor == SAFE_ANCHOR_ENTRY and pz < -6.0:
		state = RoomState.POD_OBSERVATION

func _update_uv_pulses(delta: float) -> void:
	if not _uv_pulse_light:
		return
	_uv_timer += delta
	# Subtle clinical pulse every 3.0s
	var intensity: float = 0.8 + 0.4 * sin(_uv_timer * 2.0)
	_uv_pulse_light.light_energy = intensity

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

func _build_room_hull() -> void:
	var wall_mat := _material(Color(0.25, 0.28, 0.32), 0.2, 0.5)
	wall_mat.albedo_texture = CERAMIC
	wall_mat.uv1_scale = Vector3(3.0, 3.0, 1.0)
	
	var floor_mat := _material(Color(0.16, 0.18, 0.22), 0.6, 0.45)
	floor_mat.albedo_texture = GRAPHITE
	floor_mat.uv1_scale = Vector3(4.0, 4.0, 1.0)
	
	var center_z := -ROOM_LENGTH * 0.5 # -16.0m
	var center_y := ROOM_HEIGHT * 0.5 # 3.6m
	
	# 1. Floor (solid) at Y = 0.0m
	_box("Floor", Vector3(0.0, -WALL_THICKNESS * 0.5, center_z), Vector3(ROOM_WIDTH, WALL_THICKNESS, ROOM_LENGTH), floor_mat, true)
	
	# 2. Ceiling (solid) at Y = 7.2m
	_box("Ceiling", Vector3(0.0, ROOM_HEIGHT + WALL_THICKNESS * 0.5, center_z), Vector3(ROOM_WIDTH, WALL_THICKNESS, ROOM_LENGTH), wall_mat, true)
	
	# 3. West Wall (solid) at X = -12.0m
	_box("WestWall", Vector3(-ROOM_WIDTH * 0.5 - WALL_THICKNESS * 0.5, center_y, center_z), Vector3(WALL_THICKNESS, ROOM_HEIGHT, ROOM_LENGTH), wall_mat, true)
	
	# 4. East Wall (solid) at X = +12.0m
	_box("EastWall", Vector3(ROOM_WIDTH * 0.5 + WALL_THICKNESS * 0.5, center_y, center_z), Vector3(WALL_THICKNESS, ROOM_HEIGHT, ROOM_LENGTH), wall_mat, true)
	
	# 5. South Wall (solid) at Z = 0.0m with Entrance Portal (Width 2.6m x Height 3.2m)
	var south_z := WALL_THICKNESS * 0.5
	# SouthWest: from X = -12.0m to -1.3m (width = 10.7m, center X = -6.65m)
	_box("SouthWallWest", Vector3(-6.65, center_y, south_z), Vector3(10.7, ROOM_HEIGHT, WALL_THICKNESS), wall_mat, true)
	# SouthEast: from X = +1.3m to +12.0m (width = 10.7m, center X = +6.65m)
	_box("SouthWallEast", Vector3(6.65, center_y, south_z), Vector3(10.7, ROOM_HEIGHT, WALL_THICKNESS), wall_mat, true)
	# SouthLintel: above portal from Y = 3.2m to 7.2m (height = 4.0m, center Y = 5.2m, width = 2.6m)
	_box("SouthLintel", Vector3(0.0, 5.2, south_z), Vector3(2.6, 4.0, WALL_THICKNESS), wall_mat, true)
	
	# 6. North Wall (solid) at Z = -32.0m with Exit Blast Gate (Width 2.05m x Height 2.8m)
	var north_z := -ROOM_LENGTH - WALL_THICKNESS * 0.5
	# NorthWest: from X = -12.0m to -1.025m (width = 10.975m, center X = -6.5125m)
	_box("NorthWallWest", Vector3(-6.5125, center_y, north_z), Vector3(10.975, ROOM_HEIGHT, WALL_THICKNESS), wall_mat, true)
	# NorthEast: from X = +1.025m to +12.0m (width = 10.975m, center X = +6.5125m)
	_box("NorthWallEast", Vector3(6.5125, center_y, north_z), Vector3(10.975, ROOM_HEIGHT, WALL_THICKNESS), wall_mat, true)
	# NorthLintel: above exit from Y = 2.8m to 7.2m (height = 4.4m, center Y = 5.0m, width = 2.05m)
	_box("NorthLintel", Vector3(0.0, 5.0, north_z), Vector3(2.05, 4.4, WALL_THICKNESS), wall_mat, true)
	
	# Ambient Clinical Light
	_uv_pulse_light = OmniLight3D.new()
	_uv_pulse_light.name = "ClinicalUVPulseLight"
	_uv_pulse_light.position = Vector3(0.0, 5.5, center_z)
	_uv_pulse_light.light_color = Color(0.85, 0.95, 0.92) # Soft Clinical Teal
	_uv_pulse_light.light_energy = 1.2
	_uv_pulse_light.omni_range = 24.0
	_uv_pulse_light.shadow_enabled = true
	add_child(_uv_pulse_light)

func _build_decon_arches() -> void:
	var frame_mat := _material(Color(0.28, 0.32, 0.36), 0.7, 0.4)
	var emitter_mat := _material(Color(0.45, 0.1, 0.7), 0.2, 0.2, true, Color(0.45, 0.1, 0.7), 2.5)
	
	for i in range(2):
		var arch_z := -3.5 - float(i) * 3.0
		_box("DeconArchPillarL_%d" % i, Vector3(-1.8, 2.0, arch_z), Vector3(0.4, 4.0, 0.4), frame_mat, true)
		_box("DeconArchPillarR_%d" % i, Vector3(1.8, 2.0, arch_z), Vector3(0.4, 4.0, 0.4), frame_mat, true)
		_box("DeconArchLintel_%d" % i, Vector3(0.0, 4.0, arch_z), Vector3(4.0, 0.4, 0.4), frame_mat, true)
		
		# UV Emitter Strip
		_box("UVEmitter_%d" % i, Vector3(0.0, 3.8, arch_z), Vector3(3.2, 0.1, 0.2), emitter_mat, false)

func _build_quarantine_pods() -> void:
	var frame_mat := _material(Color(0.2, 0.24, 0.28), 0.8, 0.3)
	var glass_mat := _material(Color(0.1, 0.3, 0.35, 0.4), 0.1, 0.1, true, Color(0.0, 0.8, 0.9), 0.8)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	var pod_z_positions := [-11.0, -16.0, -21.0]
	for idx in range(pod_z_positions.size()):
		var pz: float = pod_z_positions[idx]
		# Left Pod (X = -6.5m)
		_create_pod("QuarantinePod_L%d" % idx, Vector3(-6.5, 1.4, pz), frame_mat, glass_mat)
		# Right Pod (X = +6.5m)
		_create_pod("QuarantinePod_R%d" % idx, Vector3(6.5, 1.4, pz), frame_mat, glass_mat)

func _create_pod(node_name: String, pos: Vector3, frame_mat: Material, glass_mat: Material) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	
	# Glass cylinder mesh
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.4
	cyl.bottom_radius = 1.4
	cyl.height = 2.8
	mesh.mesh = cyl
	mesh.material_override = glass_mat
	body.add_child(mesh)
	
	# Solid Collision
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape := CylinderShape3D.new()
	shape.radius = 1.4
	shape.height = 2.8
	col.shape = shape
	body.add_child(col)
	
	# Top and Bottom metal rims
	_box("PodBase", Vector3(0.0, -1.35, 0.0), Vector3(3.2, 0.1, 3.2), frame_mat, false).reparent(body, false)
	_box("PodCap", Vector3(0.0, 1.35, 0.0), Vector3(3.2, 0.1, 3.2), frame_mat, false).reparent(body, false)
	
	add_child(body)

func _build_observation_catwalk() -> void:
	var deck_mat := _material(Color(0.22, 0.25, 0.3), 0.75, 0.35)
	var rail_mat := _material(Color(0.14, 0.17, 0.2), 0.9, 0.2)
	
	# Catwalk Bridge at Y = +3.2m spanning across Z = -16.0m (Width 2.4m along Z, Length 18.0m along X)
	_box("ObservationCatwalkDeck", Vector3(0.0, 3.1, -16.0), Vector3(18.0, 0.2, 2.4), deck_mat, true)
	
	# Catwalk Railings
	_box("CatwalkRailNorth", Vector3(0.0, 3.7, -17.15), Vector3(18.0, 1.0, 0.1), rail_mat, true)
	_box("CatwalkRailSouth", Vector3(0.65, 3.7, -14.85), Vector3(16.7, 1.0, 0.1), rail_mat, true)
	
	# Access Stairs from Floor (Y = 0.0m) to Catwalk (Y = 3.2m) on West side (X: -9.0m to -12.0m)
	for i in range(11):
		var step_y := float(i) * 0.29
		var step_z := -9.25 - float(i) * 0.5
		_box("CatwalkStair_%d" % i, Vector3(-8.5, step_y + 0.15, step_z), Vector3(1.6, 0.2, 0.5), deck_mat, false)
	var support = preload("res://scripts/environment/room_path_support.gd")
	support.add_ramp(self, "CatwalkStairSupport", Vector3(-8.5, 0, -9), Vector3(-8.5, 3.2, -14.1), 1.6)
	support.add_ramp(self, "CatwalkStairLanding", Vector3(-8.5,3.2,-14.1), Vector3(-8.5,3.2,-15.3), 1.6, deck_mat)

func _build_override_terminal() -> void:
	var metal_mat := _material(Color(0.2, 0.24, 0.28), 0.7, 0.4)
	var screen_mat := _material(Color(0.05, 0.12, 0.15), 0.0, 0.2, true, Color(0.0, 0.85, 0.9), 1.8)
	
	var terminal_script = preload("res://scripts/environment/quarantine_terminal.gd")
	_terminal_body = terminal_script.new()
	_terminal_body.name = "QuarantineOverrideTerminal"
	_terminal_body.position = Vector3(0.0, 3.2, -16.0) # Centered on Catwalk
	
	var prop := SIGNAL_CONSOLE_PROP.instantiate()
	prop.name = "Prop"
	_terminal_body.add_child(prop)
	
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 1.4, 0.9)
	col.shape = box
	_terminal_body.add_child(col)
	
	# Screen mesh
	var screen := MeshInstance3D.new()
	var s_box := BoxMesh.new()
	s_box.size = Vector3(0.9, 0.6, 0.05)
	screen.mesh = s_box
	screen.position = Vector3(0.0, 0.75, 0.38)
	screen.rotation.x = -0.3
	screen.material_override = screen_mat
	_terminal_body.add_child(screen)
	
	_terminal_light = OmniLight3D.new()
	_terminal_light.name = "TerminalLight"
	_terminal_light.position = Vector3(0.0, 1.2, 0.4)
	_terminal_light.light_color = Color(0.0, 0.85, 0.9)
	_terminal_light.light_energy = 1.4
	_terminal_light.omni_range = 3.5
	_terminal_body.add_child(_terminal_light)
	
	# Interaction Area3D
	var area := Area3D.new()
	area.name = "InteractionArea"
	var area_col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.4
	area_col.shape = sphere
	area.add_child(area_col)
	
	area.body_entered.connect(func(body: Node3D):
		if body.has_method("register_nearby_interactable"):
			body.register_nearby_interactable(_terminal_body)
	)
	area.body_exited.connect(func(body: Node3D):
		if body.has_method("unregister_nearby_interactable"):
			body.unregister_nearby_interactable(_terminal_body)
	)
	_terminal_body.add_child(area)
	
	add_child(_terminal_body)

func _build_exit_gate() -> void:
	var gate_mat := _material(Color(0.2, 0.25, 0.3), 0.9, 0.2, true, Color(0.0, 0.85, 0.9), 0.8)
	
	_gate = StaticBody3D.new()
	_gate.name = "NorthExitBlastGate"
	_gate.position = Vector3(0.0, _gate_closed_y, -32.0)
	
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = Vector3(2.05, 2.8, 0.2)
	mesh.material_override = gate_mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_gate.add_child(mesh)
	
	_gate_shape = CollisionShape3D.new()
	_gate_shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(2.05, 2.8, 0.2)
	_gate_shape.shape = box
	_gate.add_child(_gate_shape)
	
	add_child(_gate)

func trigger_interaction(_interactor: Node = null) -> Dictionary:
	return execute_quarantine_override()

func execute_quarantine_override() -> Dictionary:
	if override_done:
		return {"success": true, "already_overridden": true}
	
	override_done = true
	state = RoomState.OVERRIDE_ACTIVE
	quarantine_override_initiated.emit()
	
	_open_exit_gate()
	return {"success": true, "cleared": true}

func _open_exit_gate() -> void:
	if gate_open:
		return
	gate_open = true
	state = RoomState.QUARANTINE_CLEARED
	quarantine_cleared.emit()
	exit_gate_opened.emit()
	
	if reduced_motion:
		if _gate:
			_gate.position.y = _gate_open_y
		if _gate_shape:
			_gate_shape.set_deferred("disabled", true)
		return
	
	if _gate:
		var tween := create_tween()
		tween.tween_property(_gate, "position:y", _gate_open_y, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func():
			if _gate_shape:
				_gate_shape.set_deferred("disabled", true)
		)

func get_safe_anchor() -> Vector3:
	return current_anchor

func get_state() -> Dictionary:
	return {
		"state": state,
		"current_anchor": current_anchor,
		"override_done": override_done,
		"gate_open": gate_open,
		"gate_pos_y": _gate.position.y if _gate else _gate_closed_y,
		"gate_col_disabled": _gate_shape.disabled if _gate_shape else false
	}

func restore_state(data: Dictionary) -> void:
	if data.has("state"):
		state = data["state"]
	if data.has("current_anchor"):
		current_anchor = data["current_anchor"]
	if data.has("override_done"):
		override_done = data["override_done"]
	if data.has("gate_open"):
		gate_open = data["gate_open"]
	if _gate and data.has("gate_pos_y"):
		_gate.position.y = data["gate_pos_y"]
	if _gate_shape and data.has("gate_col_disabled"):
		_gate_shape.disabled = data["gate_col_disabled"]
