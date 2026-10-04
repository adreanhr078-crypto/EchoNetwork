extends Node3D

## Local authored ward kit; no campaign state, exit claim or runtime avatar swap.
## Bed/contact anchors are references, not an accepted character performance.
const MATTRESS_TOP := 0.70
const MATTRESS_SIZE := Vector3(2.12, 0.14, 0.96)
var bed_bounds := AABB(Vector3(-1.06, 0.56, -0.48), MATTRESS_SIZE)
var materials := {}

func _ready() -> void:
	materials = {
		"wall": _mat(Color(0.34, 0.39, 0.42), 0.90),
		"floor": _mat(Color(0.20, 0.25, 0.27), 0.72),
		"trim": _mat(Color(0.10, 0.15, 0.18), 0.72),
		"ivory": _mat(Color(0.73, 0.77, 0.73), 0.84),
		"linen": _mat(Color(0.67, 0.72, 0.73), 0.98),
		"fold": _mat(Color(0.47, 0.54, 0.56), 0.98),
		"steel": _mat(Color(0.29, 0.34, 0.37), 0.40, 0.65),
		"glass": _mat(Color(0.64, 0.76, 0.81), 0.38),
		"ink": _mat(Color(0.05, 0.08, 0.10), 0.95),
		"wood": _mat(Color(0.31, 0.25, 0.19), 0.84),
	}
	_room()
	_bed()
	_equipment()
	_anchors()
	_lighting()

func _room() -> void:
	_box("WardFloor", Vector3(6.4, 0.16, 5.8), Vector3(0, -0.08, 0), "floor", true)
	_box("HeadWall", Vector3(0.16, 3.2, 5.8), Vector3(-3.2, 1.6, 0), "wall", true)
	# Rear wall is broken around the actual window opening.
	_box("WindowSillWall", Vector3(6.4, 0.95, 0.16), Vector3(0, 0.475, -2.9), "wall", true)
	_box("WindowUpperWall", Vector3(6.4, 0.45, 0.16), Vector3(0, 2.975, -2.9), "wall", true)
	_box("WindowLeftPier", Vector3(1.8, 1.8, 0.16), Vector3(-2.3, 1.85, -2.9), "wall", true)
	_box("WindowRightPier", Vector3(1.8, 1.8, 0.16), Vector3(2.3, 1.85, -2.9), "wall", true)
	_box("Ceiling", Vector3(6.4, 0.14, 5.8), Vector3(0, 3.2, 0), "ivory")
	_box("HeadwallServicePanel", Vector3(0.12, 0.30, 2.05), Vector3(-3.06, 1.30, -0.1), "ivory")
	for z in [-0.70, -0.40, 0.0, 0.30]:
		_box("ServiceSocket", Vector3(0.025, 0.08, 0.08), Vector3(-2.989, 1.30, z), "trim")
	for x in [-1.40, 0.0, 1.40]:
		_box("WindowUpright", Vector3(0.07, 1.80, 0.10), Vector3(x, 1.85, -2.83), "ivory")
	for y in [0.99, 2.72]:
		_box("WindowHorizontal", Vector3(2.87, 0.07, 0.10), Vector3(0, y, -2.83), "ivory")
	# Local geometry for blind slats catches sunlight without a painted light map.
	for i in range(13):
		var slat := _box("DaylightBlindSlat", Vector3(2.74, 0.025, 0.11), Vector3(0, 1.07 + i * 0.127, -2.80), "ivory")
		slat.rotation.x = -0.40
	_box("WindowReveal", Vector3(2.75, 1.74, 0.015), Vector3(0, 1.85, -2.97), "glass")
	_box("WindowSill", Vector3(3.05, 0.07, 0.32), Vector3(0, 0.95, -2.76), "ivory")
	# Restrained panel seams and scuffed lower wall, authored with geometry.
	for z in [-2.0, -1.0, 0.0, 1.0, 2.0]:
		_box("HeadwallSeam", Vector3(0.004, 2.90, 0.008), Vector3(-3.111, 1.52, z), "trim")
	_box("Baseboard", Vector3(0.035, 0.12, 5.62), Vector3(-3.09, 0.08, 0), "trim")
	for i in range(9):
		_box("FloorJoint", Vector3(6.2, 0.001, 0.006), Vector3(0, 0.001, -2.65 + i * 0.66), "trim")
	for i in range(7):
		_box("FloorJoint", Vector3(0.006, 0.001, 5.5), Vector3(-2.90 + i * 0.96, 0.001, 0), "trim")

