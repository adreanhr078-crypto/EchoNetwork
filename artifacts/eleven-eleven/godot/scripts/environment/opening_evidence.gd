extends Node3D
class_name OpeningEvidence

signal evidence_inspected(evidence_id: String)

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")

@export_enum("clock", "photo") var evidence_id := "clock"
var inspected := false

var _beacon_mesh: MeshInstance3D
var _beacon_light: OmniLight3D
var _ring_mesh: MeshInstance3D
var _orbit_ring_1: MeshInstance3D
var _orbit_ring_2: MeshInstance3D
var _cloche_mesh: MeshInstance3D
var _cloche_mat: StandardMaterial3D
var _pulse_time: float = 0.0

func _ready() -> void:
	$ClockFace.visible = evidence_id == "clock"
	$ClockHands.visible = evidence_id == "clock"
	$PhotoFrame.visible = evidence_id == "photo"
	$PhotoTrace.visible = evidence_id == "photo"
	$EvidenceLabel.text = "11:11" if evidence_id == "clock" else "// 11 //"
	$EvidenceLabel.position = Vector3(0.0, 1.55, 0.0)
	$InteractionArea.prompt_target_name = "11:11 CHRONOMETER" if evidence_id == "clock" else "TORN PHOTOGRAPH"

	_setup_pedestal_and_props()
	_setup_holographic_beacon()

