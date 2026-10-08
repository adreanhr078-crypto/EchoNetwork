extends Node3D

## Room 9: The Mirror Chamber & Central Security Surveillance Hub
## Connects from Buffer 8-9 (Decon-to-Surveillance Conduit) South Entrance at Z = 0.0m
## to Room 10 (Dr. Kinja's Observation Lab) North Exit Blast Gate at Z = -36.0m.
## Enforces the Anti-Crowding and Quality Gate Invariants:
## - Watertight Hull (28.0m x 36.0m x 8.0m), solid collision envelope, zero light bleed.
## - Narrative & Gameplay Flow:
##   * Panopticon Discovery: Massive North monitor wall broadcasting live feeds of Echo's escape.
##   * Two-Way Surveillance Mirror: Reflective glass revealing Echo's exhausted human state.
##   * Kinetic High-Speed Traversal: Elevated catwalks, slide-under horizontal lasers (height 1.2m).
##   * Elevated Central Command Dais at Y = +2.4m with Master Security Override Terminal.
##   * Lockdown Override unlocking the North Exit Blast Gate to Dr. Kinja's Lab.
## - 3-Tier Safe Anchors: Entry, Command Dais, Exit Gantry.
## - Full accessibility: reduced motion, audio mute, durable state save/restore.

signal mirror_examined
signal lockdown_override_initiated
signal security_cleared
signal exit_gate_opened
signal retry_requested(anchor: Vector3)

enum RoomState {
	ENTRY_LOBBY,
	MIRROR_DISCOVERY,
	COMMAND_DAIS,
	OVERRIDE_ACTIVE,
	SECURITY_CLEARED,
	EXIT_CORRIDOR
}

const CERAMIC = preload("res://assets/environments/maintenance_jutsu_v1_Maintenance ceramic grain 512.png")
const GRAPHITE = preload("res://assets/environments/maintenance_jutsu_v1_Maintenance brushed graphite 512.png")
const SIGNAL_CONSOLE_PROP = preload("res://assets/props/signal_console_jutsu.glb")

const ROOM_WIDTH := 28.0 # X: -14.0m to +14.0m (center = 0.0m)
const ROOM_LENGTH := 36.0 # Z: 0.0m to -36.0m (center = -18.0m)
const ROOM_HEIGHT := 8.0 # Y: 0.0m to +8.0m
const WALL_THICKNESS := 0.4

const SAFE_ANCHOR_ENTRY := Vector3(0.0, 0.1, -2.0)
const SAFE_ANCHOR_COMMAND := Vector3(0.0, 2.5, -18.0)
const SAFE_ANCHOR_EXIT := Vector3(0.0, 0.1, -33.0)

var state: RoomState = RoomState.ENTRY_LOBBY
var current_anchor: Vector3 = SAFE_ANCHOR_ENTRY
var reduced_motion := false
var audio_muted := false
var player: Node3D
var presentation_language:="ar"
var _telemetry:Node3D
var _telemetry_signature:=""

func set_presentation_language(language:String) -> void:
	presentation_language="en" if language=="en" else "ar"
	_update_telemetry()

func _update_telemetry() -> void:
	if not _telemetry: return
	var signature:="%s/%s/%s" % [presentation_language,mirror_inspected,override_done]
	if signature==_telemetry_signature: return
	_telemetry_signature=signature
	preload("res://scripts/environment/surveillance_display.gd").update(_telemetry,presentation_language,mirror_inspected,override_done)

var mirror_inspected := false
var override_done := false
var gate_open := false

var _gate: StaticBody3D
var _gate_shape: CollisionShape3D
var _gate_closed_y := 1.4
var _gate_open_y := 4.8

var _terminal_body: StaticBody3D
var _terminal_light: OmniLight3D
var _ambient_amber_light: OmniLight3D
var _laser_beams: Array[MeshInstance3D] = []

func _ready() -> void:
	_build_room_hull()
	_build_panoramic_monitor_wall()
	_build_surveillance_mirror()
	_build_elevated_command_dais()
	_build_laser_security_grid()
	_build_master_terminal()
	_build_exit_gate()
	preload("res://scripts/environment/room_service_lighting.gd").install(self, Rect2(-14,-36,28,36),8.0)

