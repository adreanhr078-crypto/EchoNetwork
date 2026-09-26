extends Node3D

const HospitalBedScene = preload("res://scenes/props/hospital_bed.tscn")

var _floor_material: StandardMaterial3D
var _wall_material: StandardMaterial3D
var _trim_material: StandardMaterial3D
var _window_material: StandardMaterial3D
var _screen_material: StandardMaterial3D
var _metal_material: StandardMaterial3D
var _curtain_material: StandardMaterial3D

func _ready() -> void:
	_make_materials()
	_build_room()
	_build_bed_and_equipment()
	_build_window_and_curtain()
	_build_signage()

func _make_materials() -> void:
	_floor_material = _material(Color(0.08, 0.11, 0.16), 0.22, 0.45)
	_wall_material = _material(Color(0.14, 0.18, 0.24), 0.75, 0.02)
	_trim_material = _material(Color(0.06, 0.09, 0.14), 0.45, 0.5)
	_window_material = _material(Color(0.12, 0.22, 0.38), 0.15, 0.05, Color(0.2, 0.35, 0.6), 1.2)
	_screen_material = _material(Color(0.01, 0.02, 0.04), 0.35, 0.18, Color(0.0, 0.85, 0.45), 0.85)
	_metal_material = _material(Color(0.2, 0.24, 0.28), 0.34, 0.72)
	_curtain_material = _material(Color(0.15, 0.18, 0.22), 0.92, 0.0)

func _build_room() -> void:
	_add_box("PolishedHospitalFloor", Vector3(16.0, 0.3, 18.0), Vector3(0, -0.18, -2.0), _floor_material, true)
	_add_box("NorthWallLeft", Vector3(6.0, 5.0, 0.4), Vector3(-5.0, 2.5, -11.0), _wall_material, true)
	_add_box("NorthWallRight", Vector3(6.0, 5.0, 0.4), Vector3(5.0, 2.5, -11.0), _wall_material, true)
	_add_box("DoorLintel", Vector3(4.0, 1.4, 0.4), Vector3(0, 4.3, -11.0), _wall_material, true)
	_add_box("SouthWall", Vector3(16.0, 5.0, 0.4), Vector3(0, 2.5, 7.0), _wall_material, true)
	_add_box("WestWall", Vector3(0.4, 5.0, 18.0), Vector3(-8.0, 2.5, -2.0), _wall_material, true)
	_add_box("EastWall", Vector3(0.4, 5.0, 18.0), Vector3(8.0, 2.5, -2.0), _wall_material, true)
	_add_box("Ceiling", Vector3(16.0, 0.4, 18.0), Vector3(0, 5.0, -2.0), _wall_material)
	_add_box("WardBaseboard", Vector3(15.7, 0.18, 0.15), Vector3(0, 0.14, -10.72), _trim_material)
	_add_box("WardHeadwall", Vector3(8.5, 1.25, 0.22), Vector3(-2.2, 2.45, -10.72), _trim_material)
	_add_box("WardHandrail", Vector3(15.6, 0.12, 0.12), Vector3(0, 1.12, -10.72), _metal_material)
	var window_light := OmniLight3D.new()
	window_light.name = "MoonlightRainWindowFill"
	window_light.position = Vector3(-6.6, 3.1, -2.0)
	window_light.light_color = Color(0.22, 0.38, 0.68) # Moody nocturnal moonlight
	window_light.light_energy = 2.2
	window_light.omni_range = 14.0
	add_child(window_light)
	var ceiling_light := OmniLight3D.new()
	ceiling_light.name = "WardDimNocturnalLight"
	ceiling_light.position = Vector3(0, 4.2, -4.0)
	ceiling_light.light_color = Color(0.15, 0.25, 0.42) # Dim eerie ambient
	ceiling_light.light_energy = 0.55
	ceiling_light.omni_range = 10.0
	add_child(ceiling_light)
	_add_box("CeilingDiffuser", Vector3(2.5, 0.08, 1.2), Vector3(0, 4.72, -4.0), _window_material)

