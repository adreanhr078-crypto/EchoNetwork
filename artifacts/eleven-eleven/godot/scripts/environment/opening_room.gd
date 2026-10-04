extends Node3D

## Isolated Room 1: Awakening Cryo-Chamber (Sector 11 Facility)
## Fully compliant with Level Architecture Anti-Crowding Specification:
## Dimensions: 18.0m width x 25.4m length x 7.2m height (Z = +7.0m to -18.0m, Y = 0.0m)
## Watertight hermetic boundary, zero shared walls, isolated PBR lighting & acoustics.

signal room_cleared
signal evidence_inspected(id: String)
signal terminal_solved

const VISUAL_SHELL = preload("res://scenes/environment/sector11_visual_shell.tscn")
const BLAST_GATE = preload("res://scenes/environment/blast_gate.tscn")
const TERMINAL = preload("res://scenes/environment/substation_terminal.tscn")
const EVIDENCE = preload("res://scenes/environment/opening_evidence.tscn")
const FLOODED_SHADER = preload("res://shaders/flooded_lab_floor.gdshader")
const STROBE_SCRIPT = preload("res://scripts/effects/emergency_warning_strobe.gd")

const ROOM_WIDTH := 18.0
const ROOM_LENGTH := 25.4
const ROOM_HEIGHT := 7.2
const Z_SOUTH := 7.0
const Z_NORTH := -18.0

var shell: Node3D
var primary_blast_gate: Node3D
var terminal: Node3D
var clock_evidence: Node3D
var photo_evidence: Node3D
var strobe_light: OmniLight3D
var vent_duct_marker: Marker3D

func _ready() -> void:
	_build_room()

func _build_room() -> void:
	# 1. Hermetic Visual Shell (opening_only mode: Z = +7.0 to -18.0)
	shell = VISUAL_SHELL.instantiate()
	shell.name = "Sector11OpeningShell"
	shell.set("opening_only", true)
	add_child(shell)
	
	# 2. Flooded Reflective Floor
	var floor_body := StaticBody3D.new()
	floor_body.name = "FloodedFloorBody"
	floor_body.position = Vector3(0.0, -0.2, -5.5)
	
	var floor_mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(ROOM_WIDTH, 0.4, ROOM_LENGTH)
	floor_mesh.mesh = box_mesh
	
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = FLOODED_SHADER
	floor_mat.set_shader_parameter("floor_color", Color(0.035, 0.045, 0.065, 1.0))
	floor_mat.set_shader_parameter("water_tint", Color(0.015, 0.25, 0.34, 1.0))
	floor_mat.set_shader_parameter("neon_reflection_color", Color(0.0, 0.48, 0.62, 1.0))
	floor_mat.set_shader_parameter("roughness", 0.50)
	floor_mat.set_shader_parameter("metallic", 0.22)
	floor_mat.set_shader_parameter("specular", 0.30)
	floor_mat.set_shader_parameter("puddle_roughness", 0.03)
	floor_mat.set_shader_parameter("puddle_specular", 0.95)
	floor_mat.set_shader_parameter("puddle_coverage", 0.52)
	floor_mesh.material_override = floor_mat
	floor_body.add_child(floor_mesh)
	
	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(ROOM_WIDTH, 0.4, ROOM_LENGTH)
	floor_col.shape = floor_shape
	floor_body.add_child(floor_col)
	add_child(floor_body)
	
	# 3. Primary Blast Gate at Z = -18.0 (Locked, sealing Room 1)
	primary_blast_gate = BLAST_GATE.instantiate()
	primary_blast_gate.name = "PrimaryBlastGate"
	primary_blast_gate.position = Vector3(0.0, 0.0, Z_NORTH)
	primary_blast_gate.set("state", 0) # LOCKED
	primary_blast_gate.set("keep_collision_when_open", true)
	add_child(primary_blast_gate)
	
	# 4. Authored High Vent Duct Aperture (Vent Duct #1 at X = +3.2m, Y = 1.8m, Z = -18.0m)
	# Connects toward Surveillance Vestibule (Room 2) without shared walls
	_build_vent_duct_aperture()
	
	# 5. Authored Signal Console Terminal
	terminal = TERMINAL.instantiate()
	terminal.name = "SectorTerminal"
	terminal.position = Vector3(2.8, 0.0, 2.4)
	add_child(terminal)
	
	# 6. Authored Evidences (Clock & Photograph)
	clock_evidence = EVIDENCE.instantiate()
	clock_evidence.name = "OpeningClock"
	clock_evidence.position = Vector3(-1.85, 0.0, 1.8)
	clock_evidence.set("evidence_id", "clock")
	add_child(clock_evidence)
	
	photo_evidence = EVIDENCE.instantiate()
	photo_evidence.name = "OpeningPhotograph"
	photo_evidence.position = Vector3(3.7, 0.0, -1.5)
	photo_evidence.set("evidence_id", "photo")
	add_child(photo_evidence)
	
	# 7. Emergency Strobe Light (Controlled energy, zero light bleed outside Room 1)
	strobe_light = OmniLight3D.new()
	strobe_light.name = "EmergencyStrobe"
	strobe_light.position = Vector3(-6.0, 5.2, -4.0)
	strobe_light.light_color = Color(0.95, 0.15, 0.25)
	strobe_light.light_energy = 0.8
	strobe_light.omni_range = 8.0
	strobe_light.shadow_enabled = false
	strobe_light.set_script(STROBE_SCRIPT)
	add_child(strobe_light)

func _build_vent_duct_aperture() -> void:
	# Vent Duct aperture per spec Section 3.1: Width 1.2m, Height 1.4m at X = +3.2m, Y = 1.8m, Z = -18.0m
	vent_duct_marker = Marker3D.new()
	vent_duct_marker.name = "VentDuctMarker"
	vent_duct_marker.position = Vector3(3.2, 1.8, Z_NORTH)
	add_child(vent_duct_marker)
	
	# Visual vent rim
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.18, 0.22, 0.26)
	frame_mat.metallic = 0.6
	frame_mat.roughness = 0.4
	
	var rim := MeshInstance3D.new()
	rim.name = "VentRim"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.6
	torus.outer_radius = 0.75
	rim.mesh = torus
	rim.rotation.x = PI * 0.5
	rim.position = Vector3(3.2, 2.5, Z_NORTH + 0.05)
	rim.material_override = frame_mat
	add_child(rim)

func get_vent_anchor() -> Vector3:
	return vent_duct_marker.global_position if vent_duct_marker else to_global(Vector3(3.2, 1.8, Z_NORTH))

func get_gate() -> Node3D:
	return primary_blast_gate
