extends Node3D

## Room 7: Core Reactor & Power Station (Sector 11 Geothermal Tokamak & Energy Substation)
## Connects from Buffer 6-7 (Archive-to-Reactor Conduit) South Entrance at Z = 0.0m
## to Room 8 North Exit Blast Gate at Z = -44.0m.
## Enforces the Anti-Crowding and Quality Gate Invariants:
## - Watertight Hull (36.0m x 44.0m x 16.0m), Y: -10.0m abyss to +6.0m ceiling.
## - Vertical Traversal: Enters at Y = -4.0m, navigates turbine catwalks, solves dual circuit breakers
##   to raise the central hydraulic bridge, and exits at Y = 0.0m.
## - Electrical Hazard Volumes: Pure Area3D triggers (NEVER StaticBody3D) with 0.8s amber telegraph,
##   1.0s active discharge, and 2.5s safe recovery rhythm.
## - Plasma Abyss Recovery Trigger: Area3D at Y <= -8.5m resetting player seamlessly to safe anchor.
## - 3-Tier Safe Anchors: Alpha (Entry), Beta (Mid-Transformer), Gamma (Exit Gantry).
## - Interactive Terminals: Circuit Breakers A & B implementing trigger_interaction(player).
## - Full accessibility: reduced motion, audio mute, durable state save/restore.

signal breaker_a_activated
signal breaker_b_activated
signal hydraulic_bridge_extended
signal exit_gate_opened
signal retry_requested(anchor: Vector3)
signal hazard_triggered(hazard_name: String)

enum RoomState {
	ENTRY_BALCONY,
	TURBINE_EXPLORATION,
	BREAKER_A_ACTIVE,
	BREAKER_B_ACTIVE,
	BRIDGE_EXTENDED,
	EXIT_GANTRY
}

const CERAMIC = preload("res://assets/environments/maintenance_jutsu_v1_Maintenance ceramic grain 512.png")
const GRAPHITE = preload("res://assets/environments/maintenance_jutsu_v1_Maintenance brushed graphite 512.png")
const SIGNAL_CONSOLE_PROP = preload("res://assets/props/signal_console_jutsu.glb")
const CONDUIT_PROP = preload("res://assets/props/sector11-conduit-v1.glb")

const ROOM_WIDTH := 36.0 # X: -18.0m to +18.0m (center = 0.0m)
const ROOM_LENGTH := 44.0 # Z: 0.0m to -44.0m (center = -22.0m)
const ROOM_HEIGHT := 16.0 # Y: -10.0m to +6.0m
const FLOOR_Y := -10.0
const CEILING_Y := 6.0
const WALL_THICKNESS := 0.5

const SAFE_ANCHOR_ALPHA := Vector3(0.0, -3.9, -2.5) # Entry Balcony
const SAFE_ANCHOR_BETA := Vector3(-11.0, -1.9, -16.0) # West Transformer
const SAFE_ANCHOR_GAMMA := Vector3(0.0, 0.1, -41.0) # North Exit Gantry

var state: RoomState = RoomState.ENTRY_BALCONY
var current_anchor: Vector3 = SAFE_ANCHOR_ALPHA
var reduced_motion := false
var audio_muted := false
var player: Node3D

var breaker_a_done := false
var breaker_b_done := false
var bridge_extended := false
var gate_open := false

# Hazard Timing
var hazard_phase_timer := 0.0
const TELEGRAPH_TIME := 0.8
const DISCHARGE_TIME := 1.0
const SAFE_TIME := 2.5
const CYCLE_TIME := TELEGRAPH_TIME + DISCHARGE_TIME + SAFE_TIME # 4.3s

var _breaker_a_console: Node3D
var _breaker_b_console: Node3D
var _hydraulic_bridge: StaticBody3D
var _hydraulic_bridge_shape: CollisionShape3D
var _bridge_retracted_y := -3.5
var _bridge_extended_y := 0.0

var _gate: StaticBody3D
var _gate_shape: CollisionShape3D
var _gate_closed_y := 1.4
var _gate_open_y := 4.8

var _hazard_a_mesh: MeshInstance3D
var _hazard_a_area: Area3D
var _hazard_a_light: OmniLight3D

