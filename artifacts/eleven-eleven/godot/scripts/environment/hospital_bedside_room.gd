extends Node3D

## Room 12: Hospital Bedside Awakening Room (Decompression Ward)
## Chapter 1 Climax & Awakening into the Real World.
## Decoupled Origin at Vector3(0, 0, 0), independent of Sector 11 facility.
## Enforces the Anti-Crowding and Quality Gate Invariants:
## - Watertight Hull (6.4m x 5.8m x 3.2m), hermetic collision envelope, zero light/audio bleed.
## - Furniture & Ward Equipment:
##   * Hospital bed, mattress, pillow, folded linen cover.
##   * Bedside cabinet, water cup, vitals monitor (HEART RATE 72).
##   * IV drip pole, IV bag, visitor chair.
##   * Rain window with daylight blinds (South Wall).
##   * Digital Wall Clock frozen at 11:11 (North Wall).
##   * Interactive Vanity & Mirror Station (East Wall).
##   * Ward Exit Door with Minato-Kasumi medical signage.
## - Monotonic Safe Anchors: Bedside Awakening (-0.3, 0.0, 1.18) -> Mirror Station (1.8, 0.0, -1.0).
## - Narrative & Gameplay Signals:
##   * signal bed_awakened
##   * signal ex011_mark_revealed
##   * signal chapter_1_completed

signal bed_awakened
signal ex011_mark_revealed
signal chapter_1_completed
signal safe_anchor_updated(anchor: Vector3)

enum RoomState {
	BED_RECLINED,
	BED_AWAKENING,
	WARD_EXPLORATION,
	MIRROR_INSPECTION,
	EX011_REVEALED,
	CHAPTER_1_COMPLETED
}

const MirrorStationScript = preload("res://scripts/environment/hospital_mirror_station.gd")

const ROOM_WIDTH := 6.4   # X: -3.2m to +3.2m
const ROOM_LENGTH := 5.8  # Z: -2.9m to +2.9m
const ROOM_HEIGHT := 3.2  # Y: 0.0m to +3.2m
const WALL_THICKNESS := 0.20

const SAFE_ANCHOR_BEDSIDE := Vector3(-0.30, 0.0, 1.18)
const SAFE_ANCHOR_MIRROR := Vector3(1.80, 0.0, -1.00)

var state: RoomState = RoomState.BED_RECLINED
var current_anchor: Vector3 = SAFE_ANCHOR_BEDSIDE
var reduced_motion := false
var audio_muted := false
var player: Node3D

var bed_awakened_done := false
var mark_revealed_done := false
var chapter_completed_done := false

# Node references
var _floor_body: StaticBody3D
var _ceiling_body: StaticBody3D
var _north_wall: StaticBody3D
var _south_wall: StaticBody3D
var _west_wall: StaticBody3D
var _east_wall: StaticBody3D

var _bed_body: StaticBody3D
var _cabinet_body: StaticBody3D
var _mirror_station: StaticBody3D
var _clock_label: Label3D
var _vitals_label: Label3D
var _exit_door_body: StaticBody3D

var _mark_light: OmniLight3D

func _ready() -> void:
	_build_room_hull()
	_build_lighting_and_environment()
	_build_bed_and_equipment()
	_build_rain_window()
	_build_clock_1111()
	_build_mirror_station()
	_build_exit_door()

func _physics_process(_delta: float) -> void:
	if not player or not is_instance_valid(player):
		return
	
	var pos: Vector3 = to_local(player.global_position)
	
	# Monotonic safe anchor progression
	if pos.x > 0.8 and pos.z < 0.2:
		if current_anchor != SAFE_ANCHOR_MIRROR:
			current_anchor = SAFE_ANCHOR_MIRROR
			safe_anchor_updated.emit(current_anchor)
			if state == RoomState.WARD_EXPLORATION:
				state = RoomState.MIRROR_INSPECTION

