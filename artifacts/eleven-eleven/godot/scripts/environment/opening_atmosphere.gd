extends Node3D

## Presentation-only first-room finish. Uses existing architecture/colliders.
## Local elapsed time makes pause/Reduced Motion real, including wet normals.
const DECK_SHADER = preload("res://shaders/opening_deck.gdshader")
const GLASS_SHADER = preload("res://shaders/opening_frosted_glass.gdshader")
const WALL_SHADER = preload("res://shaders/opening_wall_finish.gdshader")
const DUST_SHADER = preload("res://shaders/opening_dust.gdshader")
const CASE_PATH := "res://assets/props/sector11_supply_case_v1.glb"
const ROOM_AUDIO = preload("res://scripts/audio/procedural_cinematic_audio.gd")
const ENERGY_FX = preload("res://scripts/environment/opening_energy_fx.gd")

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
var _vent: AudioStreamPlayer3D
var _relay: AudioStreamPlayer3D
var _vent_stream: AudioStreamWAV
var _relay_stream: AudioStreamWAV
var _phase := -1
var relay_count := 0
var _gate_focus: OmniLight3D
var _gate_color: Color
var _gate_energy := 0.0
var _power_blend := 0.0
var _face_fill: OmniLight3D
var _shoulder_fill: OmniLight3D
var _face_energy := 0.0
var _shoulder_energy := 0.0
var _inside_room := true
var _reaction_origin := Vector2(-1.85, 1.8)
var _reaction_age := 0.0
var _power_state := 0.0
var energy_fx: Node3D
var _evidence_nodes: Dictionary = {}
var _terminal_focus: OmniLight3D
var _terminal_energy := 0.0
var _terminal_guidance := 0.2
var _exit_cue: Node3D
var _exit_label: Label3D

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
	_build_room_sound()
	_build_exit_cue()
	energy_fx = Node3D.new()
	energy_fx.name = "OpeningEnergyFX"
	energy_fx.set_script(ENERGY_FX)
	add_child(energy_fx)
	set_reduced_motion(bool(main.get("reduced_motion")))

func _build_exit_cue() -> void:
	var gate:=_main.find_child("PrimaryBlastGate",true,false) as Node3D
	if not gate:return
	# A static architectural edge shows the shape of the opened passage before
	# the boundary memory loads the next room. No new lights, collision or power.
	_exit_cue=Node3D.new();_exit_cue.name="OpenPassageFrame";gate.add_child(_exit_cue)
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color(.25,.7,.76)
	material.emission_enabled=true;material.emission=Color(.18,.55,.6);material.emission_energy_multiplier=.35
	for spec in [[Vector3(.045,5.8,.045),Vector3(-3.45,2.9,.48)],[Vector3(.045,5.8,.045),Vector3(3.45,2.9,.48)],[Vector3(6.9,.045,.08),Vector3(0,.06,.48)]]:
		var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=spec[0];mesh.mesh=box;mesh.position=spec[1]
		mesh.material_override=material;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;_exit_cue.add_child(mesh)
	_exit_label=Label3D.new();_exit_label.font=preload("res://assets/fonts/NotoSansArabic.ttf")
	_exit_label.position=Vector3(0,5.7,.5);_exit_label.pixel_size=.006;_exit_label.font_size=36
	_exit_label.modulate=Color(.75,.91,.93);_exit_label.outline_size=8;_exit_cue.add_child(_exit_label)
	_exit_cue.hide()

func _build_room_sound() -> void:
	# Two bounded spatial sources; silence is retained behind the next threshold.
	_vent = AudioStreamPlayer3D.new()
	_vent.name = "ObservationVentAir"
	_vent.position = Vector3(6.1, 2.8, -5.5)
	_vent.volume_db = -14.0
	_vent.unit_size = 7.0
	_vent.max_distance = 20.0
	add_child(_vent)
	_relay = AudioStreamPlayer3D.new()
	_relay.name = "GatePressureRelease"
	_relay.position = Vector3(0, 2, -15.5)
	_relay.volume_db = -16.0
	_relay.unit_size = 8.0
	_relay.max_distance = 24.0
	add_child(_relay)
	_gate_focus = _main.get_node_or_null("Sector11GateFocus") as OmniLight3D
	if _gate_focus:
		_gate_color = _gate_focus.light_color
		_gate_energy = _gate_focus.light_energy
	_terminal_focus = _main.get_node_or_null("Sector11TerminalFocus") as OmniLight3D
	if _terminal_focus: _terminal_energy = _terminal_focus.light_energy
	_face_fill = _main.player.find_child("EchoFaceFill", true, false) as OmniLight3D
	_shoulder_fill = _main.player.find_child("EchoShoulderFill", true, false) as OmniLight3D
	if _face_fill: _face_energy = _face_fill.light_energy
	if _shoulder_fill: _shoulder_energy = _shoulder_fill.light_energy

func _room_phase() -> int:
	var prologue := _main.get_node_or_null("PrologueOrchestrator")
	if not prologue: return 0
	if prologue.room_gate_open: return 5
	if prologue.wake_terminal_solved or prologue.conduit_a_energized: return 4
	if prologue.opening_memory_recovered: return 3
	if prologue.clock_inspected: return 2
	return 0 if _main.player.opening_recovery_active else 1

