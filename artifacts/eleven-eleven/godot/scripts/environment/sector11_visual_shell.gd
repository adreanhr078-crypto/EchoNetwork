extends Node3D

const ROOM_WIDTH := 18.0
const ROOM_HEIGHT := 7.2
const ROOM_LENGTH := 42.0
const ROOM_CENTER_Z := -14.0
const OBSERVATION_MODULE: PackedScene = preload("res://assets/environment/sector11_observation_module_v1.glb")
const SERVICE_MODULE: PackedScene = preload("res://assets/environment/sector11_service_module_v1.glb")
const CEILING_TILE: PackedScene = preload("res://assets/environment/sector11_ceiling_tile_v1.glb")

var _shell_material: StandardMaterial3D
var _panel_material: StandardMaterial3D
var _rib_material: StandardMaterial3D
var _cyan_material: StandardMaterial3D
var _violet_material: StandardMaterial3D
var _warm_material: StandardMaterial3D
var _lamp_material: StandardMaterial3D
var _floor_joint_material: StandardMaterial3D
var _floor_panel_material: StandardMaterial3D
var _observation_glass_material: StandardMaterial3D

func _ready() -> void:
	_make_materials()
	_build_boundaries()
	_build_structural_ribs()
	_build_wall_panels()
	_build_ceiling_lights()
	_build_service_conduits()
	_build_sector_signage()
	_build_floor_inlays()

func _make_materials() -> void:
	_shell_material = _material(Color(0.06, 0.08, 0.12), 0.75, 0.15)
	_panel_material = _material(Color(0.04, 0.055, 0.08), 0.65, 0.25)
	_rib_material = _material(Color(0.12, 0.15, 0.22), 0.45, 0.45)
	_cyan_material = _material(Color(0.0, 0.35, 0.45), 0.3, 0.3, Color(0.0, 0.88, 1.0), 1.6)
	_violet_material = _material(Color(0.28, 0.06, 0.44), 0.3, 0.3, Color(0.78, 0.22, 1.0), 1.8)
	_warm_material = _material(Color(0.42, 0.19, 0.08), 0.45, 0.2, Color(0.9, 0.32, 0.08), 1.2)
	_lamp_material = _material(Color(0.42, 0.65, 0.82), 0.25, 0.05, Color(0.45, 0.75, 1.0), 1.8)
	_floor_joint_material = _material(Color(0.015, 0.02, 0.03), 0.35, 0.35)
	_floor_panel_material = _material(Color(0.022, 0.03, 0.045), 0.14, 0.6)
	_observation_glass_material = _material(Color(0.02, 0.08, 0.14, 0.75), 0.12, 0.35, Color(0.0, 0.22, 0.32), 0.45)
	_observation_glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_observation_glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED

func _build_boundaries() -> void:
	_add_boundary("WestContainmentWall", Vector3(0.8, ROOM_HEIGHT, ROOM_LENGTH), Vector3(-ROOM_WIDTH * 0.5, ROOM_HEIGHT * 0.5, ROOM_CENTER_Z))
	_add_boundary("EastContainmentWall", Vector3(0.8, ROOM_HEIGHT, ROOM_LENGTH), Vector3(ROOM_WIDTH * 0.5, ROOM_HEIGHT * 0.5, ROOM_CENTER_Z))
	_add_boundary("CeilingShell", Vector3(ROOM_WIDTH, 0.6, ROOM_LENGTH), Vector3(0.0, ROOM_HEIGHT, ROOM_CENTER_Z), false)

func _add_boundary(node_name: String, size: Vector3, at: Vector3, collidable: bool = true) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = at
	add_child(body)
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.name = "Surface"
	visual.mesh = mesh
	visual.material_override = _shell_material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.add_child(visual)
	if collidable:
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)

func _build_structural_ribs() -> void:
	for index in range(9):
		var z := 5.0 - float(index) * 5.0
		for side in [-1.0, 1.0]:
			_add_box("ContainmentRib", Vector3(0.42, ROOM_HEIGHT - 0.5, 0.55), Vector3(side * (ROOM_WIDTH * 0.5 - 0.22), (ROOM_HEIGHT - 0.5) * 0.5, z), _rib_material)
		_add_box("CeilingCrossBeam", Vector3(ROOM_WIDTH - 0.7, 0.38, 0.6), Vector3(0.0, ROOM_HEIGHT - 0.6, z), _rib_material)
		_add_box("ServiceTruss", Vector3(ROOM_WIDTH - 1.8, 0.12, 0.26), Vector3(0.0, ROOM_HEIGHT - 1.15, z), _panel_material)

func _build_wall_panels() -> void:
	var bay_positions := [2.0, -6.0, -15.0, -25.0, -34.0]
	for index in range(bay_positions.size()):
		var z: float = bay_positions[index]
		for side in [-1.0, 1.0]:
			var is_observation: bool = side > 0.0 and index in [1, 3]
			var module_scene: PackedScene = OBSERVATION_MODULE if is_observation else SERVICE_MODULE
			var module := module_scene.instantiate() as Node3D
			if is_observation:
				module.name = "ObservationModule_%02d" % (index + 1)
			else:
				module.name = "ServiceModule_%02d_%s" % [index + 1, "L" if side < 0.0 else "R"]
			module.position = Vector3(side * (ROOM_WIDTH * 0.5 - 0.4), 0.0, z)
			module.rotation.y = -side * PI * 0.5
			add_child(module)

