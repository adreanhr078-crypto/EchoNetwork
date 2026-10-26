extends Node3D
class_name OpeningEvidence

signal evidence_inspected(evidence_id: String)
signal inspection_requested(evidence: Node3D, interactor: Node3D)

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")
const EVIDENCE_FONT = preload("res://assets/fonts/NotoSansArabic.ttf")

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
var reduced_motion := false
var presentation_language := "ar"
var _feedback_tween: Tween
var _label_tween: Tween
var _guidance_strength := 1.0
var _guidance_target := 1.0
var _beam_material: StandardMaterial3D
var _beam_color: Color
var _trim_material: StandardMaterial3D

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
	$EvidenceLabel.font = EVIDENCE_FONT
	set_presentation_language(presentation_language)

func set_presentation_language(language: String) -> void:
	if language not in ["ar", "en"]: return
	presentation_language = language
	if not is_node_ready(): return
	$InteractionArea.prompt_target_name = ("الساعة المتوقفة" if evidence_id == "clock" else "الأثر الشخصي") if language == "ar" else ("Stopped clock" if evidence_id == "clock" else "Personal trace")
	if inspected:
		$EvidenceLabel.text = ("تم فحص الساعة · 11:11" if evidence_id == "clock" else "تم فحص الأثر الشخصي") if language == "ar" else ("Clock inspected · 11:11" if evidence_id == "clock" else "Personal trace inspected")

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if not is_node_ready(): return
	if enabled:
		if _beacon_light: _beacon_light.light_energy = 0.35
		if _ring_mesh: _ring_mesh.scale = Vector3.ONE
		if inspected:
			if _feedback_tween: _feedback_tween.kill()
			if _label_tween: _label_tween.kill()
			_hide_inspected_effects()
			$EvidenceLabel.position.y = 2.1
			$EvidenceLabel.modulate.a = 1.0
		_guidance_strength = _guidance_target
		_apply_guidance()

func _hide_inspected_effects() -> void:
	for mesh in [_beacon_mesh,_ring_mesh,_orbit_ring_1,_orbit_ring_2,_cloche_mesh]:
		if mesh: mesh.hide()
	if _beacon_light: _beacon_light.light_energy = 0.0

func restore_inspection(completed: bool) -> void:
	# Checkpoint presentation reflects an existing milestone and never emits it.
	inspected = completed
	if completed:
		_hide_inspected_effects()
		$EvidenceLabel.position.y = 2.1
		set_presentation_language(presentation_language)