func _bed() -> void:
	_box("BedDeck", Vector3(2.24, 0.11, 1.02), Vector3(0, 0.505, 0), "steel", true)
	_box("Mattress", MATTRESS_SIZE, Vector3(0, 0.63, 0), "linen", true)
	_box("MattressPipingNear", Vector3(2.08, 0.012, 0.014), Vector3(0, 0.67, 0.485), "fold")
	_box("MattressPipingFar", Vector3(2.08, 0.012, 0.014), Vector3(0, 0.67, -0.485), "fold")
	for x in [-0.82, 0.82]:
		for z in [-0.38, 0.38]:
			_cylinder("BedLeg", 0.035, 0.35, Vector3(x, 0.31, z), "steel")
			var wheel := _cylinder("LockingCaster", 0.067, 0.040, Vector3(x, 0.067, z), "trim")
			wheel.rotation.x = PI / 2.0
			_box("CasterLock", Vector3(0.07, 0.025, 0.04), Vector3(x + 0.025, 0.135, z), "steel")
	for x in [-1.16, 1.16]:
		_box("BedEndPanel", Vector3(0.08, 0.35, 1.06), Vector3(x, 0.77, 0), "ivory")
		_box("EndPanelHandle", Vector3(0.012, 0.07, 0.40), Vector3(x + signf(x) * 0.046, 0.83, 0), "trim")
	for z in [-0.56, 0.56]:
		_box("LowerSideRail", Vector3(1.23, 0.04, 0.035), Vector3(0.18, 0.71, z), "steel")
		for x in [-0.43, 0.78]:
			_box("RailPost", Vector3(0.03, 0.13, 0.03), Vector3(x, 0.76, z), "steel")
	# Pillow belongs to the bed kit, not to a claimed pose performance.
	var pillow := MeshInstance3D.new()
	pillow.name = "Pillow"
	var cushion := SphereMesh.new()
	cushion.radius = 0.5
	cushion.height = 1.0
	cushion.radial_segments = 20
	cushion.rings = 8
	pillow.mesh = cushion
	pillow.material_override = materials.ivory
	pillow.position = Vector3(-0.77, 0.75, 0)
	pillow.scale = Vector3(0.44, 0.10, 0.68)
	add_child(pillow)
	pillow.rotation.z = -0.08
	_box("PillowSeam", Vector3(0.43, 0.003, 0.015), Vector3(-0.77, 0.802, 0.22), "linen")
	# Folded cover leaves a real contact surface for isolated character work.
	_box("FoldedCover", Vector3(0.40, 0.09, 0.92), Vector3(0.80, 0.745, 0), "linen")
	for x in [0.63, 0.68, 0.76, 0.87, 0.95]:
		_box("CoverFold", Vector3(0.012, 0.004, 0.87), Vector3(x, 0.793, 0), "fold")