var _hazard_b_mesh: MeshInstance3D
var _hazard_b_area: Area3D
var _hazard_b_light: OmniLight3D

var _reactor_core_light: OmniLight3D
var _abyss_recovery_area: Area3D

func _ready() -> void:
	_build_room_hull()
	_build_entry_balcony()
	_build_reactor_core()
	_build_west_turbine_complex()
	_build_east_capacitor_complex()
	_build_hydraulic_bridge()
	_build_exit_gantry()
	_build_hazard_volumes()
	_build_abyss_kill_zone()
	_build_consoles()

func _physics_process(delta: float) -> void:
	_update_hazard_cycles(delta)
	
	if not player or not is_instance_valid(player):
		return
	
	# Update active safe anchor based on player progression (monotonic checkpoints)
	var pz: float = to_local(player.global_position).z
	var py: float = to_local(player.global_position).y
	
	if pz < -36.0 and bridge_extended:
		current_anchor = SAFE_ANCHOR_GAMMA
	elif pz < -14.0 and py > -3.0:
		if current_anchor != SAFE_ANCHOR_GAMMA:
			current_anchor = SAFE_ANCHOR_BETA

func _update_hazard_cycles(delta: float) -> void:
	hazard_phase_timer += delta
	if hazard_phase_timer >= CYCLE_TIME:
		hazard_phase_timer -= CYCLE_TIME
	
	var is_telegraph := hazard_phase_timer < TELEGRAPH_TIME
	var is_discharge := hazard_phase_timer >= TELEGRAPH_TIME and hazard_phase_timer < (TELEGRAPH_TIME + DISCHARGE_TIME)
	
	# Alternating phases: Phase A active during first half, Phase B offset by 2.15s
	var phase_b_timer := fmod(hazard_phase_timer + CYCLE_TIME * 0.5, CYCLE_TIME)
	var b_telegraph := phase_b_timer < TELEGRAPH_TIME
	var b_discharge := phase_b_timer >= TELEGRAPH_TIME and phase_b_timer < (TELEGRAPH_TIME + DISCHARGE_TIME)
	
	_update_hazard_visuals(_hazard_a_mesh, _hazard_a_light, _hazard_a_area, is_telegraph, is_discharge)
	_update_hazard_visuals(_hazard_b_mesh, _hazard_b_light, _hazard_b_area, b_telegraph, b_discharge)
	
	if is_discharge and _hazard_a_area:
		for b in _hazard_a_area.get_overlapping_bodies():
			_on_hazard_entered("HazardA", b)
	if b_discharge and _hazard_b_area:
		for b in _hazard_b_area.get_overlapping_bodies():
			_on_hazard_entered("HazardB", b)