func _setup_pedestal_and_props() -> void:
	# 1. Architectural Pedestal Base (Plinth grounded on the floor)
	var pedestal := Node3D.new()
	pedestal.name = "Pedestal"
	
	var obsidian_mat := StandardMaterial3D.new()
	obsidian_mat.albedo_color = Color(0.065, 0.08, 0.11)
	obsidian_mat.metallic = 0.92
	obsidian_mat.roughness = 0.18
	
	var accent_color := Color(0.0, 0.90, 1.0) if evidence_id == "clock" else Color(0.85, 0.3, 1.0)
	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = accent_color
	trim_mat.emission_enabled = true
	trim_mat.emission = accent_color
	trim_mat.emission_energy_multiplier = 2.4
	
	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color(1.0, 0.83, 0.36)
	gold_mat.metallic = 0.96
	gold_mat.roughness = 0.15
	gold_mat.emission_enabled = true
	gold_mat.emission = Color(1.0, 0.83, 0.36)
	gold_mat.emission_energy_multiplier = 0.85
	
	# Chamfered Octagonal Plinth Base (0.42m radius, 0.12m height)
	var base_mesh := MeshInstance3D.new()
	base_mesh.name = "PedestalBase"
	var base_cyl := CylinderMesh.new()
	base_cyl.radial_segments = 8
	base_cyl.top_radius = 0.38
	base_cyl.bottom_radius = 0.44
	base_cyl.height = 0.12
	base_mesh.mesh = base_cyl
	base_mesh.position = Vector3(0.0, 0.06, 0.0)
	base_mesh.material_override = obsidian_mat
	pedestal.add_child(base_mesh)
	
	# Pedestal Tapered Column (0.32m to 0.26m radius, 0.76m height)
	var col_mesh := MeshInstance3D.new()
	col_mesh.name = "PedestalColumn"
	var col_cyl := CylinderMesh.new()
	col_cyl.radial_segments = 12
	col_cyl.top_radius = 0.26
	col_cyl.bottom_radius = 0.32
	col_cyl.height = 0.76
	col_mesh.mesh = col_cyl
	col_mesh.position = Vector3(0.0, 0.50, 0.0)
	col_mesh.material_override = obsidian_mat
	pedestal.add_child(col_mesh)
	
	# Vertical Neon Cooling Flutes on Column
	for f in range(4):
		var flute := MeshInstance3D.new()
		var flute_box := BoxMesh.new()
		flute_box.size = Vector3(0.02, 0.68, 0.02)
		flute.mesh = flute_box
		var angle := f * (PI / 2.0)
		flute.position = Vector3(sin(angle) * 0.27, 0.50, cos(angle) * 0.27)
		flute.rotation.y = angle
		flute.material_override = trim_mat
		pedestal.add_child(flute)
	
	# Glowing Neon Trim Ring at top of column
	var trim_mesh := MeshInstance3D.new()
	trim_mesh.name = "PedestalTrim"
	var trim_torus := TorusMesh.new()
	trim_torus.inner_radius = 0.26
	trim_torus.outer_radius = 0.29
	trim_mesh.mesh = trim_torus
	trim_mesh.position = Vector3(0.0, 0.88, 0.0)
	trim_mesh.material_override = trim_mat
	pedestal.add_child(trim_mesh)
	
	# Ergonomic Console Top Platter (Elevated to 0.94m, angled 24 degrees toward player approach)
	var top_mesh := MeshInstance3D.new()
	top_mesh.name = "ConsoleTop"
	var top_box := BoxMesh.new()
	top_box.size = Vector3(0.48, 0.04, 0.48)
	top_mesh.mesh = top_box
	top_mesh.position = Vector3(0.0, 0.94, 0.0)
	top_mesh.rotation = Vector3(deg_to_rad(24.0), deg_to_rad(75.0), 0.0)
	top_mesh.material_override = obsidian_mat
	pedestal.add_child(top_mesh)
	
	# Recessed Circular Display Cushion on Platter
	var cushion_mesh := MeshInstance3D.new()
	cushion_mesh.name = "DisplayCushion"
	var cushion_cyl := CylinderMesh.new()
	cushion_cyl.top_radius = 0.20
	cushion_cyl.bottom_radius = 0.21
	cushion_cyl.height = 0.015
	cushion_mesh.mesh = cushion_cyl
	cushion_mesh.position = Vector3(0.0, 0.022, 0.0)
	var velvet_mat := StandardMaterial3D.new()
	velvet_mat.albedo_color = Color(0.03, 0.04, 0.065)
	velvet_mat.roughness = 0.75
	cushion_mesh.material_override = velvet_mat
	top_mesh.add_child(cushion_mesh)
	
	add_child(pedestal)

	if evidence_id == "clock":
		# Position clock centered on the angled console cushion
		$ClockFace.position = Vector3(0.0, 0.965, 0.0)
		$ClockFace.rotation = Vector3(deg_to_rad(24.0), deg_to_rad(75.0), 0.0)
		
		# Detailed Beveled Outer Casing in Polished Antique Gold
		var bezel_mesh := CylinderMesh.new()
		bezel_mesh.top_radius = 0.185
		bezel_mesh.bottom_radius = 0.195
		bezel_mesh.height = 0.034
		$ClockFace.mesh = bezel_mesh
		$ClockFace.material_override = gold_mat
		
		# Open Hunter Case Lid (Tilted back 65 degrees)
		var lid := MeshInstance3D.new()
		lid.name = "PocketWatchLid"
		var lid_mesh := CylinderMesh.new()
		lid_mesh.top_radius = 0.185
		lid_mesh.bottom_radius = 0.190
		lid_mesh.height = 0.012
		lid.mesh = lid_mesh
		lid.position = Vector3(0.0, 0.075, -0.185)
		lid.rotation.x = deg_to_rad(-65.0)
		lid.material_override = gold_mat
		$ClockFace.add_child(lid)
		
		# Top Winding Crown & Bow Loop at 12 o'clock (-Z)
		var crown := MeshInstance3D.new()
		crown.name = "WindingCrown"
		var crown_cyl := CylinderMesh.new()
		crown_cyl.top_radius = 0.022
		crown_cyl.bottom_radius = 0.022
		crown_cyl.height = 0.028
		crown.mesh = crown_cyl
		crown.position = Vector3(0.0, 0.012, -0.215)
		crown.rotation.x = deg_to_rad(90.0)
		crown.material_override = gold_mat
		$ClockFace.add_child(crown)
		
		var bow := MeshInstance3D.new()
		bow.name = "BowRing"
		var bow_torus := TorusMesh.new()
		bow_torus.inner_radius = 0.030
		bow_torus.outer_radius = 0.042
		bow.mesh = bow_torus
		bow.position = Vector3(0.0, 0.012, -0.252)
		bow.rotation.x = deg_to_rad(90.0)
		bow.material_override = gold_mat
		$ClockFace.add_child(bow)
		
		# Draped Golden Chain Links curving onto cushion
		for c in range(8):
			var link := MeshInstance3D.new()
			var link_torus := TorusMesh.new()
			link_torus.inner_radius = 0.010
			link_torus.outer_radius = 0.016
			link.mesh = link_torus
			var progress := float(c) / 7.0
			var chain_z := -0.25 + progress * 0.32
			var chain_x := sin(progress * PI) * 0.10
			var chain_y := 0.008 - sin(progress * PI) * 0.03
			link.position = Vector3(chain_x, chain_y, chain_z)
			link.rotation = Vector3(deg_to_rad(25.0 * c), deg_to_rad(40.0), 0.0)
			link.material_override = gold_mat
			$ClockFace.add_child(link)
		
		# Inner Porcelain Dark Enamel Dial Face
		var dial := MeshInstance3D.new()
		dial.name = "ClockDial"
		var dial_cyl := CylinderMesh.new()
		dial_cyl.top_radius = 0.170
		dial_cyl.bottom_radius = 0.170
		dial_cyl.height = 0.006
		dial.mesh = dial_cyl
		dial.position = Vector3(0.0, 0.018, 0.0)
		
		var dial_mat := StandardMaterial3D.new()
		dial_mat.albedo_color = Color(0.015, 0.025, 0.045)
		dial_mat.metallic = 0.75
		dial_mat.roughness = 0.12
		dial.material_override = dial_mat
		$ClockFace.add_child(dial)
		
		# Dedicated Luminescent Material for 11:11 Hour & Minute Highlight
		var eleven_mat := StandardMaterial3D.new()
		eleven_mat.albedo_color = Color(0.0, 0.95, 1.0)
		eleven_mat.metallic = 0.95
		eleven_mat.roughness = 0.06
		eleven_mat.emission_enabled = true
		eleven_mat.emission = Color(0.0, 0.95, 1.0)
		eleven_mat.emission_energy_multiplier = 4.2
		eleven_mat.rim_enabled = true
		eleven_mat.rim = 1.0
		eleven_mat.rim_tint = 0.85

		# Radial Hour Ticks (Hour 11 and Minute 11 Highlighted in Cyan Neon)
		for h in range(12):
			var tick := MeshInstance3D.new()
			var tick_mesh := BoxMesh.new()
			var is_eleven := (h == 11)
			tick_mesh.size = Vector3(0.012 if not is_eleven else 0.024, 0.006, 0.028 if not is_eleven else 0.046)
			tick.mesh = tick_mesh
			var angle := deg_to_rad(h * 30.0)
			tick.position = Vector3(sin(angle) * 0.138, 0.004, -cos(angle) * 0.138)
			tick.rotation.y = -angle
			tick.material_override = eleven_mat if is_eleven else gold_mat
			dial.add_child(tick)
		
		# Hour Hand (pointed at 11:00 / 335.5 deg) with luminescent strip
		$ClockHands.position = Vector3(0.0, 0.024, 0.0)
		$ClockHands.rotation = Vector3.ZERO
		var h_box := BoxMesh.new()
		h_box.size = Vector3(0.016, 0.006, 0.095)
		$ClockHands.mesh = h_box
		var h_angle := deg_to_rad(335.5)
		$ClockHands.rotation.y = -h_angle
		$ClockHands.position = Vector3(sin(h_angle) * 0.042, 0.024, -cos(h_angle) * 0.042)
		var hand_gold := StandardMaterial3D.new()
		hand_gold.albedo_color = Color(1.0, 0.88, 0.42)
		hand_gold.metallic = 0.98
		hand_gold.roughness = 0.08
		hand_gold.emission_enabled = true
		hand_gold.emission = Color(0.0, 0.92, 1.0)
		hand_gold.emission_energy_multiplier = 3.6
		hand_gold.rim_enabled = true
		hand_gold.rim = 1.0
		hand_gold.rim_tint = 0.75
		$ClockHands.material_override = hand_gold
		
		# Minute Hand (pointed at 11 min / 66 deg)
		var min_hand := MeshInstance3D.new()
		min_hand.name = "MinuteHand"
		var m_box := BoxMesh.new()
		m_box.size = Vector3(0.011, 0.006, 0.135)
		min_hand.mesh = m_box
		var m_angle := deg_to_rad(66.0)
		min_hand.rotation.y = -m_angle
		min_hand.position = Vector3(sin(m_angle) * 0.060, 0.026, -cos(m_angle) * 0.060)
		min_hand.material_override = hand_gold
		$ClockFace.add_child(min_hand)
		
		# Center Jewel Pin
		var pin := MeshInstance3D.new()
		var pin_cyl := CylinderMesh.new()
		pin_cyl.top_radius = 0.016
		pin_cyl.bottom_radius = 0.016
		pin_cyl.height = 0.014
		pin.mesh = pin_cyl
		pin.position = Vector3(0.0, 0.028, 0.0)
		pin.material_override = trim_mat
		$ClockFace.add_child(pin)
		
		# Protective Crystal Glass Cloche (Display Dome - 48 radial segments)
		_cloche_mesh = MeshInstance3D.new()
		_cloche_mesh.name = "GlassCloche"
		var dome_mesh := CylinderMesh.new()
		dome_mesh.radial_segments = 48
		dome_mesh.top_radius = 0.22
		dome_mesh.bottom_radius = 0.232
		dome_mesh.height = 0.24
		_cloche_mesh.mesh = dome_mesh
		_cloche_mesh.position = Vector3(0.0, 0.125, 0.0)
		
		_cloche_mat = StandardMaterial3D.new()
		_cloche_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_cloche_mat.albedo_color = Color(0.75, 0.94, 1.0, 0.18)
		_cloche_mat.metallic = 0.18
		_cloche_mat.roughness = 0.02
		_cloche_mat.clearcoat_enabled = true
		_cloche_mat.clearcoat = 1.0
		_cloche_mat.clearcoat_roughness = 0.02
		_cloche_mat.rim_enabled = true
		_cloche_mat.rim = 1.0
		_cloche_mat.rim_tint = 0.85
		_cloche_mat.emission_enabled = true
		_cloche_mat.emission = Color(0.0, 0.88, 1.0)
		_cloche_mat.emission_energy_multiplier = 0.28
		_cloche_mesh.material_override = _cloche_mat
		$ClockFace.add_child(_cloche_mesh)
		
		# Crystal Cloche Crown Finial
		var finial := MeshInstance3D.new()
		finial.name = "ClocheFinial"
		var finial_sphere := SphereMesh.new()
		finial_sphere.radial_segments = 24
		finial_sphere.rings = 12
		finial_sphere.radius = 0.026
		finial_sphere.height = 0.052
		finial.mesh = finial_sphere
		finial.position = Vector3(0.0, 0.122, 0.0)
		finial.material_override = _cloche_mat
		_cloche_mesh.add_child(finial)
		
		# Cloche Base Gold Trim Ring
		var base_ring := MeshInstance3D.new()
		base_ring.name = "ClocheBaseRing"
		var ring_torus := TorusMesh.new()
		ring_torus.inner_radius = 0.225
		ring_torus.outer_radius = 0.238
		base_ring.mesh = ring_torus
		base_ring.position = Vector3(0.0, -0.118, 0.0)
		base_ring.material_override = gold_mat
		_cloche_mesh.add_child(base_ring)
	elif evidence_id == "photo":
		$PhotoFrame.position = Vector3(0.0, 0.965, 0.0)
		$PhotoFrame.rotation = Vector3(deg_to_rad(24.0), deg_to_rad(75.0), 0.0)
		$PhotoTrace.position = Vector3(0.0, 0.970, 0.0)
		$PhotoTrace.rotation = Vector3(deg_to_rad(24.0), deg_to_rad(75.0), 0.0)