func _physics_process(_delta: float) -> void:
	_update_telemetry()
	if not player or not is_instance_valid(player):
		return
	
	var pz: float = to_local(player.global_position).z
	var py: float = to_local(player.global_position).y
	
	# Monotonic safe anchor progression
	if pz < -30.0 and gate_open:
		current_anchor = SAFE_ANCHOR_EXIT
	elif pz < -14.0 and py > 1.8:
		if current_anchor != SAFE_ANCHOR_EXIT:
			current_anchor = SAFE_ANCHOR_COMMAND
	elif current_anchor == SAFE_ANCHOR_ENTRY and pz < -6.0:
		state = RoomState.MIRROR_DISCOVERY

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
	var wall_mat := _material(Color(0.58, 0.62, 0.68), 0.1, 0.8)
	wall_mat.albedo_texture = CERAMIC
	wall_mat.uv1_scale = Vector3(4.0, 4.0, 1.0)
	
	var floor_mat := _material(Color(0.38, 0.43, 0.5), 0.2, 0.7)
	floor_mat.albedo_texture = GRAPHITE
	floor_mat.uv1_scale = Vector3(5.0, 5.0, 1.0)
	
	var center_z := -ROOM_LENGTH * 0.5 # -18.0m
	var center_y := ROOM_HEIGHT * 0.5 # 4.0m
	
	# 1. Floor (solid) at Y = 0.0m
	_box("Floor", Vector3(0.0, -WALL_THICKNESS * 0.5, center_z), Vector3(ROOM_WIDTH, WALL_THICKNESS, ROOM_LENGTH), floor_mat, true)
	
	# 2. Ceiling (solid) at Y = 8.0m
	_box("Ceiling", Vector3(0.0, ROOM_HEIGHT + WALL_THICKNESS * 0.5, center_z), Vector3(ROOM_WIDTH, WALL_THICKNESS, ROOM_LENGTH), wall_mat, true)
	
	# 3. West Wall (solid) at X = -14.0m
	_box("WestWall", Vector3(-ROOM_WIDTH * 0.5 - WALL_THICKNESS * 0.5, center_y, center_z), Vector3(WALL_THICKNESS, ROOM_HEIGHT, ROOM_LENGTH), wall_mat, true)
	
	# 4. East Wall (solid) at X = +14.0m
	_box("EastWall", Vector3(ROOM_WIDTH * 0.5 + WALL_THICKNESS * 0.5, center_y, center_z), Vector3(WALL_THICKNESS, ROOM_HEIGHT, ROOM_LENGTH), wall_mat, true)
	
	# 5. South Wall (solid) at Z = 0.0m with Entrance Portal (Width 2.6m x Height 3.2m)
	var south_z := WALL_THICKNESS * 0.5
	# SouthWest: from X = -14.0m to -1.3m (width = 12.7m, center X = -7.65m)
	_box("SouthWallWest", Vector3(-7.65, center_y, south_z), Vector3(12.7, ROOM_HEIGHT, WALL_THICKNESS), wall_mat, true)
	# SouthEast: from X = +1.3m to +14.0m (width = 12.7m, center X = +7.65m)
	_box("SouthWallEast", Vector3(7.65, center_y, south_z), Vector3(12.7, ROOM_HEIGHT, WALL_THICKNESS), wall_mat, true)
	# SouthLintel: above portal from Y = 3.2m to 8.0m (height = 4.8m, center Y = 5.6m, width = 2.6m)
	_box("SouthLintel", Vector3(0.0, 5.6, south_z), Vector3(2.6, 4.8, WALL_THICKNESS), wall_mat, true)
	
	# 6. North Wall (solid) at Z = -36.0m with Exit Blast Gate (Width 2.05m x Height 2.8m)
	var north_z := -ROOM_LENGTH - WALL_THICKNESS * 0.5
	# NorthWest: from X = -14.0m to -1.025m (width = 12.975m, center X = -7.5125m)
	_box("NorthWallWest", Vector3(-7.5125, center_y, north_z), Vector3(12.975, ROOM_HEIGHT, WALL_THICKNESS), wall_mat, true)
	# NorthEast: from X = +1.025m to +14.0m (width = 12.975m, center X = +7.5125m)
	_box("NorthWallEast", Vector3(7.5125, center_y, north_z), Vector3(12.975, ROOM_HEIGHT, WALL_THICKNESS), wall_mat, true)
	# NorthLintel: above exit from Y = 2.8m to 8.0m (height = 5.2m, center Y = 5.4m, width = 2.05m)
	_box("NorthLintel", Vector3(0.0, 5.4, north_z), Vector3(2.05, 5.2, WALL_THICKNESS), wall_mat, true)
	
	# Ambient Surveillance Amber Light
	_ambient_amber_light = OmniLight3D.new()
	_ambient_amber_light.name = "SurveillanceAmberLight"
	_ambient_amber_light.position = Vector3(0.0, 6.0, center_z)
	_ambient_amber_light.light_color = Color(1.0, 0.65, 0.15) # Surveillance Amber
	_ambient_amber_light.light_energy = 0.4
	_ambient_amber_light.omni_range = 28.0
	_ambient_amber_light.shadow_enabled = true
	add_child(_ambient_amber_light)