func _update_hazard_visuals(mesh: MeshInstance3D, light: OmniLight3D, area: Area3D, telegraph: bool, discharge: bool) -> void:
	if not mesh or not light or not area:
		return
	
	var mat := mesh.material_override as StandardMaterial3D
	if not mat:
		return
	
	if discharge:
		mat.emission_enabled = true
		mat.emission = Color(0.0, 0.9, 1.0) # Cold Cyan Plasma
		mat.emission_energy_multiplier = 3.5
		light.light_color = Color(0.0, 0.9, 1.0)
		light.light_energy = 3.0
		area.monitoring = true
	elif telegraph:
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.7, 0.1) # Warning Amber
		mat.emission_energy_multiplier = 1.2
		light.light_color = Color(1.0, 0.7, 0.1)
		light.light_energy = 1.0
		area.monitoring = false
	else:
		mat.emission_enabled = false
		light.light_energy = 0.05
		area.monitoring = false

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
	var wall_mat := _material(Color(0.18, 0.2, 0.24), 0.3, 0.6)
	wall_mat.albedo_texture = CERAMIC
	wall_mat.uv1_scale = Vector3(4.0, 4.0, 1.0)
	
	var floor_mat := _material(Color(0.1, 0.12, 0.15), 0.7, 0.4)
	floor_mat.albedo_texture = GRAPHITE
	floor_mat.uv1_scale = Vector3(6.0, 6.0, 1.0)
	
	var center_z := -ROOM_LENGTH * 0.5 # -22.0m
	var hull_height := CEILING_Y - FLOOR_Y # 16.0m
	var center_y := FLOOR_Y + hull_height * 0.5 # -2.0m
	
	# 1. Abyss Base Floor (Y = -10.0m)
	_box("AbyssFloor", Vector3(0.0, FLOOR_Y - WALL_THICKNESS * 0.5, center_z), Vector3(ROOM_WIDTH, WALL_THICKNESS, ROOM_LENGTH), floor_mat, true)
	
	# 2. Ceiling (Y = +6.0m)
	_box("Ceiling", Vector3(0.0, CEILING_Y + WALL_THICKNESS * 0.5, center_z), Vector3(ROOM_WIDTH, WALL_THICKNESS, ROOM_LENGTH), wall_mat, true)
	
	# 3. West Wall (X = -18.0m)
	_box("WestWall", Vector3(-ROOM_WIDTH * 0.5 - WALL_THICKNESS * 0.5, center_y, center_z), Vector3(WALL_THICKNESS, hull_height, ROOM_LENGTH), wall_mat, true)
	
	# 4. East Wall (X = +18.0m)
	_box("EastWall", Vector3(ROOM_WIDTH * 0.5 + WALL_THICKNESS * 0.5, center_y, center_z), Vector3(WALL_THICKNESS, hull_height, ROOM_LENGTH), wall_mat, true)
	
	# 5. South Wall (Z = 0.0m) with Entrance Portal (Width 2.6m x Height 3.2m at Y = -4.0m to -0.8m)
	# South Portal: X = -1.3m to +1.3m, Y = -4.0m to -0.8m
	var south_z := WALL_THICKNESS * 0.5
	# SouthWest: from X = -18.0m to -1.3m (width = 16.7m, center X = -9.65m)
	_box("SouthWallWest", Vector3(-9.65, center_y, south_z), Vector3(16.7, hull_height, WALL_THICKNESS), wall_mat, true)
	# SouthEast: from X = +1.3m to +18.0m (width = 16.7m, center X = +9.65m)
	_box("SouthWallEast", Vector3(9.65, center_y, south_z), Vector3(16.7, hull_height, WALL_THICKNESS), wall_mat, true)
	# SouthUnder: below portal from Y = -10.0m to -4.0m (height = 6.0m, center Y = -7.0m, width = 2.6m)
	_box("SouthUnderPortal", Vector3(0.0, -7.0, south_z), Vector3(2.6, 6.0, WALL_THICKNESS), wall_mat, true)
	# SouthLintel: above portal from Y = -0.8m to +6.0m (height = 6.8m, center Y = 2.6m, width = 2.6m)
	_box("SouthLintel", Vector3(0.0, 2.6, south_z), Vector3(2.6, 6.8, WALL_THICKNESS), wall_mat, true)
	
	# 6. North Wall (Z = -44.0m) with Exit Blast Gate (Width 2.05m x Height 2.8m at Y = 0.0m to +2.8m)
	var north_z := -ROOM_LENGTH - WALL_THICKNESS * 0.5
	# NorthWest: from X = -18.0m to -1.025m (width = 16.975m, center X = -9.5125m)
	_box("NorthWallWest", Vector3(-9.5125, center_y, north_z), Vector3(16.975, hull_height, WALL_THICKNESS), wall_mat, true)
	# NorthEast: from X = +1.025m to +18.0m (width = 16.975m, center X = +9.5125m)
	_box("NorthWallEast", Vector3(9.5125, center_y, north_z), Vector3(16.975, hull_height, WALL_THICKNESS), wall_mat, true)
	# NorthUnder: below exit from Y = -10.0m to 0.0m (height = 10.0m, center Y = -5.0m, width = 2.05m)
	_box("NorthUnderGate", Vector3(0.0, -5.0, north_z), Vector3(2.05, 10.0, WALL_THICKNESS), wall_mat, true)
	# NorthLintel: above exit from Y = 2.8m to 6.0m (height = 3.2m, center Y = 4.4m, width = 2.05m)
	_box("NorthLintel", Vector3(0.0, 4.4, north_z), Vector3(2.05, 3.2, WALL_THICKNESS), wall_mat, true)