func _build_bed_and_equipment() -> void:
	var bed := HospitalBedScene.instantiate()
	bed.name = "RecoveryBed"
	bed.position = Vector3(-2.3, 0.0, -1.0)
	add_child(bed)
	_add_box("MonitorCart", Vector3(0.75, 1.15, 0.52), Vector3(0.15, 0.58, -2.2), _metal_material)
	_add_box("PatientMonitor", Vector3(0.74, 0.52, 0.12), Vector3(0.15, 1.45, -2.35), _screen_material)
	_add_box("MonitorStatusBar", Vector3(0.58, 0.035, 0.025), Vector3(0.15, 1.51, -2.27), _window_material)
	_add_label("VitalsReadout", "HEART RATE  72\nNEURAL LINK  DISCONNECTED", Vector3(0.15, 1.35, -2.27), 15, Color(0.44, 0.9, 0.95))
	_add_cylinder("IVStand", 0.035, 2.1, Vector3(-4.0, 1.05, -1.4), _metal_material)
	_add_box("IVBag", Vector3(0.22, 0.38, 0.1), Vector3(-4.0, 1.88, -1.4), _window_material)
	_add_cylinder("IVBase", 0.24, 0.045, Vector3(-4.0, 0.12, -1.4), _metal_material)
	_add_box("BedsideCabinet", Vector3(0.72, 0.76, 0.62), Vector3(-4.3, 0.38, -1.0), _floor_material)
	_add_box("RoomChairSeat", Vector3(0.64, 0.14, 0.66), Vector3(2.8, 0.58, -3.1), _trim_material)
	_add_box("RoomChairBack", Vector3(0.64, 0.75, 0.14), Vector3(2.8, 0.97, -3.45), _trim_material)
	_add_box("RoomChairLegs", Vector3(0.58, 0.46, 0.55), Vector3(2.8, 0.27, -3.1), _metal_material)
	var privacy_rail := CylinderMesh.new()
	privacy_rail.top_radius = 0.025
	privacy_rail.bottom_radius = 0.025
	privacy_rail.height = 7.5
	var rail := MeshInstance3D.new()
	rail.name = "PrivacyCurtainRail"
	rail.mesh = privacy_rail
	rail.material_override = _metal_material
	rail.position = Vector3(-5.3, 3.9, -2.3)
	rail.rotation.z = PI * 0.5
	add_child(rail)
	_add_box("PrivacyCurtain", Vector3(0.08, 3.1, 0.8), Vector3(-5.25, 2.15, -1.2), _curtain_material)

func _build_window_and_curtain() -> void:
	_add_box("WindowFrameNear", Vector3(0.22, 2.5, 0.18), Vector3(-7.55, 3.0, -4.5), _trim_material)
	_add_box("WindowFrameFar", Vector3(0.22, 2.5, 0.18), Vector3(-7.55, 3.0, 0.5), _trim_material)
	_add_box("WindowFrameTop", Vector3(0.22, 0.18, 5.0), Vector3(-7.55, 4.25, -2.0), _trim_material)
	_add_box("WindowFrameBottom", Vector3(0.22, 0.18, 5.0), Vector3(-7.55, 1.75, -2.0), _trim_material)
	_add_box("MorningWindow", Vector3(0.08, 2.3, 4.8), Vector3(-7.54, 3.0, -2.0), _window_material)
	_add_box("WindowMullion", Vector3(0.1, 2.3, 0.08), Vector3(-7.47, 3.0, -2.0), _trim_material)
	_add_box("CurtainNear", Vector3(0.08, 2.45, 0.65), Vector3(-7.35, 3.0, -4.9), _curtain_material)
	_add_box("CurtainFar", Vector3(0.08, 2.45, 0.65), Vector3(-7.35, 3.0, 0.9), _curtain_material)
	_add_box("ExitDoorLeft", Vector3(0.12, 3.4, 0.2), Vector3(-1.92, 1.7, -10.65), _metal_material)
	_add_box("ExitDoorRight", Vector3(0.12, 3.4, 0.2), Vector3(1.92, 1.7, -10.65), _metal_material)
	_add_label("ExitSign", "WARD EXIT  →  MINATO-KASUMI", Vector3(0.0, 3.55, -10.5), 24, Color(0.38, 0.72, 0.64))

func _build_signage() -> void:
	_add_label("WardIdentity", "MINATO-KASUMI MEDICAL  /  ROOM 07", Vector3(7.52, 3.1, -7.5), 22, Color(0.32, 0.68, 0.82))
	_add_label("BedsideNotice", "RECOVERY WARD\nVISITOR HOURS  09:00–19:00", Vector3(7.52, 1.9, -6.6), 16, Color(0.58, 0.68, 0.72))

func _add_box(node_name: String, size: Vector3, at: Vector3, material: Material, collidable: bool = false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	visual.material_override = material
	visual.position = at
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if not collidable:
		add_child(visual)
		return
	var body := StaticBody3D.new()
	body.name = node_name + "Body"
	body.position = at
	add_child(body)
	visual.position = Vector3.ZERO
	body.add_child(visual)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

func _add_cylinder(node_name: String, radius: float, height: float, at: Vector3, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	node.position = at
	add_child(node)

func _add_label(node_name: String, text: String, at: Vector3, font_size: int, color: Color) -> void:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.004
	label.modulate = color
	label.outline_size = 5
	label.outline_modulate = Color(0.08, 0.12, 0.15, 1.0)
	label.position = at
	add_child(label)

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
