extends Node3D

## Presentation-only first-room finish. Uses existing architecture/colliders.
## Local elapsed time makes pause/Reduced Motion real, including wet normals.
const DECK_SHADER = preload("res://shaders/opening_deck.gdshader")
const GLASS_SHADER = preload("res://shaders/opening_frosted_glass.gdshader")
const WALL_SHADER = preload("res://shaders/opening_wall_finish.gdshader")
const DUST_SHADER = preload("res://shaders/opening_dust.gdshader")
const CASE_PATH := "res://assets/props/sector11_supply_case_v1.glb"

var reduced_motion := false
var elapsed := 0.0
var reaction := 0.0
var reaction_count := 0
var configured := false
var _main: Node3D
var _deck: ShaderMaterial
var _dust_material: ShaderMaterial
var _glass_materials: Array[ShaderMaterial] = []
var _beacons: Array[OmniLight3D] = []
var _beacon_bases: Array[float] = []
var _case_glows: Array[OmniLight3D] = []
var _seen_evidence: Dictionary = {}
var dust: MultiMeshInstance3D
var _surface_count := 0

func configure(main: Node3D) -> void:
	if configured: return
	configured = true
	_main = main
	_finish_floor()
	_finish_shell()
	_finish_practical_lights()
	_finish_supply_cases()
	_build_dust()
	_bind_evidence()
	set_reduced_motion(bool(main.get("reduced_motion")))

func _finish_floor() -> void:
	var mesh := _main.get_node_or_null("Sector11Facility/Room1_CryoChamber/CatwalkFloor") as MeshInstance3D
	if not mesh: return
	_deck = ShaderMaterial.new()
	_deck.shader = DECK_SHADER
	mesh.material_override = null
	mesh.set_surface_override_material(0, _deck)

func _finish_shell() -> void:
	var shell := _main.get_node_or_null("Sector11OpeningShell")
	if not shell: return
	# Shared material cache prevents each architectural surface making a copy.
	var cache: Dictionary = {}
	for visual in shell.find_children("*", "MeshInstance3D", true, false):
		var mesh := visual as MeshInstance3D
		if not mesh.mesh: continue
		# Preserve an authored custom shader; this finish owns Standard materials.
		if mesh.material_override and not mesh.material_override is StandardMaterial3D: continue
		var path := str(shell.get_path_to(mesh))
		# A whole-mesh override takes priority over surface overrides in Godot.
		# Collect first so authored material slots remain intact when clearing it.
		var sources: Array[Material] = []
		for surface in mesh.mesh.get_surface_count():
			sources.append(mesh.get_active_material(surface))
		mesh.material_override = null
		for surface in mesh.mesh.get_surface_count():
			var source := sources[surface] as StandardMaterial3D
			if not source: continue
			var material_name := source.resource_name.to_lower()
			var boundary := mesh.mesh is BoxMesh and (path.contains("ContainmentWall") or path.contains("Bulkhead") or path.contains("CeilingShell"))
			var panel := path.contains("MaintenanceDeckPanel")
			var key := ("boundary" if boundary else "deck_panel" if panel else str(source.get_instance_id()))
			var finish: Material
			if cache.has(key):
				finish = cache[key]
			else:
				if boundary:
					var wall := ShaderMaterial.new()
					wall.shader = WALL_SHADER
					wall.set_shader_parameter("base_color", Color(0.26,0.30,0.37))
					finish = wall
				elif panel:
					var deck_panel := source.duplicate() as StandardMaterial3D
					deck_panel.albedo_color = Color(0.18,0.22,0.27)
					deck_panel.metallic = 0.22
					deck_panel.roughness = 0.55
					finish = deck_panel
				elif material_name.contains("observation glass"):
					var glass := ShaderMaterial.new()
					glass.shader = GLASS_SHADER
					_glass_materials.append(glass)
					finish = glass
				elif material_name.contains("containment ceramic") or material_name.contains("machined armor"):
					var wall := ShaderMaterial.new()
					wall.shader = WALL_SHADER
					wall.set_shader_parameter("base_color", Color(0.18,0.23,0.30) if material_name.contains("armor") else Color(0.14,0.18,0.245))
					wall.set_shader_parameter("metalness", 0.40 if material_name.contains("armor") else 0.22)
					finish = wall
				else:
					var standard := source.duplicate() as StandardMaterial3D
					if source.emission_enabled:
						# Tiny practicals may shine; whole panels cannot become lights.
						standard.emission_energy_multiplier = minf(source.emission_energy_multiplier, 0.80)
					else:
						standard.metallic = minf(source.metallic, 0.55)
						standard.roughness = maxf(source.roughness, 0.38)
					finish = standard
				cache[key] = finish
			mesh.set_surface_override_material(surface, finish)
			_surface_count += 1

func _finish_practical_lights() -> void:
	# Reuse already-loaded light slots; do not add lights to each detail.
	var violet := _main.get_node_or_null("Sector11NeonVioletRim") as OmniLight3D
	if violet:
		violet.light_color = Color(0.58,0.30,0.80)
		violet.light_energy = 0.85
	var cyan := _main.get_node_or_null("Sector11NeonCyanRim") as OmniLight3D
	if cyan:
		cyan.light_color = Color(0.18,0.68,0.82)
		cyan.light_energy = 0.80
	var strobe := _main.find_child("EmergencyStrobeChamber", true, false) as OmniLight3D
	if strobe:
		strobe.set_process(false)
		strobe.light_energy = 0.42
		strobe.omni_range = 7.0
		_beacons.append(strobe)
		_beacon_bases.append(strobe.light_energy)