func _build_entry_balcony() -> void:
	var deck_mat := _material(Color(0.2, 0.24, 0.3), 0.8, 0.3)
	var rail_mat := _material(Color(0.12, 0.15, 0.18), 0.9, 0.2)
	
	# Entry Balcony Deck: from Z = 0.0m to -6.0m, X = -3.5m to +3.5m, Y = -4.0m
	_box("EntryBalconyDeck", Vector3(0.0, -4.1, -3.0), Vector3(7.0, 0.2, 6.0), deck_mat, true)
	
	# Balcony Railings
	_box("EntryBalconyRailWest", Vector3(-3.45, -3.5, -3.0), Vector3(0.1, 1.0, 6.0), rail_mat, true)
	_box("EntryBalconyRailEast", Vector3(3.45, -3.5, -3.0), Vector3(0.1, 1.0, 6.0), rail_mat, true)
	_box("EntryBalconyRailNorthL", Vector3(-2.25, -3.5, -5.95), Vector3(2.5, 1.0, 0.1), rail_mat, true)
	_box("EntryBalconyRailNorthR", Vector3(2.25, -3.5, -5.95), Vector3(2.5, 1.0, 0.1), rail_mat, true)
	
	# Catwalk ramp leading down from Balcony to West Turbine at Y = -2.0m (stairs/steps)
	for i in range(8):
		var step_x := -3.5 - float(i) * 0.9
		var step_y := -4.0 + float(i) * 0.25 # Ascending to -2.0m
		var step_z := -6.0 - float(i) * 1.0
		_box("BalconyStair_%d" % i, Vector3(step_x, step_y - 0.1, step_z), Vector3(1.6, 0.2, 1.2), deck_mat, true)

func _build_reactor_core() -> void:
	# Central Tokamak Core at X = 0.0m, Z = -22.0m, Y = -10.0m to +4.0m (14m tall)
	var core_node := Node3D.new()
	core_node.name = "ReactorCore"
	core_node.position = Vector3(0.0, -3.0, -22.0)
	
	var core_mat := _material(Color(0.1, 0.12, 0.15), 0.9, 0.2)
	var plasma_mat := _material(Color(0.0, 0.9, 1.0), 0.1, 0.1, true, Color(0.0, 0.9, 1.0), 4.0)
	
	# Central cylinder mesh
	var col_body := StaticBody3D.new()
	col_body.name = "CoreBody"
	var cyl_mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 4.0
	cyl.bottom_radius = 4.8
	cyl.height = 14.0
	cyl_mesh.mesh = cyl
	cyl_mesh.material_override = core_mat
	col_body.add_child(cyl_mesh)
	
	var cyl_col := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 4.8
	cyl_shape.height = 14.0
	cyl_col.shape = cyl_shape
	col_body.add_child(cyl_col)
	core_node.add_child(col_body)
	
	# Plasma Ring Emitters
	for i in range(3):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 4.8
		torus.outer_radius = 5.4
		ring.mesh = torus
		ring.position = Vector3(0.0, -4.0 + float(i) * 3.5, 0.0)
		ring.material_override = plasma_mat
		core_node.add_child(ring)
	
	# Central Core Light
	_reactor_core_light = OmniLight3D.new()
	_reactor_core_light.name = "ReactorCoreLight"
	_reactor_core_light.position = Vector3(0.0, 0.0, 0.0)
	_reactor_core_light.light_color = Color(0.0, 0.9, 1.0)
	_reactor_core_light.light_energy = 4.5
	_reactor_core_light.omni_range = 28.0
	_reactor_core_light.shadow_enabled = true
	core_node.add_child(_reactor_core_light)
	
	add_child(core_node)

func _build_west_turbine_complex() -> void:
	var metal_mat := _material(Color(0.22, 0.25, 0.28), 0.7, 0.4)
	
	# West Platform: X = -11.0m, Z = -16.0m, Y = -2.0m (Size: 6.0m x 8.0m)
	_box("WestPlatform", Vector3(-11.0, -2.1, -16.0), Vector3(6.0, 0.2, 8.0), metal_mat, true)
	
	# Climbable Conduit Pipes along West Wall
	var pipe := CONDUIT_PROP.instantiate()
	pipe.name = "WestConduitProp"
	pipe.position = Vector3(-13.5, -2.0, -16.0)
	pipe.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	add_child(pipe)