func _build_observation_bay(bay_number: int, side: float, x: float, z: float) -> void:
	_add_box("ObservationBayGlass", Vector3(0.045, 3.15, 3.8), Vector3(x, 3.35, z), _observation_glass_material)
	for edge in [-1.0, 1.0]:
		_add_box("ObservationBayFrame", Vector3(0.14, 3.45, 0.18), Vector3(x - side * 0.08, 3.35, z + edge * 1.98), _rib_material)
	_add_box("ObservationBayHeader", Vector3(0.14, 0.16, 4.1), Vector3(x - side * 0.08, 5.13, z), _rib_material)
	_add_box("ObservationBaySill", Vector3(0.14, 0.22, 4.1), Vector3(x - side * 0.08, 1.57, z), _rib_material)
	_add_box("GlassDivider", Vector3(0.055, 0.07, 3.65), Vector3(x - side * 0.13, 2.75, z), _cyan_material)
	_add_box("ObservationStatus", Vector3(0.055, 0.28, 0.08), Vector3(x - side * 0.15, 5.42, z - 1.55), _warm_material if bay_number == 4 else _cyan_material)
	var bay_label := Label3D.new()
	bay_label.name = "ObservationBayLabel"
	bay_label.text = "OBSERVATION // 0%d" % bay_number
	bay_label.font_size = 18
	bay_label.pixel_size = 0.004
	bay_label.modulate = Color(0.54, 0.78, 0.87)
	bay_label.outline_size = 5
	bay_label.outline_modulate = Color(0.018, 0.035, 0.06, 1.0)
	bay_label.position = Vector3(x - side * 0.16, 5.46, z + 0.55)
	bay_label.rotation.y = -side * PI * 0.5
	add_child(bay_label)

func _build_service_bay(bay_number: int, side: float, x: float, z: float) -> void:
	var panel_height := 2.8 if bay_number % 2 == 0 else 3.25
	_add_box("RecessedServiceBay", Vector3(0.08, panel_height, 3.35), Vector3(x, 2.7, z), _panel_material)
	_add_box("ServiceBayHeader", Vector3(0.12, 0.14, 3.6), Vector3(x - side * 0.08, 2.7 + panel_height * 0.5, z), _rib_material)
	_add_box("ServiceBaySill", Vector3(0.12, 0.14, 3.6), Vector3(x - side * 0.08, 2.7 - panel_height * 0.5, z), _rib_material)
	_add_box("ServiceBaySignal", Vector3(0.055, 0.44, 0.09), Vector3(x - side * 0.14, 2.7, z - 1.25), _warm_material if bay_number == 5 else _cyan_material)
	for vent_index in range(4):
		_add_box("ServiceVent", Vector3(0.055, 0.075, 1.35), Vector3(x - side * 0.14, 3.55 + float(vent_index) * 0.16, z + 0.52), _floor_joint_material)
	_add_box("StatusLight", Vector3(0.07, 0.055, 1.35), Vector3(x - side * 0.13, 4.65, z), _warm_material if bay_number == 5 else _cyan_material)
	_add_box("WallLightSlot", Vector3(0.08, 0.1, 2.1), Vector3(x - side * 0.12, ROOM_HEIGHT - 0.75, z), _lamp_material)

func _build_ceiling_lights() -> void:
	var tile_positions := [2.5, -2.5, -7.5, -12.5, -17.5, -22.5, -27.5, -32.5]
	for index in range(tile_positions.size()):
		var z: float = tile_positions[index]
		var tile := CEILING_TILE.instantiate() as Node3D
		tile.name = "CeilingLightCassette_%02d" % (index + 1)
		tile.position = Vector3(0.0, ROOM_HEIGHT - 0.39, z)
		add_child(tile)
		if index % 2 == 1:
			var light := OmniLight3D.new()
			light.name = "CoolLabKey_%02d" % (index + 1)
			light.position = Vector3(0.0, ROOM_HEIGHT - 1.35, z + 2.5)
			light.light_color = Color(0.72, 0.83, 1.0)
			light.light_energy = 3.6
			light.omni_range = 12.0
			light.shadow_enabled = false
			add_child(light)
		if index % 3 == 0:
			var warm_beacon := OmniLight3D.new()
			warm_beacon.name = "ContainmentBeacon_%02d" % (index + 1)
			warm_beacon.position = Vector3(0.0, 5.0, z - 2.0)
			warm_beacon.light_color = Color(1.0, 0.33, 0.12)
			warm_beacon.light_energy = 0.38
			warm_beacon.omni_range = 6.0
			add_child(warm_beacon)