func _sync_room_sound_and_light(delta: float) -> void:
	_inside_room = _main.player.global_position.z > -18.4
	var next := _room_phase()
	var prologue := _main.get_node_or_null("PrologueOrchestrator")
	_power_state = 1.0 if prologue and prologue.conduit_a_energized else 0.0
	# First observation also covers checkpoint load: restore visuals silently.
	if _phase < 0:
		_power_blend = 1.0 if next == 5 else 0.0
	elif next == 5 and _phase != 5 and _inside_room and not _main.audio_muted:
		if not _relay_stream: _relay_stream = ROOM_AUDIO.create_pressure_air(0.85, 111113)
		_relay.stream = _relay_stream
		_relay.play()
		relay_count += 1
	_phase = next
	if _exit_cue:
		_exit_cue.visible=next==5 and _inside_room
		_exit_label.text="الممر مفتوح" if _main.presentation_language=="ar" else "PASSAGE OPEN"
	# Presentation follows existing milestones without changing prerequisites,
	# interactables, save data or reward authority.
	if _evidence_nodes.has("clock"):
		_evidence_nodes.clock.set_guidance_strength(1.0)
	if _evidence_nodes.has("photo"):
		_evidence_nodes.photo.set_guidance_strength(1.0 if next >= 2 else 0.18)
	var terminal_target := 1.0 if next >= 3 else 0.2
	_terminal_guidance = terminal_target if reduced_motion else move_toward(_terminal_guidance,terminal_target,delta*1.6)
	if _terminal_focus:
		_terminal_focus.light_energy = _terminal_energy*_terminal_guidance if _inside_room else _terminal_energy
	var target := 1.0 if next == 5 else 0.0
	_power_blend = target if reduced_motion else move_toward(_power_blend, target, delta * 1.4)
	if _gate_focus:
		_gate_focus.light_color = _gate_color.lerp(Color(0.15, 0.78, 0.84), _power_blend)
		_gate_focus.light_energy = lerpf(_gate_energy, 1.35, _power_blend)
	# Room-specific exposure avoids bleaching V31's face at the arrival close-up.
	# Release these local values at the physical exit, before the next room review.
	if _face_fill: _face_fill.light_energy = 0.42 if _inside_room else _face_energy
	if _shoulder_fill: _shoulder_fill.light_energy = 0.55 if _inside_room else _shoulder_energy
	var audible: bool = _inside_room and not _main.audio_muted
	if audible and not _vent.playing:
		if not _vent_stream:
			_vent_stream = _create_vent_air()
		_vent.stream = _vent_stream
		_vent.play()
	elif not audible and _vent.playing:
		_vent.stop()
	if not audible and _relay.playing: _relay.stop()

func _create_vent_air() -> AudioStreamWAV:
	# Filtered broadband noise, no oscillator, notes, chord, or musical drone.
	# Crossfade the final 80ms into the start for a continuous mechanical loop.
	var rate := 22050
	var samples := PackedFloat32Array()
	samples.resize(rate * 6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 111112
	var air := 0.0
	for index in samples.size():
		air = lerpf(air, rng.randf_range(-1.0, 1.0), 0.045)
		samples[index] = air * 0.28
	var seam := int(rate * 0.08)
	for index in seam:
		var weight := float(index) / float(seam - 1)
		samples[samples.size() - seam + index] = lerpf(samples[samples.size() - seam + index], samples[index], weight)
	var stream := ROOM_AUDIO.generate_wav(samples, rate)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = seam
	stream.loop_end = samples.size()
	return stream

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
		violet.light_color = Color(0.28,0.48,0.96)
		violet.light_energy = 1.15
	var cyan := _main.get_node_or_null("Sector11NeonCyanRim") as OmniLight3D
	if cyan:
		cyan.light_color = Color(0.18,0.68,0.82)
		cyan.light_energy = 1.35
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
		_evidence_nodes[evidence.evidence_id] = evidence
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
		_reaction_age = 0.0
		var source := _main.find_child("OpeningClock" if id == "clock" else "OpeningPhotograph", true, false) as Node3D
		if source:
			_reaction_origin = Vector2(source.global_position.x, source.global_position.z)
			energy_fx.react_at(source.global_position, id == "photo")

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if enabled: reaction = 0.0
	if energy_fx: energy_fx.sync(elapsed,0.0,_phase,_power_state,enabled,_inside_room)
	_sync_materials()

func _process(delta: float) -> void:
	if not configured or not is_instance_valid(_main): return
	_sync_room_sound_and_light(delta)
	if not reduced_motion:
		elapsed += minf(delta,0.1)
		_reaction_age += minf(delta,0.1)
		reaction = maxf(0.0,reaction-delta*0.35)
	energy_fx.sync(elapsed,delta,_phase,_power_state,reduced_motion,_inside_room)
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
		_deck.set_shader_parameter("reaction_origin", _reaction_origin)
		_deck.set_shader_parameter("reaction_age", _reaction_age)
		_deck.set_shader_parameter("power_state", _power_state)
	if _dust_material:
		_dust_material.set_shader_parameter("motion_time", elapsed)
		_dust_material.set_shader_parameter("reaction", reaction)
	for glass in _glass_materials:
		glass.set_shader_parameter("reaction", reaction)
		glass.set_shader_parameter("motion_time", elapsed)
		glass.set_shader_parameter("scan_motion", 0.0 if reduced_motion else 1.0)

func diagnostics() -> Dictionary:
	return {"configured":configured,"surface_count":_surface_count,"glass_materials":_glass_materials.size(),
		"dust_count":dust.multimesh.instance_count if dust else 0,"elapsed":elapsed,"reaction_count":reaction_count,
		"added_colliders":find_children("*","CollisionObject3D",true,false).size(),"reduced_motion":reduced_motion,
		"room_phase":_phase,"vent_playing":_vent.playing if _vent else false,"relay_count":relay_count,
		"sound_sources":2,"audio_policy":"SFX_ONLY","energy_fx":energy_fx.diagnostics() if energy_fx else {}}