func _build_panoramic_monitor_wall() -> void:
	# Panoramic screen bank along North Wall at Z = -35.6m (Width 20.0m x Height 5.0m at Y = 4.5m)
	var screen_mat := preload("res://scripts/environment/surveillance_display.gd").material()
	var frame_mat := _material(Color(0.15, 0.18, 0.22), 0.8, 0.3)
	
	_box("MonitorWallFrame", Vector3(0.0, 4.5, -35.7), Vector3(22.0, 5.4, 0.2), frame_mat, false)
	_box("MonitorWallScreens", Vector3(0.0, 4.5, -35.6), Vector3(21.0, 4.8, 0.05), screen_mat, false)
	
	_telemetry=preload("res://scripts/environment/surveillance_display.gd").populate(self,Vector3(0,4.5,-35.5),20,4.5,"SURVEILLANCE / LOCAL TELEMETRY")
	_update_telemetry()

func _build_surveillance_mirror() -> void:
	# The Two-Way Surveillance Mirror Chamber (East side at X = 8.5m, Z = -10.0m)
	var mirror_frame_mat := _material(Color(0.2, 0.24, 0.28), 0.8, 0.3)
	
	var mirror_node := Node3D.new()
	mirror_node.name = "SurveillanceMirrorChamber"
	mirror_node.position = Vector3(8.5, 1.6, -10.0)
	
	_box("MirrorTopFrame",Vector3(8.5,3.1,-10),Vector3(0.3,0.2,4.4),mirror_frame_mat,true)
	_box("MirrorBottomFrame",Vector3(8.5,0.1,-10),Vector3(0.3,0.2,4.4),mirror_frame_mat,true)
	for z in [-12.1,-7.9]:
		_box("MirrorSideFrame",Vector3(8.5,1.6,z),Vector3(0.3,2.8,0.2),mirror_frame_mat,true)
	var backing := StaticBody3D.new()
	backing.name = "MirrorBacking"
	backing.position = Vector3(8.5,1.6,-10)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.12,2.8,4.0)
	collision.shape = shape
	backing.add_child(collision)
	add_child(backing)
	var glass := preload("res://scripts/environment/planar_inspection_mirror.gd").new()
	glass.position.x = -0.17
	mirror_node.add_child(glass)
	
	# Interaction Area3D for examining reflection
	var area := Area3D.new()
	area.name = "MirrorInspectArea"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 2.8, 4.0)
	col.shape = box
	area.add_child(col)
	
	area.body_entered.connect(func(body: Node3D):
		if body == player and not mirror_inspected:
			mirror_inspected = true
			mirror_examined.emit()
	)
	mirror_node.add_child(area)
	add_child(mirror_node)