func _build_service_conduits() -> void:
	for side in [-1.0, 1.0]:
		var pipe := CylinderMesh.new()
		pipe.top_radius = 0.12
		pipe.bottom_radius = 0.12
		pipe.height = ROOM_LENGTH - 2.0
		var pipe_node := MeshInstance3D.new()
		pipe_node.name = "MainCoolantConduit"
		pipe_node.mesh = pipe
		pipe_node.material_override = _rib_material
		pipe_node.position = Vector3(side * (ROOM_WIDTH * 0.5 - 2.4), ROOM_HEIGHT - 1.0, ROOM_CENTER_Z)
		pipe_node.rotation.x = PI * 0.5
		add_child(pipe_node)
		_add_box("SignalRail", Vector3(0.1, 0.08, ROOM_LENGTH - 1.5), Vector3(side * (ROOM_WIDTH * 0.5 - 0.85), 0.15, ROOM_CENTER_Z), _cyan_material)

func _build_sector_signage() -> void:
	# Sector identification
	var label := Label3D.new()
	label.name = "SectorIdentification"
	label.text = "SECTOR 11  /  NEURAL CONTAINMENT"
	label.font_size = 36
	label.pixel_size = 0.004
	label.modulate = Color(0.55, 0.82, 0.94)
	label.outline_size = 8
	label.outline_modulate = Color(0.018, 0.035, 0.06, 1.0)
	label.position = Vector3(ROOM_WIDTH * 0.5 - 0.25, ROOM_HEIGHT - 0.55, -8.0)
	label.rotation.y = -PI * 0.5
	add_child(label)

	# Holographic Billboard 1 (West Wall): STILL HUMAN?
	_add_box("HoloPlate_West", Vector3(0.08, 3.4, 4.8), Vector3(-ROOM_WIDTH * 0.5 + 0.15, 3.8, 1.0), _violet_material)
	var holo1 := Label3D.new()
	holo1.name = "HoloSign_StillHuman"
	holo1.text = "STILL HUMAN ?\n\nMEMORY _\nIDENTITY _\nREALITY _\nYOU _"
	holo1.font_size = 32
	holo1.pixel_size = 0.0045
	holo1.modulate = Color(0.92, 0.45, 1.0, 1.0)
	holo1.outline_size = 10
	holo1.outline_modulate = Color(0.18, 0.02, 0.32, 1.0)
	holo1.position = Vector3(-ROOM_WIDTH * 0.5 + 0.22, 3.8, 1.0)
	holo1.rotation.y = PI * 0.5
	add_child(holo1)

	# Holographic Billboard 2 (East Wall): DO YOU STILL BELONG HERE?
	_add_box("HoloPlate_East", Vector3(0.08, 3.2, 5.2), Vector3(ROOM_WIDTH * 0.5 - 0.15, 3.8, -6.0), _cyan_material)
	var holo2 := Label3D.new()
	holo2.name = "HoloSign_Corrupted"
	holo2.text = "DO YOU STILL BELONG HERE ?\n\n// REALITY.DMP_CORRUPTED\nERROR  ERROR  ERROR"
	holo2.font_size = 28
	holo2.pixel_size = 0.0042
	holo2.modulate = Color(0.25, 0.95, 1.0, 1.0)
	holo2.outline_size = 8
	holo2.outline_modulate = Color(0.02, 0.18, 0.25, 1.0)
	holo2.position = Vector3(ROOM_WIDTH * 0.5 - 0.22, 3.8, -6.0)
	holo2.rotation.y = -PI * 0.5
	add_child(holo2)

	# Gate Warning Header: SOME TRUTHS SHOULD STAY BURIED
	var gate_warn := Label3D.new()
	gate_warn.name = "HoloSign_GateWarning"
	gate_warn.text = "SOME TRUTHS SHOULD STAY BURIED."
	gate_warn.font_size = 30
	gate_warn.pixel_size = 0.0042
	gate_warn.modulate = Color(1.0, 0.32, 0.22, 1.0)
	gate_warn.outline_size = 8
	gate_warn.outline_modulate = Color(0.25, 0.04, 0.02, 1.0)
	gate_warn.position = Vector3(0.0, 5.8, -17.4)
	add_child(gate_warn)

func _build_floor_inlays() -> void:
	for index in range(8):
		var z := 1.0 - float(index) * 5.0
		_add_box("DeckExpansionJoint", Vector3(18.0, 0.018, 0.045), Vector3(0.0, 0.014, z), _floor_joint_material)
		for side in [-1.0, 1.0]:
			var x: float = side * 6.3
			_add_box("MaintenanceDeckPanel", Vector3(2.6, 0.028, 1.15), Vector3(x, 0.018, z - 2.2), _floor_panel_material)
			_add_box("DeckPanelSeam", Vector3(0.045, 0.02, 0.92), Vector3(x + side * 1.18, 0.036, z - 2.2), _floor_joint_material)

func _add_box(node_name: String, size: Vector3, at: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(node)

func _material(color: Color, roughness: float, metallic: float, emission: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_energy
	return material