func _equipment() -> void:
	_box("BedsideCabinet", Vector3(0.65, 0.66, 0.48), Vector3(-0.76, 0.33, -1.13), "wood", true)
	_box("CabinetTop", Vector3(0.71, 0.045, 0.54), Vector3(-0.76, 0.682, -1.13), "ivory")
	for y in [0.28, 0.49]:
		_box("CabinetDrawer", Vector3(0.57, 0.15, 0.015), Vector3(-0.76, y, -0.883), "wood")
		_box("DrawerHandle", Vector3(0.16, 0.014, 0.028), Vector3(-0.76, y, -0.861), "steel")
	_cylinder("WaterCup", 0.042, 0.12, Vector3(-0.53, 0.765, -1.07), "ivory")
	_box("TissueBox", Vector3(0.20, 0.08, 0.13), Vector3(-0.87, 0.745, -1.12), "linen")
	_cylinder("MonitorPole", 0.024, 1.22, Vector3(-1.52, 0.68, -1.09), "steel")
	_box("MonitorBase", Vector3(0.45, 0.045, 0.44), Vector3(-1.52, 0.055, -1.09), "steel")
	_box("MonitorCase", Vector3(0.53, 0.40, 0.12), Vector3(-1.52, 1.41, -1.09), "ivory")
	_box("MonitorGlass", Vector3(0.46, 0.30, 0.005), Vector3(-1.52, 1.42, -1.024), "ink")
	# Static authored trace, no invented clinical state or simulation answer.
	var line_mat := _mat(Color(0.22, 0.46, 0.43), 0.75)
	for i in range(23):
		var trace := _box("StaticMonitorTrace", Vector3(0.017, 0.009, 0.002), Vector3(-1.72 + i * 0.018, 1.43 + (0.075 if i == 10 else (-0.04 if i == 11 else 0.0)), -1.019), "ink")
		trace.material_override = line_mat
	_cylinder("IVPole", 0.014, 1.92, Vector3(-1.34, 0.99, 0.92), "steel")
	_cylinder("IVBase", 0.22, 0.035, Vector3(-1.34, 0.035, 0.92), "steel")
	_box("IVHook", Vector3(0.24, 0.014, 0.014), Vector3(-1.34, 1.96, 0.92), "steel")
	_box("IVBag", Vector3(0.13, 0.22, 0.07), Vector3(-1.43, 1.78, 0.92), "glass")
	_box("IVTube", Vector3(0.004, 0.80, 0.004), Vector3(-1.43, 1.26, 0.92), "glass")
	_box("VisitorChairSeat", Vector3(0.48, 0.07, 0.44), Vector3(1.78, 0.48, -1.55), "wood")
	_box("VisitorChairBack", Vector3(0.48, 0.46, 0.06), Vector3(1.78, 0.74, -1.76), "wood")
	for x in [1.60, 1.96]:
		for z in [-1.71, -1.39]:
			_box("VisitorChairLeg", Vector3(0.035, 0.43, 0.035), Vector3(x, 0.23, z), "steel")

func _anchors() -> void:
	var anchors := {"BedFeetAnchor": Vector3(0.92, 0.70, 0), "BedHeadAnchor": Vector3(-0.78, 0.80, 0), "BedsideInspectAnchor": Vector3(-0.30, 0, 1.18), "EX011SkinCameraTarget": Vector3(-0.54, 0.99, 0), "SeatedPelvisAnchor": Vector3(-0.30, 0.70, 0.15)}
	for key in anchors:
		var marker := Marker3D.new()
		marker.name = key
		marker.position = anchors[key]
		add_child(marker)

func _lighting() -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.27, 0.35, 0.42)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.65, 0.72, 0.80)
	world.environment.ambient_light_energy = 0.48
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "WardDaylight"
	sun.rotation_degrees = Vector3(-48, -20, 0)
	sun.light_color = Color(0.95, 0.91, 0.83)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.light_angular_distance = 2.0
	add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0.7, 2.5, -2.20)
	fill.light_color = Color(0.70, 0.81, 0.91)
	fill.light_energy = 0.65
	fill.omni_range = 5.2
	add_child(fill)

func _box(node_name: String, size: Vector3, at: Vector3, material_key: String, collidable: bool = false) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = BoxMesh.new()
	visual.mesh.size = size
	visual.material_override = materials[material_key]
	visual.position = at
	add_child(visual)
	if collidable:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = size
		body.add_child(shape)
		visual.add_child(body)
	return visual

func _cylinder(node_name: String, radius: float, height: float, at: Vector3, material_key: String) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 12
	visual.mesh = cylinder
	visual.material_override = materials[material_key]
	visual.position = at
	add_child(visual)
	return visual

func _mat(color: Color, surface_roughness: float, surface_metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = surface_roughness
	material.metallic = surface_metallic
	return material