func _build_room_hull() -> void:
	# Floor
	_floor_body = _create_box_body("Floor", Vector3(ROOM_WIDTH, WALL_THICKNESS, ROOM_LENGTH), Vector3(0.0, -WALL_THICKNESS * 0.5, 0.0), _material(Color(0.20, 0.25, 0.27), 0.1, 0.72))
	# Ceiling
	_ceiling_body = _create_box_body("Ceiling", Vector3(ROOM_WIDTH, WALL_THICKNESS, ROOM_LENGTH), Vector3(0.0, ROOM_HEIGHT + WALL_THICKNESS * 0.5, 0.0), _material(Color(0.73, 0.77, 0.73), 0.0, 0.84))
	# North Wall (Z = +2.9)
	_north_wall = _create_box_body("NorthWall", Vector3(ROOM_WIDTH, ROOM_HEIGHT, WALL_THICKNESS), Vector3(0.0, ROOM_HEIGHT * 0.5, ROOM_LENGTH * 0.5 + WALL_THICKNESS * 0.5), _material(Color(0.34, 0.39, 0.42), 0.0, 0.90))
	# South Wall (Z = -2.9)
	_south_wall = _create_box_body("SouthWall", Vector3(ROOM_WIDTH, ROOM_HEIGHT, WALL_THICKNESS), Vector3(0.0, ROOM_HEIGHT * 0.5, -ROOM_LENGTH * 0.5 - WALL_THICKNESS * 0.5), _material(Color(0.34, 0.39, 0.42), 0.0, 0.90))
	# West Wall (X = -3.2)
	_west_wall = _create_box_body("WestWall", Vector3(WALL_THICKNESS, ROOM_HEIGHT, ROOM_LENGTH), Vector3(-ROOM_WIDTH * 0.5 - WALL_THICKNESS * 0.5, ROOM_HEIGHT * 0.5, 0.0), _material(Color(0.34, 0.39, 0.42), 0.0, 0.90))
	# East Wall (X = +3.2)
	_east_wall = _create_box_body("EastWall", Vector3(WALL_THICKNESS, ROOM_HEIGHT, ROOM_LENGTH), Vector3(ROOM_WIDTH * 0.5 + WALL_THICKNESS * 0.5, ROOM_HEIGHT * 0.5, 0.0), _material(Color(0.34, 0.39, 0.42), 0.0, 0.90))

func _build_lighting_and_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "HospitalWorldEnvironment"
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.27, 0.35, 0.42)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.65, 0.72, 0.80)
	world.environment.ambient_light_energy = 0.55
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(world)
	
	# Daylight through south rain window
	var sun := DirectionalLight3D.new()
	sun.name = "WardDaylight"
	sun.rotation_degrees = Vector3(-45, -25, 0)
	sun.light_color = Color(0.96, 0.92, 0.85)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	add_child(sun)
	
	# Soft ambient fill
	var fill := OmniLight3D.new()
	fill.name = "WardInteriorFill"
	fill.position = Vector3(0.0, 2.5, 0.0)
	fill.light_color = Color(0.72, 0.82, 0.90)
	fill.light_energy = 0.65
	fill.omni_range = 6.0
	add_child(fill)

func _build_bed_and_equipment() -> void:
	# Bed frame and mattress
	_bed_body = _create_box_body("HospitalBed", Vector3(2.24, 0.70, 1.04), Vector3(-1.0, 0.35, 0.0), _material(Color(0.67, 0.72, 0.73), 0.05, 0.95))
	
	# Pillow
	var pillow := _create_mesh_box("Pillow", Vector3(0.50, 0.12, 0.70), Vector3(-1.75, 0.76, 0.0), _material(Color(0.85, 0.88, 0.86), 0.0, 0.9))
	add_child(pillow)
	
	# Folded cover
	var cover := _create_mesh_box("FoldedCover", Vector3(0.55, 0.10, 0.98), Vector3(-0.20, 0.75, 0.0), _material(Color(0.52, 0.58, 0.60), 0.0, 0.95))
	add_child(cover)
	
	# Bedside cabinet
	_cabinet_body = _create_box_body("BedsideCabinet", Vector3(0.65, 0.68, 0.52), Vector3(-1.75, 0.34, -1.05), _material(Color(0.31, 0.25, 0.19), 0.0, 0.8))
	
	# Water cup
	var cup := _create_mesh_box("WaterCup", Vector3(0.09, 0.14, 0.09), Vector3(-1.60, 0.75, -1.0), _material(Color(0.75, 0.85, 0.90), 0.1, 0.2))
	add_child(cup)
	
	# Heart rate / Vitals monitor cart & screen
	var monitor_base := _create_mesh_box("MonitorBase", Vector3(0.45, 1.30, 0.40), Vector3(-2.45, 0.65, -1.05), _material(Color(0.25, 0.28, 0.32), 0.6, 0.4))
	add_child(monitor_base)
	
	var monitor_screen := _create_mesh_box("MonitorScreen", Vector3(0.50, 0.38, 0.08), Vector3(-2.45, 1.45, -0.98), _material(Color(0.02, 0.04, 0.06), 0.2, 0.1, true, Color(0.0, 0.85, 0.45), 0.8))
	add_child(monitor_screen)
	
	_vitals_label = Label3D.new()
	_vitals_label.name = "VitalsReadout"
	_vitals_label.text = "HEART RATE: 72 BPM\nNEURAL LINK: DISCONNECTED\nSTATUS: STABLE"
	_vitals_label.font_size = 14
	_vitals_label.modulate = Color(0.2, 0.95, 0.65)
	_vitals_label.position = Vector3(-2.45, 1.45, -0.93)
	add_child(_vitals_label)
	
	# IV stand
	var iv_pole := _create_mesh_box("IVPole", Vector3(0.04, 2.0, 0.04), Vector3(-2.45, 1.0, 0.90), _material(Color(0.35, 0.38, 0.42), 0.8, 0.3))
	add_child(iv_pole)
	var iv_bag := _create_mesh_box("IVBag", Vector3(0.16, 0.28, 0.08), Vector3(-2.45, 1.85, 0.90), _material(Color(0.8, 0.9, 0.95), 0.0, 0.1))
	add_child(iv_bag)