func _build_east_capacitor_complex() -> void:
	var metal_mat := _material(Color(0.22, 0.25, 0.28), 0.7, 0.4)
	var rail_mat := _material(Color(0.18, 0.2, 0.22), 0.8, 0.3)
	
	# East Platform: X = +11.0m, Z = -28.0m, Y = -2.0m (Size: 6.0m x 8.0m)
	_box("EastPlatform", Vector3(11.0, -2.1, -28.0), Vector3(6.0, 0.2, 8.0), metal_mat, true)
	
	# Secondary walkway linking East and North Gantry
	_box("EastNorthWalkway", Vector3(11.0, -1.0, -36.0), Vector3(2.4, 0.2, 8.0), metal_mat, true)
	
	# Connector Gantry spanning from East walkway to Exit Gantry (X = +11.0m to +4.0m at Z = -40.0m, Y = 0.0m)
	_box("EastToExitWalkway", Vector3(7.5, -0.1, -40.0), Vector3(7.0, 0.2, 2.4), metal_mat, true)
	_box("EastToExitRailNorth", Vector3(7.5, 0.5, -41.15), Vector3(7.0, 1.0, 0.1), rail_mat, true)
	_box("EastToExitRailSouth", Vector3(7.5, 0.5, -38.85), Vector3(7.0, 1.0, 0.1), rail_mat, true)

func _build_hydraulic_bridge() -> void:
	var bridge_mat := _material(Color(0.25, 0.28, 0.35), 0.85, 0.3)
	
	# Central Bridge spanning from West Platform to East Platform / North Gantry
	# Spanning across Z = -22.0m, width 3.2m, length 14.0m
	_hydraulic_bridge = StaticBody3D.new()
	_hydraulic_bridge.name = "HydraulicBridge"
	_hydraulic_bridge.position = Vector3(0.0, _bridge_retracted_y, -22.0)
	
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = Vector3(14.0, 0.4, 3.2)
	mesh.material_override = bridge_mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_hydraulic_bridge.add_child(mesh)
	
	_hydraulic_bridge_shape = CollisionShape3D.new()
	_hydraulic_bridge_shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(14.0, 0.4, 3.2)
	_hydraulic_bridge_shape.shape = box
	_hydraulic_bridge.add_child(_hydraulic_bridge_shape)
	
	add_child(_hydraulic_bridge)

func _build_exit_gantry() -> void:
	var gantry_mat := _material(Color(0.22, 0.26, 0.32), 0.8, 0.3)
	var rail_mat := _material(Color(0.12, 0.15, 0.18), 0.9, 0.2)
	var gate_mat := _material(Color(0.18, 0.2, 0.25), 0.9, 0.25, true, Color(0.0, 0.9, 1.0), 0.8)
	
	# North Exit Gantry at Y = 0.0m, Z = -38.0m to -44.0m, X = -4.0m to +4.0m
	_box("ExitGantryDeck", Vector3(0.0, -0.1, -41.0), Vector3(8.0, 0.2, 6.0), gantry_mat, true)
	_box("ExitGantryRailWest", Vector3(-3.95, 0.5, -41.0), Vector3(0.1, 1.0, 6.0), rail_mat, true)
	# Split East railing to leave 2.4m aperture for EastToExitWalkway entrance (Z = -38.8m to -41.2m)
	_box("ExitGantryRailEastNorth", Vector3(3.95, 0.5, -42.6), Vector3(0.1, 1.0, 2.8), rail_mat, true)
	_box("ExitGantryRailEastSouth", Vector3(3.95, 0.5, -38.4), Vector3(0.1, 1.0, 0.8), rail_mat, true)
	
	# North Exit Blast Gate (2.05m wide x 2.8m high) at Z = -44.0m
	_gate = StaticBody3D.new()
	_gate.name = "NorthExitGate"
	_gate.position = Vector3(0.0, _gate_closed_y, -44.0)
	
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