func _setup_holographic_beacon() -> void:
	var color := Color(0.0, 0.90, 1.0, 0.40) if evidence_id == "clock" else Color(0.85, 0.30, 1.0, 0.40)

	# 1. Soft Vertical Holographic Light Beam (Pillar)
	_beacon_mesh = MeshInstance3D.new()
	_beacon_mesh.name = "HolographicBeacon"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.28
	cyl.height = 3.2
	_beacon_mesh.mesh = cyl
	_beacon_mesh.position = Vector3(0.0, 1.7, 0.0)

	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_mat.albedo_color = color
	_beacon_mesh.material_override = beam_mat
	add_child(_beacon_mesh)

	# 2. Concentric Orbiting Data Ring 1 (Upper Horizontal Ring)
	_orbit_ring_1 = MeshInstance3D.new()
	_orbit_ring_1.name = "OrbitRing1"
	var orbit_torus_1 := TorusMesh.new()
	orbit_torus_1.inner_radius = 0.26
	orbit_torus_1.outer_radius = 0.285
	_orbit_ring_1.mesh = orbit_torus_1
	_orbit_ring_1.position = Vector3(0.0, 1.25, 0.0)
	_orbit_ring_1.material_override = beam_mat
	add_child(_orbit_ring_1)

	# 3. Concentric Orbiting Data Ring 2 (Tilted Gimbal Ring)
	_orbit_ring_2 = MeshInstance3D.new()
	_orbit_ring_2.name = "OrbitRing2"
	var orbit_torus_2 := TorusMesh.new()
	orbit_torus_2.inner_radius = 0.31
	orbit_torus_2.outer_radius = 0.335
	_orbit_ring_2.mesh = orbit_torus_2
	_orbit_ring_2.position = Vector3(0.0, 1.28, 0.0)
	_orbit_ring_2.rotation = Vector3(deg_to_rad(28.0), 0.0, deg_to_rad(15.0))
	_orbit_ring_2.material_override = beam_mat
	add_child(_orbit_ring_2)

	# 4. Holographic Ground Ring (Reflecting on wet floor)
	_ring_mesh = MeshInstance3D.new()
	_ring_mesh.name = "BeaconRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.50
	torus.outer_radius = 0.64
	_ring_mesh.mesh = torus
	_ring_mesh.position = Vector3(0.0, 0.03, 0.0)
	_ring_mesh.material_override = beam_mat
	add_child(_ring_mesh)

	# 5. Dedicated OmniLight for floor reflections & atmospheric illumination
	_beacon_light = OmniLight3D.new()
	_beacon_light.name = "BeaconLight"
	_beacon_light.position = Vector3(0.0, 1.05, 0.0)
	_beacon_light.light_color = color
	_beacon_light.light_energy = 1.45
	_beacon_light.omni_range = 4.5
	_beacon_light.omni_attenuation = 1.2
	add_child(_beacon_light)