func _build_rain_window() -> void:
	# South rain window frame & glass
	var win_glass := _create_box_body("WindowGlassBarrier", Vector3(2.87, 1.80, 0.08), Vector3(0.0, 1.85, -2.85), _material(Color(0.64, 0.76, 0.85), 0.1, 0.2))
	var win_sill := _create_mesh_box("WindowSill", Vector3(3.05, 0.08, 0.32), Vector3(0.0, 0.95, -2.76), _material(Color(0.73, 0.77, 0.73), 0.0, 0.84))
	add_child(win_sill)
	
	# Venetian blind slats angled to catch morning sun
	for i in range(12):
		var slat := _create_mesh_box("BlindSlat_" + str(i), Vector3(2.75, 0.025, 0.11), Vector3(0.0, 1.08 + i * 0.13, -2.80), _material(Color(0.82, 0.85, 0.82), 0.0, 0.85))
		slat.rotation.x = -0.38
		add_child(slat)

func _build_clock_1111() -> void:
	# Digital wall clock mounted on North Wall at eye level
	var clock_frame := _create_mesh_box("ClockFrame", Vector3(0.55, 0.24, 0.06), Vector3(0.0, 2.30, 2.82), _material(Color(0.08, 0.10, 0.12), 0.4, 0.5))
	add_child(clock_frame)
	
	_clock_label = Label3D.new()
	_clock_label.name = "DigitalClock1111"
	_clock_label.text = "11:11"
	_clock_label.font_size = 28
	_clock_label.modulate = Color(0.3, 0.9, 0.85)
	_clock_label.position = Vector3(0.0, 2.30, 2.78)
	_clock_label.rotation_degrees = Vector3(0, 180, 0) # Facing inward into the room
	add_child(_clock_label)

func _build_mirror_station() -> void:
	# Interactive Vanity & Mirror Station on East Wall (X = 3.1, Z = -1.0)
	_mirror_station = MirrorStationScript.new()
	_mirror_station.name = "VanityMirrorStation"
	_mirror_station.position = Vector3(3.0, 0.0, -1.0)
	add_child(_mirror_station)
	
	# Solid counter / sink vanity
	var counter_col := CollisionShape3D.new()
	counter_col.name = "CounterCollisionShape3D"
	var counter_box := BoxShape3D.new()
	counter_box.size = Vector3(0.60, 0.85, 1.10)
	counter_col.shape = counter_box
	counter_col.position = Vector3(-0.30, 0.425, 0.0)
	_mirror_station.add_child(counter_col)
	
	var counter_mesh := _create_mesh_box("CounterMesh", Vector3(0.60, 0.85, 1.10), Vector3(-0.30, 0.425, 0.0), _material(Color(0.85, 0.88, 0.88), 0.0, 0.85))
	_mirror_station.add_child(counter_mesh)
	
	# Sink basin cutout & faucet
	var faucet := _create_mesh_box("Faucet", Vector3(0.06, 0.22, 0.06), Vector3(-0.15, 0.96, 0.0), _material(Color(0.7, 0.75, 0.8), 0.9, 0.2))
	_mirror_station.add_child(faucet)
	
	# Mirror frame & reflective surface
	var mirror_frame := _create_mesh_box("MirrorFrame", Vector3(0.04, 1.10, 0.80), Vector3(-0.02, 1.65, 0.0), _material(Color(0.20, 0.22, 0.25), 0.5, 0.4))
	_mirror_station.add_child(mirror_frame)
	
	var mirror_glass := _create_mesh_box("MirrorGlass", Vector3(0.02, 1.02, 0.72), Vector3(-0.04, 1.65, 0.0), _material(Color(0.75, 0.85, 0.92), 0.9, 0.05))
	_mirror_station.add_child(mirror_glass)
	
	# Mirror Vanity Light
	var mirror_light := OmniLight3D.new()
	mirror_light.name = "MirrorVanityLight"
	mirror_light.position = Vector3(2.6, 2.35, -1.0)
	mirror_light.light_color = Color(0.98, 0.95, 0.88)
	mirror_light.light_energy = 0.95
	mirror_light.omni_range = 3.5
	add_child(mirror_light)
	
	# EX-011 neck pulse stinger light (starts muted/dormant)
	_mark_light = OmniLight3D.new()
	_mark_light.name = "EX011MarkLight"
	_mark_light.position = Vector3(2.2, 1.45, -1.0)
	_mark_light.light_color = Color(0.62, 0.25, 0.92) # Royal Zero Purple
	_mark_light.light_energy = 0.0
	_mark_light.omni_range = 2.0
	add_child(_mark_light)

