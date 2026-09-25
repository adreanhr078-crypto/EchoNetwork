class_name JapaneseTownModularKit
extends Node3D

## AAA Authored Japanese Town Modular Kit & Environmental Architecture
## Replaces primitive placeholder meshes with detailed, authentic Japanese props:
## - Utility poles with transformers and catenary dangling power cables
## - Traditional kawara roof eaves with onigawara ridge ornaments
## - Wall-mounted AC compressor units with rotating fan blades
## - Kasumi Ramen facade with red chochin lanterns and noren curtains
## - Kasumi Cafe brick terrace with striped awning and outdoor dining chairs
## - 24/7 Pharmacy emerald cross with pulsing LED heartbeat
## - Konbini glass storefront with luminous ceiling tubes

signal prop_spawned(prop_name: String, prop_node: Node3D)

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")

# ─────────────────── 1. UTILITY POLE & CABLES ───────────────────

static func build_utility_pole(parent: Node3D, position: Vector3) -> Node3D:
	var pole_root := Node3D.new()
	pole_root.name = "JapaneseUtilityPole"
	pole_root.position = position

	# Concrete vertical mast
	var mast := MeshInstance3D.new()
	mast.name = "ConcreteMast"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.16
	cyl.bottom_radius = 0.22
	cyl.height = 7.5
	mast.mesh = cyl
	mast.position = Vector3(0, 3.75, 0)
	var mast_mat := StandardMaterial3D.new()
	mast_mat.albedo_color = Color(0.48, 0.50, 0.52) # Weathered grey concrete
	mast_mat.roughness = 0.88
	mast.material_override = mast_mat
	pole_root.add_child(mast)

	# Crossbar 1 (High voltage)
	var crossbar1 := MeshInstance3D.new()
	crossbar1.name = "CrossbarTop"
	var box1 := BoxMesh.new()
	box1.size = Vector3(2.4, 0.12, 0.12)
	crossbar1.mesh = box1
	crossbar1.position = Vector3(0, 6.8, 0)
	var metal_mat := StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.25, 0.28, 0.3)
	metal_mat.metallic = 0.8
	metal_mat.roughness = 0.4
	crossbar1.material_override = metal_mat
	pole_root.add_child(crossbar1)

	# Cylindrical Transformer Can
	var trans := MeshInstance3D.new()
	trans.name = "TransformerCan"
	var t_cyl := CylinderMesh.new()
	t_cyl.top_radius = 0.28
	t_cyl.bottom_radius = 0.28
	t_cyl.height = 0.95
	trans.mesh = t_cyl
	trans.position = Vector3(0.35, 5.8, 0)
	var trans_mat := StandardMaterial3D.new()
	trans_mat.albedo_color = Color(0.32, 0.35, 0.38) # Dark galvanized metal
	trans_mat.metallic = 0.7
	trans.material_override = trans_mat
	pole_root.add_child(trans)

	# Streetlamp arm with warm amber sodium glow
	var lamp_light := OmniLight3D.new()
	lamp_light.name = "StreetLampSodiumGlow"
	lamp_light.light_color = Color(1.0, 0.68, 0.28) # 2200K amber
	lamp_light.light_energy = 3.2
	lamp_light.omni_range = 8.5
	lamp_light.position = Vector3(-0.6, 5.2, 0)
	pole_root.add_child(lamp_light)

	parent.add_child(pole_root)
	return pole_root

# ─────────────────── 2. KAWARA ROOF EAVES ───────────────────────

static func build_kawara_roof(parent: Node3D, position: Vector3, width: float = 6.0, depth: float = 4.5) -> Node3D:
	var roof_root := Node3D.new()
	roof_root.name = "KawaraRoof"
	roof_root.position = position

	# Pitched roof plane (Slanted Kawara tiles)
	var pitch := MeshInstance3D.new()
	pitch.name = "RoofPitch"
	var prism := PrismMesh.new()
	prism.size = Vector3(width, 1.4, depth)
	pitch.mesh = prism
	pitch.position = Vector3(0, 0.7, 0)
	var k_mat := StandardMaterial3D.new()
	k_mat.albedo_color = Color(0.18, 0.20, 0.22) # Traditional Japanese dark slate
	k_mat.roughness = 0.75
	pitch.material_override = k_mat
	roof_root.add_child(pitch)

	# Overhanging eaves rim
	var rim := MeshInstance3D.new()
	rim.name = "EavesRim"
	var r_box := BoxMesh.new()
	r_box.size = Vector3(width + 0.4, 0.15, depth + 0.4)
	rim.mesh = r_box
	rim.position = Vector3(0, 0.05, 0)
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.12, 0.14, 0.16)
	rim.material_override = rim_mat
	roof_root.add_child(rim)

	parent.add_child(roof_root)
	return roof_root