func _build_hazard_volumes() -> void:
	# Hazard A: West Catwalk Discharge Arc (Area3D)
	var arc_a_node := Node3D.new()
	arc_a_node.name = "HazardVolumeA"
	arc_a_node.position = Vector3(-6.0, -1.9, -16.0)
	
	_hazard_a_mesh = MeshInstance3D.new()
	var box_m := BoxMesh.new()
	box_m.size = Vector3(3.5, 0.8, 2.2)
	_hazard_a_mesh.mesh = box_m
	_hazard_a_mesh.material_override = _material(Color(0.2, 0.2, 0.2), 0.5, 0.5)
	arc_a_node.add_child(_hazard_a_mesh)
	
	_hazard_a_light = OmniLight3D.new()
	_hazard_a_light.omni_range = 4.0
	arc_a_node.add_child(_hazard_a_light)
	
	_hazard_a_area = Area3D.new()
	_hazard_a_area.name = "TriggerArea"
	var col_a := CollisionShape3D.new()
	var box_a := BoxShape3D.new()
	box_a.size = Vector3(3.5, 1.2, 2.2)
	col_a.shape = box_a
	_hazard_a_area.add_child(col_a)
	_hazard_a_area.body_entered.connect(func(body: Node3D): _on_hazard_entered("HazardA", body))
	arc_a_node.add_child(_hazard_a_area)
	add_child(arc_a_node)
	
	# Hazard B: East Catwalk Discharge Arc (Area3D)
	var arc_b_node := Node3D.new()
	arc_b_node.name = "HazardVolumeB"
	arc_b_node.position = Vector3(6.0, -1.9, -28.0)
	
	_hazard_b_mesh = MeshInstance3D.new()
	_hazard_b_mesh.mesh = box_m
	_hazard_b_mesh.material_override = _material(Color(0.2, 0.2, 0.2), 0.5, 0.5)
	arc_b_node.add_child(_hazard_b_mesh)
	
	_hazard_b_light = OmniLight3D.new()
	_hazard_b_light.omni_range = 4.0
	arc_b_node.add_child(_hazard_b_light)
	
	_hazard_b_area = Area3D.new()
	_hazard_b_area.name = "TriggerArea"
	var col_b := CollisionShape3D.new()
	col_b.shape = box_a
	_hazard_b_area.add_child(col_b)
	_hazard_b_area.body_entered.connect(func(body: Node3D): _on_hazard_entered("HazardB", body))
	arc_b_node.add_child(_hazard_b_area)
	add_child(arc_b_node)

func _build_abyss_kill_zone() -> void:
	# Area3D catching falls into plasma abyss below Y = -8.5m
	_abyss_recovery_area = Area3D.new()
	_abyss_recovery_area.name = "AbyssRecoveryArea"
	_abyss_recovery_area.position = Vector3(0.0, -9.0, -22.0)
	
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ROOM_WIDTH, 2.0, ROOM_LENGTH)
	col.shape = box
	_abyss_recovery_area.add_child(col)
	_abyss_recovery_area.body_entered.connect(_on_abyss_entered)
	add_child(_abyss_recovery_area)

func _build_consoles() -> void:
	# Breaker A Console on West Platform
	_breaker_a_console = _create_breaker_console("BreakerAConsole", Vector3(-12.5, -2.0, -16.0), "breaker_a")
	add_child(_breaker_a_console)
	
	# Breaker B Console on East Platform
	_breaker_b_console = _create_breaker_console("BreakerBConsole", Vector3(12.5, -2.0, -28.0), "breaker_b")
	add_child(_breaker_b_console)

func _create_breaker_console(node_name: String, pos: Vector3, breaker_id: String) -> Node3D:
	var terminal_script: GDScript = preload("res://scripts/environment/breaker_terminal.gd")
	var console: Node3D = terminal_script.new()
	console.name = node_name
	console.position = pos
	
	var prop := SIGNAL_CONSOLE_PROP.instantiate()
	prop.name = "Prop"
	console.add_child(prop)
	
	var area := Area3D.new()
	area.name = "InteractionArea"
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.4
	col.shape = sphere
	area.add_child(col)
	
	area.body_entered.connect(func(body: Node3D):
		if body.has_method("register_nearby_interactable"):
			body.register_nearby_interactable(console)
	)
	area.body_exited.connect(func(body: Node3D):
		if body.has_method("unregister_nearby_interactable"):
			body.unregister_nearby_interactable(console)
	)
	
	console.add_child(area)
	console.set_meta("breaker_id", breaker_id)
	return console