func _finish_supply_cases() -> void:
	if not ResourceLoader.exists(CASE_PATH):
		push_warning("Opening supply-case import unavailable; retaining existing prop")
		return
	var case_scene := load(CASE_PATH) as PackedScene
	if not case_scene: return
	for case_name in ["SupplyCrate_A1", "SupplyCrate_A2"]:
		var existing := _main.find_child(case_name, true, false) as Node3D
		if not existing: continue
		var old_mesh := existing.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if not old_mesh: continue
		# Asset is a single mesh at origin, retaining the existing break/shrink path.
		var source_root := case_scene.instantiate() as Node3D
		var meshes := source_root.find_children("*", "MeshInstance3D", true, false)
		if meshes.size() == 1:
			var authored := meshes[0] as MeshInstance3D
			old_mesh.mesh = authored.mesh
			old_mesh.material_override = null
			for surface in old_mesh.mesh.get_surface_count():
				old_mesh.set_surface_override_material(surface, null)
			old_mesh.position = Vector3.ZERO
		source_root.free()
		var glow := existing.get_node_or_null("CrateGlow") as OmniLight3D
		if glow:
			glow.light_color = Color(0.95,0.45,0.15)
			glow.light_energy = 0.16
			glow.omni_range = 1.3
			_case_glows.append(glow)

func _build_dust() -> void:
	dust = MultiMeshInstance3D.new()
	dust.name = "LightCaughtDust"
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var particles := MultiMesh.new()
	particles.transform_format = MultiMesh.TRANSFORM_3D
	particles.use_custom_data = true
	var grain := SphereMesh.new()
	grain.radius = 0.006
	grain.height = 0.012
	grain.radial_segments = 4
	grain.rings = 2
	particles.mesh = grain
	particles.instance_count = 48
	var rng := RandomNumberGenerator.new()
	rng.seed = 111107
	for index in particles.instance_count:
		var near_capsule := index < 32
		var center := Vector3(-2.7,2.4,2.0) if near_capsule else Vector3(6.1,3.2,-5.5)
		var offset := Vector3(rng.randf_range(-1.0,1.0),rng.randf_range(-1.5,1.5),rng.randf_range(-1.4,1.4))
		var scale_factor := rng.randf_range(0.6,1.4)
		particles.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scale_factor),center+offset))
		particles.set_instance_custom_data(index, Color(rng.randf(),rng.randf(),0,1))
	_dust_material = ShaderMaterial.new()
	_dust_material.shader = DUST_SHADER
	dust.multimesh = particles
	dust.material_override = _dust_material
	dust.custom_aabb = AABB(Vector3(-4,0,0),Vector3(12,6,5)).expand(Vector3(8,5,-8))
	add_child(dust)

func _bind_evidence() -> void:
	for evidence_name in ["OpeningClock", "OpeningPhotograph"]:
		var evidence := _main.find_child(evidence_name, true, false)
		if not evidence: continue
		if evidence.get("inspected") == true:
			_seen_evidence[evidence.get("evidence_id")] = true
		evidence.evidence_inspected.connect(_on_evidence_inspected)

func _on_evidence_inspected(id: String) -> void:
	if _seen_evidence.has(id): return
	_seen_evidence[id] = true
	# Receives the real one-shot inspection signal, never emits story progress.
	reaction_count += 1
	if not reduced_motion:
		reaction = 1.0

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if enabled: reaction = 0.0
	_sync_materials()

func _process(delta: float) -> void:
	if not configured or not is_instance_valid(_main): return
	if not reduced_motion:
		elapsed += minf(delta,0.1)
		reaction = maxf(0.0,reaction-delta*0.8)
	for index in _beacons.size():
		var beacon := _beacons[index]
		if is_instance_valid(beacon):
			# A slow breathing warning, no sharp fullscreen/roomwide flashing.
			beacon.light_energy = _beacon_bases[index] * (1.0 if reduced_motion else 1.0+sin(elapsed*0.8)*0.10)
	_sync_materials()

func _sync_materials() -> void:
	if _deck:
		_deck.set_shader_parameter("motion_time", elapsed)
		_deck.set_shader_parameter("ripple_amount", 0.0 if reduced_motion else 1.0)
		_deck.set_shader_parameter("reaction", reaction)
	if _dust_material: _dust_material.set_shader_parameter("motion_time", elapsed)
	for glass in _glass_materials:
		glass.set_shader_parameter("reaction", reaction)

func diagnostics() -> Dictionary:
	return {"configured":configured,"surface_count":_surface_count,"glass_materials":_glass_materials.size(),
		"dust_count":dust.multimesh.instance_count if dust else 0,"elapsed":elapsed,"reaction_count":reaction_count,
		"added_colliders":find_children("*","CollisionObject3D",true,false).size(),"reduced_motion":reduced_motion}