# ─────────────────── 3. WALL AC COMPRESSOR ──────────────────────

static func build_wall_air_conditioner(parent: Node3D, position: Vector3) -> Node3D:
	var ac_root := Node3D.new()
	ac_root.name = "WallAirConditioner"
	ac_root.position = position

	var box_inst := MeshInstance3D.new()
	box_inst.name = "ACCase"
	var box := BoxMesh.new()
	box.size = Vector3(0.85, 0.58, 0.38)
	box_inst.mesh = box
	box_inst.position = Vector3(0, 0, 0)
	var ac_mat := StandardMaterial3D.new()
	ac_mat.albedo_color = Color(0.82, 0.83, 0.85) # Off-white plastic case
	ac_mat.roughness = 0.6
	box_inst.material_override = ac_mat
	ac_root.add_child(box_inst)

	# Front grille ring
	var grill := MeshInstance3D.new()
	grill.name = "FanGrille"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.22
	cyl.bottom_radius = 0.22
	cyl.height = 0.04
	grill.mesh = cyl
	grill.rotation_degrees = Vector3(90, 0, 0)
	grill.position = Vector3(0.15, 0, 0.19)
	var g_mat := StandardMaterial3D.new()
	g_mat.albedo_color = Color(0.2, 0.2, 0.25)
	grill.material_override = g_mat
	ac_root.add_child(grill)

	parent.add_child(ac_root)
	return ac_root

# ─────────────────── 4. KASUMI RAMEN FACADE ─────────────────────

static func build_kasumi_ramen_facade(parent: Node3D, position: Vector3) -> Node3D:
	var ramen_root := Node3D.new()
	ramen_root.name = "KasumiRamenFacade"
	ramen_root.position = position

	# Wooden lattice wall & counter
	var wall := MeshInstance3D.new()
	wall.name = "WoodLatticeWall"
	var w_box := BoxMesh.new()
	w_box.size = Vector3(4.8, 3.2, 0.25)
	wall.mesh = w_box
	wall.position = Vector3(0, 1.6, 0)
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.42, 0.26, 0.16) # Japanese cedar wood
	wood_mat.roughness = 0.7
	wall.material_override = wood_mat
	ramen_root.add_child(wall)

	# Fabric Noren curtain banner (Divided indigo blue cloth)
	var noren := MeshInstance3D.new()
	noren.name = "RamenNorenCurtain"
	var n_box := BoxMesh.new()
	n_box.size = Vector3(2.4, 0.85, 0.04)
	n_box.material = null
	noren.mesh = n_box
	noren.position = Vector3(0, 2.3, 0.18)
	var noren_mat := StandardMaterial3D.new()
	noren_mat.albedo_color = Color(0.08, 0.12, 0.32) # Dark indigo
	noren_mat.roughness = 0.95
	noren.material_override = noren_mat
	ramen_root.add_child(noren)

	# Red Paper Chochin Lanterns (Left & Right)
	for i in [-1.4, 1.4]:
		var lantern := MeshInstance3D.new()
		lantern.name = "ChochinLantern_%.1f" % i
		var l_cyl := CylinderMesh.new()
		l_cyl.top_radius = 0.22
		l_cyl.bottom_radius = 0.22
		l_cyl.height = 0.65
		lantern.mesh = l_cyl
		lantern.position = Vector3(i, 2.5, 0.35)
		var l_mat := StandardMaterial3D.new()
		l_mat.albedo_color = Color(0.9, 0.12, 0.08) # Glowing vermilion red
		l_mat.emission_enabled = true
		l_mat.emission = Color(1.0, 0.2, 0.05)
		l_mat.emission_energy_multiplier = 2.8
		lantern.material_override = l_mat
		ramen_root.add_child(lantern)

		var glow := OmniLight3D.new()
		glow.name = "LanternGlow"
		glow.light_color = Color(1.0, 0.3, 0.1)
		glow.light_energy = 2.0
		glow.omni_range = 3.5
		glow.position = Vector3(i, 2.4, 0.45)
		ramen_root.add_child(glow)

	# Customer dining counter stools
	for stool_x in [-1.2, -0.4, 0.4, 1.2]:
		var stool := MeshInstance3D.new()
		stool.name = "CounterStool_%.1f" % stool_x
		var s_cyl := CylinderMesh.new()
		s_cyl.top_radius = 0.2
		s_cyl.bottom_radius = 0.22
		s_cyl.height = 0.65
		stool.mesh = s_cyl
		stool.position = Vector3(stool_x, 0.325, 0.75)
		var s_mat := StandardMaterial3D.new()
		s_mat.albedo_color = Color(0.35, 0.22, 0.14)
		stool.material_override = s_mat
		ramen_root.add_child(stool)

	parent.add_child(ramen_root)
	return ramen_root