func _build_exit_door() -> void:
	# East Wall Ward Exit Door at X = 3.12, Z = 1.6
	_exit_door_body = _create_box_body("WardExitDoor", Vector3(WALL_THICKNESS, 2.20, 1.40), Vector3(ROOM_WIDTH * 0.5, 1.10, 1.60), _material(Color(0.24, 0.28, 0.32), 0.5, 0.5))
	
	var exit_sign := Label3D.new()
	exit_sign.name = "WardExitSign"
	exit_sign.text = "WARD EXIT  →  MINATO-KASUMI"
	exit_sign.font_size = 18
	exit_sign.modulate = Color(0.35, 0.85, 0.65)
	exit_sign.position = Vector3(ROOM_WIDTH * 0.5 - 0.05, 2.40, 1.60)
	exit_sign.rotation_degrees = Vector3(0, -90, 0)
	add_child(exit_sign)

# --- Gameplay & Interaction Logic ---

func wake_up_from_bed() -> bool:
	if bed_awakened_done:
		return false
	
	bed_awakened_done = true
	state = RoomState.WARD_EXPLORATION
	current_anchor = SAFE_ANCHOR_BEDSIDE
	bed_awakened.emit()
	return true

func execute_mirror_inspection(_interactor: Node = null) -> Dictionary:
	if mark_revealed_done:
		return {
			"success": true,
			"already_inspected": true,
			"label": "EX-011",
			"chapter_completed": chapter_completed_done
		}
	
	state = RoomState.EX011_REVEALED
	mark_revealed_done = true
	ex011_mark_revealed.emit()
	
	# Light stinger animation for EX-011 reveal
	if not reduced_motion and _mark_light:
		var tw := create_tween()
		tw.tween_property(_mark_light, "light_energy", 1.8, 0.2)
		tw.tween_property(_mark_light, "light_energy", 0.4, 0.6)
	elif _mark_light:
		_mark_light.light_energy = 0.4
	
	# Transition to Chapter 1 Completion
	_complete_chapter_1()
	
	return {
		"success": true,
		"mark_revealed": true,
		"label": "EX-011",
		"chapter_completed": true,
		"message": "EX-011 mark confirmed. Chapter 1 Completed."
	}

func _complete_chapter_1() -> void:
	state = RoomState.CHAPTER_1_COMPLETED
	chapter_completed_done = true
	chapter_1_completed.emit()

func get_safe_anchor() -> Vector3:
	return current_anchor

# --- State Persistence Contract ---

func get_state() -> Dictionary:
	return {
		"state": state,
		"bed_awakened": bed_awakened_done,
		"mark_revealed": mark_revealed_done,
		"chapter_completed": chapter_completed_done,
		"current_anchor": current_anchor,
		"clock_time": "11:11"
	}

func restore_state(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	
	bed_awakened_done = data.get("bed_awakened", false)
	mark_revealed_done = data.get("mark_revealed", false)
	chapter_completed_done = data.get("chapter_completed", false)
	
	if data.has("state"):
		state = data["state"]
	if data.has("current_anchor"):
		current_anchor = data["current_anchor"]
	
	if mark_revealed_done and _mark_light:
		_mark_light.light_energy = 0.4
		
	return true

# --- Helper Builders ---

func _create_box_body(node_name: String, size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = node_name + "Mesh"
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh
	mesh_inst.material_override = mat
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.add_child(mesh_inst)
	
	add_child(body)
	return body

func _create_mesh_box(node_name: String, size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = node_name
	mesh_inst.position = pos
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh
	mesh_inst.material_override = mat
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mesh_inst

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