func _build_elevated_command_dais() -> void:
	var deck_mat := _material(Color(0.22, 0.25, 0.3), 0.8, 0.35)
	var rail_mat := _material(Color(0.14, 0.17, 0.2), 0.9, 0.2)
	
	# Dais Platform: centered at X = 0.0m, Z = -18.0m, Y = 2.4m (Size: 8.0m x 8.0m x 0.3m)
	_box("CommandDaisDeck", Vector3(0.0, 2.25, -18.0), Vector3(8.0, 0.3, 8.0), deck_mat, true)
	
	# Railings with openings for East and West stairs
	_box("DaisRailNorth", Vector3(0.0, 2.85, -21.95), Vector3(8.0, 1.0, 0.1), rail_mat, true)
	_box("DaisRailSouth", Vector3(0.0, 2.85, -14.05), Vector3(8.0, 1.0, 0.1), rail_mat, true)
	_box("DaisRailWestEdge", Vector3(-3.95, 2.85, -19.5), Vector3(0.1, 1.0, 3.0), rail_mat, true)
	_box("DaisRailEastEdge", Vector3(3.95, 2.85, -19.5), Vector3(0.1, 1.0, 3.0), rail_mat, true)
	
	# Twin Access Stairs (West Stair & East Stair)
	for i in range(8):
		var step_y := float(7 - i) * 0.3
		# West Stair descending from X = -4.0m to -7.2m
		var wx := -4.65 - float(i) * 0.45
		_box("WestStair_%d" % i, Vector3(wx, step_y + 0.15, -16.6), Vector3(0.5, 0.2, 2.2), deck_mat, false)
		# East Stair descending from X = +4.0m to +7.2m
		var ex := 4.65 + float(i) * 0.45
		_box("EastStair_%d" % i, Vector3(ex, step_y + 0.15, -16.6), Vector3(0.5, 0.2, 2.2), deck_mat, false)
	var support = preload("res://scripts/environment/room_path_support.gd")
	support.add_ramp(self, "WestStairSupport", Vector3(-7.8, 0, -16.6), Vector3(-4.5, 2.4, -16.6), 2.2)
	support.add_ramp(self, "EastStairSupport", Vector3(7.8, 0, -16.6), Vector3(4.5, 2.4, -16.6), 2.2)
	support.add_ramp(self, "WestStairLanding", Vector3(-4.5,2.4,-16.6), Vector3(-3.5,2.4,-16.6),2.2,deck_mat)
	support.add_ramp(self, "EastStairLanding", Vector3(4.5,2.4,-16.6), Vector3(3.5,2.4,-16.6),2.2,deck_mat)

func _build_laser_security_grid() -> void:
	var laser_mat := _material(Color(1.0, 0.1, 0.1, 0.4), 0.0, 0.1, true, Color(1.0, 0.0, 0.0), 3.0)
	laser_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# Horizontal laser beams set at height Y = 1.2m (enabling slide-under parkour maneuver)
	var z_positions := [-8.0, -12.0, -26.0, -30.0]
	for idx in range(z_positions.size()):
		var lz: float = z_positions[idx]
		var beam := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.03
		cyl.bottom_radius = 0.03
		cyl.height = 14.0
		beam.mesh = cyl
		beam.rotation.z = PI * 0.5
		beam.position = Vector3(0.0, 1.2, lz)
		beam.material_override = laser_mat
		add_child(beam)
		_laser_beams.append(beam)

func _build_master_terminal() -> void:
	var metal_mat := _material(Color(0.2, 0.24, 0.28), 0.7, 0.4)
	var screen_mat := preload("res://scripts/environment/surveillance_display.gd").material()
	
	var terminal_script = preload("res://scripts/environment/mirror_terminal.gd")
	_terminal_body = terminal_script.new()
	_terminal_body.name = "MasterSecurityTerminal"
	_terminal_body.position = Vector3(0.0, 2.4, -18.0) # On the Dais
	
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
	_terminal_light.light_color = Color(1.0, 0.65, 0.1)
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
	var gate_mat := _material(Color(0.2, 0.25, 0.3), 0.9, 0.2, true, Color(1.0, 0.6, 0.0), 0.8)
	
	_gate = StaticBody3D.new()
	_gate.name = "SurveillanceExitGate"
	_gate.position = Vector3(0.0, _gate_closed_y, -36.0)
	
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
	return execute_lockdown_override()

func execute_lockdown_override() -> Dictionary:
	if override_done:
		return {"success": true, "already_overridden": true}
	
	override_done = true
	state = RoomState.OVERRIDE_ACTIVE
	lockdown_override_initiated.emit()
	
	# Disable security laser beams
	for beam in _laser_beams:
		beam.visible = false
	
	_open_exit_gate()
	return {"success": true, "cleared": true}

func _open_exit_gate() -> void:
	if gate_open:
		return
	gate_open = true
	state = RoomState.SECURITY_CLEARED
	security_cleared.emit()
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
		"mirror_inspected": mirror_inspected,
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
	if data.has("mirror_inspected"):
		mirror_inspected = data["mirror_inspected"]
	if data.has("override_done"):
		override_done = data["override_done"]
	if data.has("gate_open"):
		gate_open = data["gate_open"]
	if _gate and data.has("gate_pos_y"):
		_gate.position.y = data["gate_pos_y"]
	if _gate_shape and data.has("gate_col_disabled"):
		_gate_shape.disabled = data["gate_col_disabled"]
	if override_done:
		for beam in _laser_beams:
			beam.visible = false