func activate_breaker(breaker_id: String) -> Dictionary:
	if breaker_id == "breaker_a":
		if breaker_a_done:
			return {"success": true, "already_active": true}
		breaker_a_done = true
		breaker_a_activated.emit()
		_check_bridge_activation()
		return {"success": true, "breaker": "breaker_a", "bridge_ready": bridge_extended}
	elif breaker_id == "breaker_b":
		if breaker_b_done:
			return {"success": true, "already_active": true}
		breaker_b_done = true
		breaker_b_activated.emit()
		_check_bridge_activation()
		return {"success": true, "breaker": "breaker_b", "bridge_ready": bridge_extended}
	return {"success": false, "reason": "unknown_breaker"}

func _check_bridge_activation() -> void:
	if breaker_a_done and breaker_b_done and not bridge_extended:
		_extend_hydraulic_bridge()

func _extend_hydraulic_bridge() -> void:
	bridge_extended = true
	state = RoomState.BRIDGE_EXTENDED
	hydraulic_bridge_extended.emit()
	
	if reduced_motion:
		if _hydraulic_bridge:
			_hydraulic_bridge.position.y = _bridge_extended_y
		_open_exit_gate()
		return
	
	if _hydraulic_bridge:
		var tween := create_tween()
		tween.tween_property(_hydraulic_bridge, "position:y", _bridge_extended_y, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func():
			_open_exit_gate()
		)

func _open_exit_gate() -> void:
	if gate_open:
		return
	gate_open = true
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

func _on_hazard_entered(hazard_name: String, body: Node3D) -> void:
	if _is_player(body):
		hazard_triggered.emit(hazard_name)
		_trigger_respawn(body)

func _on_abyss_entered(body: Node3D) -> void:
	if _is_player(body):
		_trigger_respawn(body)

func _is_player(body: Node3D) -> bool:
	if not body:
		return false
	if body == player:
		return true
	if player and is_instance_valid(player) and body.is_ancestor_of(player):
		return true
	if body.is_in_group("player") or body.has_method("finish_opening_recovery"):
		return true
	return false

func _trigger_respawn(target: Node3D = null) -> void:
	retry_requested.emit(current_anchor)
	var p: Node3D = target if (target and target.has_method("finish_opening_recovery")) else player
	if p and is_instance_valid(p):
		p.global_position = current_anchor
		if "velocity" in p:
			p.velocity = Vector3.ZERO

func get_safe_anchor() -> Vector3:
	return current_anchor

func get_state() -> Dictionary:
	return {
		"state": state,
		"current_anchor": current_anchor,
		"breaker_a_done": breaker_a_done,
		"breaker_b_done": breaker_b_done,
		"bridge_extended": bridge_extended,
		"gate_open": gate_open,
		"bridge_pos_y": _hydraulic_bridge.position.y if _hydraulic_bridge else _bridge_retracted_y,
		"gate_pos_y": _gate.position.y if _gate else _gate_closed_y,
		"gate_col_disabled": _gate_shape.disabled if _gate_shape else false
	}

func restore_state(data: Dictionary) -> void:
	if data.has("state"):
		state = data["state"]
	if data.has("current_anchor"):
		current_anchor = data["current_anchor"]
	if data.has("breaker_a_done"):
		breaker_a_done = data["breaker_a_done"]
	if data.has("breaker_b_done"):
		breaker_b_done = data["breaker_b_done"]
	if data.has("bridge_extended"):
		bridge_extended = data["bridge_extended"]
	if data.has("gate_open"):
		gate_open = data["gate_open"]
	if _hydraulic_bridge and data.has("bridge_pos_y"):
		_hydraulic_bridge.position.y = data["bridge_pos_y"]
	if _gate and data.has("gate_pos_y"):
		_gate.position.y = data["gate_pos_y"]
	if _gate_shape and data.has("gate_col_disabled"):
		_gate_shape.disabled = data["gate_col_disabled"]