func _process(delta: float) -> void:
	if inspected:
		return
	_pulse_time += delta * 2.8
	var pulse := sin(_pulse_time) * 0.18 + 0.82
	if _beacon_light:
		_beacon_light.light_energy = 1.45 * pulse
	if _ring_mesh:
		_ring_mesh.rotation.y += delta * 0.6
		var ring_scale := 1.0 + sin(_pulse_time * 1.2) * 0.08
		_ring_mesh.scale = Vector3(ring_scale, 1.0, ring_scale)
	if _orbit_ring_1:
		_orbit_ring_1.rotation.y += delta * 1.1
	if _orbit_ring_2:
		_orbit_ring_2.rotation.y -= delta * 0.85
	if _beacon_mesh:
		_beacon_mesh.rotation.y -= delta * 0.35

func on_interacted(interactor: Node3D, _verb: int) -> Dictionary:
	if inspected:
		return {"inspected": false}
	inspected = true
	$InteractionArea.is_enabled = false
	if interactor and interactor.has_method("unregister_nearby_interactable"):
		interactor.unregister_nearby_interactable($InteractionArea)

	# Visual inspect feedback on character
	if interactor and interactor.has_method("play_anim"):
		interactor.play_anim("preset_biped_interact_001", 0.1)

	# Rewarding chime sound effect
	if is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_loot_toast_chime()
		audio.volume_db = -2.0
		audio.play()
		audio.finished.connect(func(): audio.queue_free())

	# Dissipate beacon, cloche, and rings with a graceful tween
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _cloche_mesh and _cloche_mat:
		tw.parallel().tween_property(_cloche_mesh, "position:y", 0.45, 0.7)
		tw.parallel().tween_property(_cloche_mat, "albedo_color:a", 0.0, 0.6)
	if _beacon_light:
		tw.parallel().tween_property(_beacon_light, "light_energy", 0.0, 0.6)
	if _beacon_mesh:
		tw.parallel().tween_property(_beacon_mesh, "scale:y", 0.01, 0.5)
	if _orbit_ring_1:
		tw.parallel().tween_property(_orbit_ring_1, "scale", Vector3(1.6, 0.01, 1.6), 0.5)
	if _orbit_ring_2:
		tw.parallel().tween_property(_orbit_ring_2, "scale", Vector3(1.6, 0.01, 1.6), 0.5)
	if _ring_mesh:
		tw.parallel().tween_property(_ring_mesh, "scale", Vector3(1.6, 1.0, 1.6), 0.5)

	# Update 3D label
	$EvidenceLabel.text = "[ " + ("11:11 CHRONOMETER" if evidence_id == "clock" else "PHOTOGRAPH") + " SECURED ]"
	$EvidenceLabel.modulate = Color(0.2, 1.0, 0.6, 1.0)
	var label_tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	label_tw.tween_property($EvidenceLabel, "position:y", 2.0, 0.8)
	label_tw.parallel().tween_property($EvidenceLabel, "modulate:a", 0.0, 1.4)

	evidence_inspected.emit(evidence_id)
	return {"inspected": true, "evidenceId": evidence_id}