func _setup_pedestal_and_props() -> void:
	# 1. Architectural Pedestal Base (Plinth grounded on the floor)
	var pedestal := Node3D.new()
	pedestal.name = "Pedestal"
	
	var obsidian_mat := StandardMaterial3D.new()
	obsidian_mat.albedo_color = Color(0.065, 0.08, 0.11)
	obsidian_mat.metallic = 0.55
	obsidian_mat.roughness = 0.42
	
	var accent_color := Color(0.0, 0.90, 1.0) if evidence_id == "clock" else Color(0.72, 0.57, 0.29)
	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = accent_color
	trim_mat.emission_enabled = true
	trim_mat.emission = accent_color
	trim_mat.emission_energy_multiplier = 0.20 if evidence_id == "clock" else 0.12
	_trim_material = trim_mat
	
	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.70, 0.48, 0.19)
	gold_mat.metallic = 0.72
	gold_mat.roughness = 0.30
	
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
		flute.name = "CoolingFlute_%d" % f
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
	if evidence_id == "clock":
		var clock_platter := CylinderMesh.new()
		clock_platter.radial_segments = 32
		clock_platter.top_radius = 0.22
		clock_platter.bottom_radius = 0.23
		clock_platter.height = 0.04
		top_mesh.mesh = clock_platter
	top_mesh.position = Vector3(0.0, 0.94, 0.0)
	var mount_yaw := deg_to_rad(15.0 if evidence_id == "clock" else -65.0)
	top_mesh.rotation = Vector3(deg_to_rad(24.0), mount_yaw, 0.0)
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
		$ClockFace.rotation = Vector3(deg_to_rad(24.0), mount_yaw, 0.0)
		
		# Original Blender hero asset: three shared materials, centre-origin hands.
		var clock := preload("res://assets/props/room01_clock_hero.glb").instantiate()
		clock.name = "HeroClock"
		var hour := clock.find_child("HourHand",true,false) as MeshInstance3D
		var minute := clock.find_child("MinuteHand",true,false) as MeshInstance3D
		$ClockFace.mesh = null
		$ClockFace.material_override = null
		$ClockFace.add_child(clock)
		$ClockHands.mesh = hour.mesh
		$ClockHands.material_override = null
		$ClockHands.transform = $ClockFace.transform * Transform3D(Basis(Vector3.UP,-deg_to_rad(335.5)),Vector3(0.0,0.024,0.0))
		hour.get_parent().remove_child(hour)
		hour.queue_free()
		minute.get_parent().remove_child(minute)
		$ClockFace.add_child(minute)
		minute.rotation.y = -deg_to_rad(66.0)

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
		_cloche_mat.roughness = 0.14
		_cloche_mat.clearcoat_enabled = true
		_cloche_mat.clearcoat = 0.35
		_cloche_mat.clearcoat_roughness = 0.16
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
		$PhotoFrame.rotation = Vector3(deg_to_rad(24.0), mount_yaw, 0.0)
		var frame := preload("res://assets/props/room01_trace_frame.glb").instantiate()
		var frame_surface := frame.find_child("PhotoFrameHero",true,false) as MeshInstance3D
		var paper_surface := frame.find_child("TracePaper",true,false) as MeshInstance3D
		var clips := frame.find_child("ArchivalClips",true,false) as MeshInstance3D
		$PhotoFrame.mesh = frame_surface.mesh
		$PhotoTrace.mesh = paper_surface.mesh
		$PhotoFrame.material_override = null
		# Remove the old scene-level metal override so both authored inset materials render.
		$PhotoFrame.set_surface_override_material(0,null)
		clips.get_parent().remove_child(clips)
		clips.owner = null
		$PhotoFrame.add_child(clips)
		frame.queue_free()
		# The plane was buried inside the 55mm frame; its normal must also follow
		# the inclined mount. Keep the existing trace without inventing a memory image.
		$PhotoTrace.transform = $PhotoFrame.transform * Transform3D(Basis.IDENTITY,Vector3(0.0,0.031,0.0))
		var paper := StandardMaterial3D.new()
		# Abstract washed emulsion only: no generated person, place or memory scene.
		paper.albedo_texture = preload("res://assets/textures/opening/photochemical-emulsion.jpg")
		paper.albedo_color = Color(0.80,0.76,0.68)
		paper.roughness = 0.92
		paper.metallic_specular = 0.12
		$PhotoTrace.material_override = paper

func _setup_holographic_beacon() -> void:
	var color := Color(0.24, 0.70, 0.76, 0.08) if evidence_id == "clock" else Color(0.78, 0.63, 0.34, 0.08)

	# 1. Soft Vertical Holographic Light Beam (Pillar)
	_beacon_mesh = MeshInstance3D.new()
	_beacon_mesh.name = "HolographicBeacon"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.04
	cyl.bottom_radius = 0.18
	cyl.height = 0.48
	_beacon_mesh.mesh = cyl
	_beacon_mesh.position = Vector3(0.0, 1.18, 0.0)

	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_mat.albedo_color = color
	_beam_material = beam_mat
	_beam_color = color
	_beacon_mesh.material_override = beam_mat
	add_child(_beacon_mesh)

	# 2. Concentric Orbiting Data Ring 1 (Upper Horizontal Ring)
	_orbit_ring_1 = MeshInstance3D.new()
	_orbit_ring_1.name = "OrbitRing1"
	var orbit_torus_1 := TorusMesh.new()
	orbit_torus_1.inner_radius = 0.235
	orbit_torus_1.outer_radius = 0.242
	_orbit_ring_1.mesh = orbit_torus_1
	_orbit_ring_1.position = Vector3(0.0, 1.25, 0.0)
	_orbit_ring_1.material_override = beam_mat
	add_child(_orbit_ring_1)

	# 3. Concentric Orbiting Data Ring 2 (Tilted Gimbal Ring)
	_orbit_ring_2 = MeshInstance3D.new()
	_orbit_ring_2.name = "OrbitRing2"
	var orbit_torus_2 := TorusMesh.new()
	orbit_torus_2.inner_radius = 0.255
	orbit_torus_2.outer_radius = 0.262
	_orbit_ring_2.mesh = orbit_torus_2
	_orbit_ring_2.position = Vector3(0.0, 1.28, 0.0)
	_orbit_ring_2.rotation = Vector3(deg_to_rad(28.0), 0.0, deg_to_rad(15.0))
	_orbit_ring_2.material_override = beam_mat
	add_child(_orbit_ring_2)

	# 4. Holographic Ground Ring (Reflecting on wet floor)
	_ring_mesh = MeshInstance3D.new()
	_ring_mesh.name = "BeaconRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.46
	torus.outer_radius = 0.475
	_ring_mesh.mesh = torus
	_ring_mesh.position = Vector3(0.0, 0.03, 0.0)
	_ring_mesh.material_override = beam_mat
	add_child(_ring_mesh)

	# 5. Dedicated OmniLight for floor reflections & atmospheric illumination
	_beacon_light = OmniLight3D.new()
	_beacon_light.name = "BeaconLight"
	_beacon_light.position = Vector3(0.0, 1.05, 0.0)
	_beacon_light.light_color = color
	_beacon_light.light_energy = 0.35
	_beacon_light.omni_range = 2.0
	_beacon_light.omni_attenuation = 1.2
	add_child(_beacon_light)