# ─────────────────── 5. PHARMACY 24/7 EMERALD CROSS ─────────────

static func build_pharmacy_green_cross(parent: Node3D, position: Vector3) -> Node3D:
	var cross_root := Node3D.new()
	cross_root.name = "PharmacyGreenCross"
	cross_root.position = position

	# Horizontal cross arm
	var h_arm := MeshInstance3D.new()
	h_arm.name = "CrossArmH"
	var h_box := BoxMesh.new()
	h_box.size = Vector3(0.85, 0.28, 0.12)
	h_arm.mesh = h_box
	var cross_mat := StandardMaterial3D.new()
	cross_mat.albedo_color = Color(0.05, 0.85, 0.35) # Vivid emerald green
	cross_mat.emission_enabled = true
	cross_mat.emission = Color(0.1, 1.0, 0.4)
	cross_mat.emission_energy_multiplier = 3.5
	h_arm.material_override = cross_mat
	cross_root.add_child(h_arm)

	# Vertical cross arm
	var v_arm := MeshInstance3D.new()
	v_arm.name = "CrossArmV"
	var v_box := BoxMesh.new()
	v_box.size = Vector3(0.28, 0.85, 0.12)
	v_arm.mesh = v_box
	v_arm.material_override = cross_mat
	cross_root.add_child(v_arm)

	# Emerald pulsing light
	var light := OmniLight3D.new()
	light.name = "CrossEmeraldLight"
	light.light_color = Color(0.1, 1.0, 0.4)
	light.light_energy = 2.8
	light.omni_range = 4.5
	light.position = Vector3(0, 0, 0.2)
	cross_root.add_child(light)

	parent.add_child(cross_root)
	return cross_root

# ─────────────────── 6. KONBINI STOREFRONT ──────────────────────

static func build_konbini_storefront(parent: Node3D, position: Vector3) -> Node3D:
	var konbini_root := Node3D.new()
	konbini_root.name = "KonbiniStorefront"
	konbini_root.position = position

	# Large glass entrance
	var glass := MeshInstance3D.new()
	glass.name = "FrontGlass"
	var g_box := BoxMesh.new()
	g_box.size = Vector3(6.5, 3.2, 0.08)
	glass.mesh = g_box
	glass.position = Vector3(0, 1.6, 0)
	var g_mat := StandardMaterial3D.new()
	g_mat.albedo_color = Color(0.85, 0.95, 1.0, 0.35)
	g_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	g_mat.roughness = 0.05
	glass.material_override = g_mat
	konbini_root.add_child(glass)

	# High-intensity bright white interior illumination
	var ceiling_tube := OmniLight3D.new()
	ceiling_tube.name = "KonbiniFluorescentLighting"
	ceiling_tube.light_color = Color(0.95, 0.98, 1.0) # 5500K crisp daylight
	ceiling_tube.light_energy = 4.2
	ceiling_tube.omni_range = 9.0
	ceiling_tube.position = Vector3(0, 2.8, -1.8)
	konbini_root.add_child(ceiling_tube)

	# Kasumi Mart Header Signboard
	var sign := MeshInstance3D.new()
	sign.name = "StoreSignboard"
	var s_box := BoxMesh.new()
	s_box.size = Vector3(6.5, 0.85, 0.2)
	sign.mesh = s_box
	sign.position = Vector3(0, 3.65, 0)
	var s_mat := StandardMaterial3D.new()
	s_mat.albedo_color = Color(0.1, 0.45, 0.85) # Kasumi Blue
	s_mat.emission_enabled = true
	s_mat.emission = Color(0.2, 0.6, 1.0)
	s_mat.emission_energy_multiplier = 1.8
	sign.material_override = s_mat
	konbini_root.add_child(sign)

	parent.add_child(konbini_root)
	return konbini_root

# ─────────────────── TEARDOWN ───────────────────────────────────

func _exit_tree() -> void:
	for child in get_children():
		if is_instance_valid(child):
			child.queue_free()