func set_guidance_strength(value: float) -> void:
	_guidance_target = clampf(value,0.0,1.0)
	if reduced_motion:
		_guidance_strength = _guidance_target
		_apply_guidance()

func _apply_guidance() -> void:
	if inspected: return
	if _beam_material:
		var color := _beam_color
		color.a *= _guidance_strength
		_beam_material.albedo_color = color
	if _trim_material:
		_trim_material.emission_energy_multiplier = (0.20 if evidence_id == "clock" else 0.12)*_guidance_strength
	if _beacon_light:
		var pulse := 1.0 if reduced_motion else sin(_pulse_time)*0.06+0.94
		_beacon_light.light_energy = 0.22*pulse*_guidance_strength

func _process(delta: float) -> void:
	if inspected: return
	_guidance_strength = _guidance_target if reduced_motion else move_toward(_guidance_strength,_guidance_target,delta*1.6)
	_apply_guidance()
	if reduced_motion: return
	_pulse_time += delta * 0.75
	if _ring_mesh:
		_ring_mesh.rotation.y += delta * 0.6
		var ring_scale := 1.0 + sin(_pulse_time * 1.2) * 0.015
		_ring_mesh.scale = Vector3(ring_scale, 1.0, ring_scale)
	if _orbit_ring_1:
		_orbit_ring_1.rotation.y += delta * 1.1
	if _orbit_ring_2:
		_orbit_ring_2.rotation.y -= delta * 0.85
	if _beacon_mesh:
		_beacon_mesh.rotation.y -= delta * 0.35

func on_interacted(interactor: Node3D, _verb: int) -> Dictionary:
	if inspected: return {"inspected": false}
	if inspection_requested.get_connections().size() > 0:
		inspection_requested.emit(self, interactor)
		return {"inspected": false, "inspectionPending": true}
	return complete_inspection(interactor)

func complete_inspection(interactor: Node3D) -> Dictionary:
	if inspected:
		return {"inspected": false}
	inspected = true
	$InteractionArea.is_enabled = false
	if interactor and interactor.has_method("unregister_nearby_interactable"):
		interactor.unregister_nearby_interactable($InteractionArea)

	# Visual inspect feedback on character
	if interactor and interactor.has_method("play_anim"):
		interactor.play_anim("preset_biped_interact_001", 0.1)

	# Muted inspection still has localized visual feedback without sound allocation.
	if is_inside_tree() and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")):
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_loot_toast_chime()
		audio.volume_db = -2.0
		audio.play()
		audio.finished.connect(audio.queue_free, CONNECT_ONE_SHOT)

	# Dissipate beacon, cloche, and rings with a graceful tween
	if reduced_motion:
		_hide_inspected_effects()
		$EvidenceLabel.position.y = 2.1
		set_presentation_language(presentation_language)
		$EvidenceLabel.modulate = Color(0.67,0.85,0.91,1.0)
		evidence_inspected.emit(evidence_id)
		return {"inspected": true, "evidenceId": evidence_id}
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_feedback_tween = tw
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
	tw.chain().tween_callback(_hide_inspected_effects)

	# Update 3D label
	set_presentation_language(presentation_language)
	$EvidenceLabel.position.y = 2.1
	$EvidenceLabel.modulate = Color(0.2, 1.0, 0.6, 1.0)
	var label_tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_label_tween = label_tw
	label_tw.tween_property($EvidenceLabel, "position:y", 2.35, 0.8)
	label_tw.parallel().tween_property($EvidenceLabel, "modulate:a", 0.0, 1.4)

	evidence_inspected.emit(evidence_id)
	return {"inspected": true, "evidenceId": evidence_id}
