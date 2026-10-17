extends Node3D

## Room 8: Decontamination & Quarantine Wing (Sector 11 Bio-Containment & Sterilization)
## Connects from Buffer 7-8 (Reactor-to-Decon Conduit) South Entrance at Z = 0.0m
## to Room 9 North Exit Blast Gate at Z = -32.0m.
## Enforces the Anti-Crowding and Quality Gate Invariants:
## - Watertight Hull (24.0m x 32.0m x 7.2m), solid collision envelope, zero light bleed.
## - Narrative & Gameplay Flow:
##   * Decon Chamber 1: Sterilization archway with UV pulses (#7209B7 UV / #D8F3DC Clinical Teal).
##   * Central Quarantine Pod Row: 6 reinforced bio-quarantine tanks.
##   * Elevated Observation Catwalk Bridge at Y = +3.2m with access stairs.
##   * Central Quarantine Override Terminal implementing trigger_interaction(player).
##   * Unlocking the North Exit Blast Gate to Room 9.
## - 3-Tier Safe Anchors (Entry, Catwalk, Exit).
## - Full accessibility: reduced motion, audio mute, durable state save/restore.

signal quarantine_override_initiated
signal quarantine_cleared
signal exit_gate_opened
signal retry_requested(anchor: Vector3)

enum RoomState {
	ENTRY_STERILIZATION,
	POD_OBSERVATION,
	OVERRIDE_ACTIVE,
	QUARANTINE_CLEARED,
	EXIT_CORRIDOR
}

const CERAMIC = preload("res://assets/environments/maintenance_jutsu_v1_Maintenance ceramic grain 512.png")
const GRAPHITE = preload("res://assets/environments/maintenance_jutsu_v1_Maintenance brushed graphite 512.png")
const SIGNAL_CONSOLE_PROP = preload("res://assets/props/signal_console_jutsu.glb")
const PRESENTATION_LAYER := 1 << 18 # Room-only fills; layer 20 is reserved for mirrors.

const ROOM_WIDTH := 24.0 # X: -12.0m to +12.0m (center = 0.0m)
const ROOM_LENGTH := 32.0 # Z: 0.0m to -32.0m (center = -16.0m)
const ROOM_HEIGHT := 7.2 # Y: 0.0m to +7.2m
const WALL_THICKNESS := 0.4

const SAFE_ANCHOR_ENTRY := Vector3(0.0, 0.1, -2.0)
const SAFE_ANCHOR_CATWALK := Vector3(0.0, 3.3, -16.0)
const SAFE_ANCHOR_EXIT := Vector3(0.0, 0.1, -29.0)

var state: RoomState = RoomState.ENTRY_STERILIZATION
var current_anchor: Vector3 = SAFE_ANCHOR_ENTRY
var reduced_motion := false:
	set(value):
		if reduced_motion==value: return
		reduced_motion = value
		if value and override_done: _mist_amount = 0.0
		if value:
			for card in _mist_cards: card.visible = false
			if is_instance_valid(_air_motes):
				_air_motes._air.visible = false
				_air_motes._release.visible = false
		if value and gate_open and is_instance_valid(_gate):
			_kill_gate_tween()
			_animate_gate()
var audio_muted := false:
	set(value):
		audio_muted = value
		if value: _stop_presentation_audio()
var player: Node3D

var override_done := false
var gate_open := false

var _gate: StaticBody3D
var _gate_shape: CollisionShape3D
var _gate_closed_y := 1.4
var _gate_open_y := 4.8

var _terminal_body: StaticBody3D
var _terminal_light: OmniLight3D
var _uv_pulse_light: OmniLight3D
var _uv_timer := 0.0
var _gate_tween: Tween
var _gate_generation := 0
var _mist_material: ShaderMaterial
var _mist_cards: Array[MeshInstance3D] = []
var _mist_amount := 1.0
var _mist_time := 0.0
var _air_motes: Node3D
var _arch_emitter_material: StandardMaterial3D
var _arch_fill: OmniLight3D
var _terminal_screen_material: StandardMaterial3D
var _gate_status_material: StandardMaterial3D
var _override_sound: AudioStreamPlayer3D
var _latch_sound: AudioStreamPlayer3D

func _ready() -> void:
	_build_room_hull()
	_build_decon_arches()
	_build_quarantine_pods()
	_build_observation_catwalk()
	_build_override_terminal()
	_build_exit_gate()
	preload("res://scripts/environment/room_service_lighting.gd").install(self,Rect2(-12,-32,24,32),7.2)
	_build_presentation()
	var finish = preload("res://scripts/environment/room_panel_finish.gd")
	finish.apply(self,["ObservationCatwalkDeck","CatwalkStairSupport","CatwalkStairLanding"],finish.material(Color(0.30,0.37,0.45),Vector2(3.6,2.4),0.22,0.56))

func _physics_process(delta: float) -> void:
	_update_uv_pulses(delta)
	
	if not player or not is_instance_valid(player):
		return
	
	var pz: float = to_local(player.global_position).z
	var py: float = to_local(player.global_position).y
	
	# Monotonic checkpoint progression
	if pz < -26.0 and gate_open:
		current_anchor = SAFE_ANCHOR_EXIT
	elif pz < -12.0 and py > 2.0:
		if current_anchor != SAFE_ANCHOR_EXIT:
			current_anchor = SAFE_ANCHOR_CATWALK
	elif current_anchor == SAFE_ANCHOR_ENTRY and pz < -6.0:
		state = RoomState.POD_OBSERVATION

func _update_uv_pulses(delta: float) -> void:
	if not _uv_pulse_light:
		return
	if override_done:
		_uv_pulse_light.light_energy = 0.72
		return
	if reduced_motion:
		_uv_pulse_light.light_energy = 0.65
		return
	_uv_timer += delta
	# Subtle clinical pulse every 3.0s
	var intensity: float = 0.62 + 0.18 * sin(_uv_timer * 2.0)
	_uv_pulse_light.light_energy = intensity

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

func _box(label: String, center: Vector3, size: Vector3, mat: Material, solid := false) -> Node3D:
	var node: Node3D = StaticBody3D.new() if solid else Node3D.new()
	node.name = label
	node.position = center
	var visual := MeshInstance3D.new()
	visual.mesh = BoxMesh.new()
	visual.mesh.size = size
	visual.material_override = mat
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	node.add_child(visual)
	if solid:
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var box := BoxShape3D.new()
		box.size = size
		collision.shape = box
		node.add_child(collision)
	add_child(node)
	return node

func _build_room_hull() -> void:
	var wall_mat := _material(Color(0.42, 0.47, 0.54), 0.15, 0.58)
	wall_mat.albedo_texture = CERAMIC
	wall_mat.uv1_scale = Vector3(3.0, 3.0, 1.0)
	
	var floor_mat := _material(Color(0.40, 0.46, 0.52), 0.22, 0.62)
	floor_mat.albedo_texture = GRAPHITE
	floor_mat.uv1_scale = Vector3(4.0, 4.0, 1.0)
	
	var center_z := -ROOM_LENGTH * 0.5 # -16.0m
	var center_y := ROOM_HEIGHT * 0.5 # 3.6m
	
	# 1. Floor (solid) at Y = 0.0m
	_box("Floor", Vector3(0.0, -WALL_THICKNESS * 0.5, center_z), Vector3(ROOM_WIDTH, WALL_THICKNESS, ROOM_LENGTH), floor_mat, true)
	
	# 2. Ceiling (solid) at Y = 7.2m
	_box("Ceiling", Vector3(0.0, ROOM_HEIGHT + WALL_THICKNESS * 0.5, center_z), Vector3(ROOM_WIDTH, WALL_THICKNESS, ROOM_LENGTH), wall_mat, true)
	
	# 3. West Wall (solid) at X = -12.0m
	_box("WestWall", Vector3(-ROOM_WIDTH * 0.5 - WALL_THICKNESS * 0.5, center_y, center_z), Vector3(WALL_THICKNESS, ROOM_HEIGHT, ROOM_LENGTH), wall_mat, true)
	
	# 4. East Wall (solid) at X = +12.0m
	_box("EastWall", Vector3(ROOM_WIDTH * 0.5 + WALL_THICKNESS * 0.5, center_y, center_z), Vector3(WALL_THICKNESS, ROOM_HEIGHT, ROOM_LENGTH), wall_mat, true)
	
	# 5. South Wall (solid) at Z = 0.0m with Entrance Portal (Width 2.6m x Height 3.2m)
	var south_z := WALL_THICKNESS * 0.5
	# SouthWest: from X = -12.0m to -1.3m (width = 10.7m, center X = -6.65m)
	_box("SouthWallWest", Vector3(-6.65, center_y, south_z), Vector3(10.7, ROOM_HEIGHT, WALL_THICKNESS), wall_mat, true)
	# SouthEast: from X = +1.3m to +12.0m (width = 10.7m, center X = +6.65m)
	_box("SouthWallEast", Vector3(6.65, center_y, south_z), Vector3(10.7, ROOM_HEIGHT, WALL_THICKNESS), wall_mat, true)
	# SouthLintel: above portal from Y = 3.2m to 7.2m (height = 4.0m, center Y = 5.2m, width = 2.6m)
	_box("SouthLintel", Vector3(0.0, 5.2, south_z), Vector3(2.6, 4.0, WALL_THICKNESS), wall_mat, true)
	
	# 6. North Wall (solid) at Z = -32.0m with Exit Blast Gate (Width 2.05m x Height 2.8m)
	var north_z := -ROOM_LENGTH - WALL_THICKNESS * 0.5
	# NorthWest: from X = -12.0m to -1.025m (width = 10.975m, center X = -6.5125m)
	_box("NorthWallWest", Vector3(-6.5125, center_y, north_z), Vector3(10.975, ROOM_HEIGHT, WALL_THICKNESS), wall_mat, true)
	# NorthEast: from X = +1.025m to +12.0m (width = 10.975m, center X = +6.5125m)
	_box("NorthWallEast", Vector3(6.5125, center_y, north_z), Vector3(10.975, ROOM_HEIGHT, WALL_THICKNESS), wall_mat, true)
	# NorthLintel: above exit from Y = 2.8m to 7.2m (height = 4.4m, center Y = 5.0m, width = 2.05m)
	_box("NorthLintel", Vector3(0.0, 5.0, north_z), Vector3(2.05, 4.4, WALL_THICKNESS), wall_mat, true)
	
	# Ambient Clinical Light
	_uv_pulse_light = OmniLight3D.new()
	_uv_pulse_light.name = "ClinicalUVPulseLight"
	_uv_pulse_light.position = Vector3(0.0, 5.5, center_z)
	_uv_pulse_light.light_color = Color(0.85, 0.95, 0.92) # Soft Clinical Teal
	_uv_pulse_light.light_energy = 1.2
	_uv_pulse_light.omni_range = 24.0
	_uv_pulse_light.shadow_enabled = true
	add_child(_uv_pulse_light)

func _build_decon_arches() -> void:
	var frame_mat := _material(Color(0.48, 0.54, 0.62), 0.22, 0.46)
	# Graphite's dark base multiplied this tint back into near-black. The
	# approved neutral ceramic grain keeps fine structure in the fill light.
	frame_mat.albedo_texture = CERAMIC
	frame_mat.uv1_scale = Vector3(2.0, 2.0, 1.0)
	_arch_emitter_material = _material(Color(0.20, 0.06, 0.34), 0.1, 0.45, true, Color(0.58, 0.16, 0.96), 1.1)
	
	for i in range(2):
		var arch_z := -3.5 - float(i) * 3.0
		_box("DeconArchPillarL_%d" % i, Vector3(-1.8, 2.0, arch_z), Vector3(0.4, 4.0, 0.4), frame_mat, true)
		_box("DeconArchPillarR_%d" % i, Vector3(1.8, 2.0, arch_z), Vector3(0.4, 4.0, 0.4), frame_mat, true)
		_box("DeconArchLintel_%d" % i, Vector3(0.0, 4.0, arch_z), Vector3(4.0, 0.4, 0.4), frame_mat, true)
		
		# UV Emitter Strip
		_box("UVEmitter_%d" % i, Vector3(0.0, 3.8, arch_z), Vector3(3.2, 0.1, 0.2), _arch_emitter_material, false)

func _build_quarantine_pods() -> void:
	var frame_mat := _material(Color(0.40,0.47,0.56),0.25,0.50)
	var glass_mat := _material(Color(0.22, 0.42, 0.48, 0.16), 0.1, 0.22, true, Color(0.0, 0.8, 0.9), 0.25)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	var pod_z_positions := [-11.0, -16.0, -21.0]
	for idx in range(pod_z_positions.size()):
		var pz: float = pod_z_positions[idx]
		# Left Pod (X = -6.5m)
		_create_pod("QuarantinePod_L%d" % idx, Vector3(-6.5, 1.4, pz), frame_mat, glass_mat)
		# Right Pod (X = +6.5m)
		_create_pod("QuarantinePod_R%d" % idx, Vector3(6.5, 1.4, pz), frame_mat, glass_mat)

func _create_pod(node_name: String, pos: Vector3, frame_mat: Material, glass_mat: Material) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	
	# Glass cylinder mesh
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.4
	cyl.bottom_radius = 1.4
	cyl.height = 2.8
	mesh.mesh = cyl
	mesh.material_override = glass_mat
	body.add_child(mesh)
	# A filter cartridge provides depth inside the existing decorative pod;
	# no subject/character or collision is added.
	var inner := MeshInstance3D.new()
	inner.name = "FilterCartridge"
	var core := CylinderMesh.new()
	core.top_radius = 0.55
	core.bottom_radius = 0.55
	core.height = 2.4
	core.radial_segments = 12
	inner.mesh = core
	var filter_mat := _material(Color(0.18,0.30,0.34),0.2,0.65,true,Color(0.12,0.72,0.82),0.45)
	filter_mat.albedo_texture = GRAPHITE
	filter_mat.emission_texture = GRAPHITE
	filter_mat.uv1_scale = Vector3(2.0,3.0,1.0)
	inner.material_override = filter_mat
	inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(inner)
	
	# Solid Collision
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape := CylinderShape3D.new()
	shape.radius = 1.4
	shape.height = 2.8
	col.shape = shape
	body.add_child(col)
	
	# Top and Bottom metal rims
	for top in [false,true]:
		var rim := MeshInstance3D.new()
		rim.name = "PodCap" if top else "PodBase"
		var metal_rim := CylinderMesh.new()
		metal_rim.top_radius = 1.46 if top else 1.55
		metal_rim.bottom_radius = 1.55 if top else 1.46
		metal_rim.height = 0.16
		metal_rim.radial_segments = 24
		rim.mesh = metal_rim
		rim.position.y = 1.35 if top else -1.35
		rim.material_override = frame_mat
		body.add_child(rim)
	
	add_child(body)

func _build_observation_catwalk() -> void:
	var deck_mat := _material(Color(0.36, 0.42, 0.48), 0.35, 0.55)
	var rail_mat := _material(Color(0.40, 0.47, 0.55), 0.25, 0.45)
	
	# Catwalk Bridge at Y = +3.2m spanning across Z = -16.0m (Width 2.4m along Z, Length 18.0m along X)
	_box("ObservationCatwalkDeck", Vector3(0.0, 3.1, -16.0), Vector3(18.0, 0.2, 2.4), deck_mat, true)
	
	# Catwalk Railings
	_box("CatwalkRailNorth", Vector3(0.0, 3.7, -17.15), Vector3(18.0, 1.0, 0.1), rail_mat, true)
	_box("CatwalkRailSouth", Vector3(0.65, 3.7, -14.85), Vector3(16.7, 1.0, 0.1), rail_mat, true)
	
	# Access Stairs from Floor (Y = 0.0m) to Catwalk (Y = 3.2m) on West side (X: -9.0m to -12.0m)
	for i in range(11):
		var step_y := float(i) * 0.29
		var step_z := -9.25 - float(i) * 0.5
		_box("CatwalkStair_%d" % i, Vector3(-8.5, step_y + 0.15, step_z), Vector3(1.6, 0.2, 0.5), deck_mat, false)
	var support = preload("res://scripts/environment/room_path_support.gd")
	support.add_ramp(self, "CatwalkStairSupport", Vector3(-8.5, 0, -9), Vector3(-8.5, 3.2, -14.1), 1.6, deck_mat)
	support.add_ramp(self, "CatwalkStairLanding", Vector3(-8.5,3.2,-14.1), Vector3(-8.5,3.2,-15.3), 1.6, deck_mat)

func _build_override_terminal() -> void:
	var metal_mat := _material(Color(0.2, 0.24, 0.28), 0.7, 0.4)
	var screen_mat := _material(Color(0.05, 0.12, 0.15), 0.0, 0.2, true, Color(0.0, 0.85, 0.9), 1.8)
	_terminal_screen_material = screen_mat
	
	var terminal_script = preload("res://scripts/environment/quarantine_terminal.gd")
	_terminal_body = terminal_script.new()
	_terminal_body.name = "QuarantineOverrideTerminal"
	_terminal_body.position = Vector3(0.0, 3.2, -16.0) # Centered on Catwalk
	
	var prop := SIGNAL_CONSOLE_PROP.instantiate()
	prop.name = "Prop"
	_terminal_body.add_child(prop)
	
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 1.4, 0.9)
	col.shape = box
	_terminal_body.add_child(col)
	
	# Screen mesh
	var screen := MeshInstance3D.new()
	var s_box := BoxMesh.new()
	s_box.size = Vector3(0.9, 0.6, 0.05)
	screen.mesh = s_box
	screen.position = Vector3(0.0, 0.75, 0.38)
	screen.rotation.x = -0.3
	screen.material_override = screen_mat
	_terminal_body.add_child(screen)
	
	_terminal_light = OmniLight3D.new()
	_terminal_light.name = "TerminalLight"
	_terminal_light.position = Vector3(0.0, 1.2, 0.4)
	_terminal_light.light_color = Color(0.0, 0.85, 0.9)
	_terminal_light.light_energy = 1.4
	_terminal_light.omni_range = 3.5
	_terminal_body.add_child(_terminal_light)
	
	# Interaction Area3D
	var area := Area3D.new()
	area.name = "InteractionArea"
	var area_col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.4
	area_col.shape = sphere
	area.add_child(area_col)
	
	area.body_entered.connect(func(body: Node3D):
		if not override_done and body.has_method("register_nearby_interactable"):
			body.register_nearby_interactable(_terminal_body)
	)
	area.body_exited.connect(func(body: Node3D):
		if body.has_method("unregister_nearby_interactable"):
			body.unregister_nearby_interactable(_terminal_body)
	)
	_terminal_body.add_child(area)
	
	add_child(_terminal_body)

func _build_exit_gate() -> void:
	var gate_mat := _material(Color(0.2, 0.25, 0.3), 0.9, 0.2, true, Color(0.0, 0.85, 0.9), 0.8)
	
	_gate = StaticBody3D.new()
	_gate.name = "NorthExitBlastGate"
	_gate.position = Vector3(0.0, _gate_closed_y, -32.0)
	
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = Vector3(2.05, 2.8, 0.2)
	mesh.material_override = gate_mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_gate.add_child(mesh)
	
	_gate_shape = CollisionShape3D.new()
	_gate_shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(2.05, 2.8, 0.2)
	_gate_shape.shape = box
	_gate.add_child(_gate_shape)
	
	add_child(_gate)

func trigger_interaction(_interactor: Node = null) -> Dictionary:
	return execute_quarantine_override()

func execute_quarantine_override() -> Dictionary:
	if override_done:
		return {"success": true, "already_overridden": true}
	
	override_done = true
	if reduced_motion: _mist_amount = 0.0
	if _air_motes: _air_motes.emit_release(Vector3(0,3.8,-16))
	if not audio_muted:
		_override_sound.play()
		_latch_sound.play()
	_refresh_presentation_state()
	state = RoomState.OVERRIDE_ACTIVE
	quarantine_override_initiated.emit()
	
	_open_exit_gate()
	return {"success": true, "cleared": true}

func _open_exit_gate() -> void:
	if gate_open:
		return
	gate_open = true
	state = RoomState.QUARANTINE_CLEARED
	quarantine_cleared.emit()
	exit_gate_opened.emit()
	_animate_gate()

func _animate_gate() -> void:
	var generation := _gate_generation
	if reduced_motion:
		if _gate:
			_gate.position.y = _gate_open_y
		_finish_gate_motion.call_deferred(generation)
		return
	
	if _gate:
		var remaining := 0.8*clampf((_gate_open_y-_gate.position.y)/(_gate_open_y-_gate_closed_y),0.0,1.0)
		_gate_tween = create_tween()
		_gate_tween.tween_property(_gate, "position:y", _gate_open_y, remaining).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_gate_tween.tween_callback(func():
			_finish_gate_motion.call_deferred(generation)
		)

func _finish_gate_motion(generation: int) -> void:
	if generation==_gate_generation and gate_open and _gate_shape:
		_gate_shape.disabled = true

func _kill_gate_tween() -> void:
	_gate_generation += 1
	if _gate_tween and _gate_tween.is_valid(): _gate_tween.kill()

func get_safe_anchor() -> Vector3:
	return current_anchor

func get_state() -> Dictionary:
	return {
		"state": state,
		"current_anchor": current_anchor,
		"override_done": override_done,
		"gate_open": gate_open,
		"gate_pos_y": _gate.position.y if _gate else _gate_closed_y,
		"gate_col_disabled": _gate_shape.disabled if _gate_shape else false
	}

func restore_state(data: Dictionary) -> void:
	_kill_gate_tween()
	_stop_presentation_audio()
	if data.has("state"):
		state = data["state"]
	if data.has("current_anchor"):
		current_anchor = data["current_anchor"]
	if data.has("override_done"):
		override_done = data["override_done"]
	if data.has("gate_open"):
		gate_open = data["gate_open"]
	if _gate and data.has("gate_pos_y"):
		_gate.position.y = data["gate_pos_y"]
	if _gate_shape and data.has("gate_col_disabled"):
		_gate_shape.disabled = data["gate_col_disabled"]
	_mist_amount = 0.0 if override_done else 1.0
	if _air_motes: _air_motes._release.visible = false
	_refresh_presentation_state()
	if gate_open and (_gate.position.y<_gate_open_y-0.001 or not _gate_shape.disabled): _animate_gate()

func _build_presentation() -> void:
	_mist_material = ShaderMaterial.new()
	_mist_material.shader = preload("res://shaders/decon_mist.gdshader")
	for arch in 2:
		for layer in 2:
			var card := MeshInstance3D.new()
			card.name = "UVMist_%d_%d" % [arch,layer]
			var quad := QuadMesh.new()
			quad.size = Vector2(3.15,3.72)
			card.mesh = quad
			card.position = Vector3(0,1.92,-3.5-arch*3.0+(0.08 if layer==0 else -0.08))
			card.material_override = _mist_material
			card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(card)
			_mist_cards.append(card)
	_air_motes = preload("res://scripts/environment/room_motes.gd").new()
	_air_motes.name = "DeconAtmosphere"
	_air_motes.anchors.assign([Vector3(0,2,-5),Vector3(-8.5,2,-11.5),Vector3(0,4.2,-16)])
	_air_motes.particles_per_anchor = 14
	_air_motes.tint = Color(0.58,0.88,0.96,0.30)
	_air_motes.seed_value = 111107
	add_child(_air_motes)
	# Eleven step noses share a single draw; no stair or support shape moves.
	var noses := MultiMeshInstance3D.new()
	noses.name = "StairNoses"
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = BoxMesh.new()
	instances.mesh.size = Vector3(1.56,0.035,0.05)
	instances.instance_count = 11
	for step in 11:
		instances.set_instance_transform(step,Transform3D(Basis.IDENTITY,Vector3(-8.5,step*0.29+0.26,-9.25-step*0.5+0.23)))
	noses.multimesh = instances
	noses.material_override = _material(Color(0.12,0.48,0.55),0.1,0.7,true,Color(0.0,0.65,0.72),0.65)
	noses.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(noses)
	var guide := OmniLight3D.new()
	guide.name = "StairGuideLight"
	guide.position = Vector3(-8.5,2.2,-11.5)
	guide.light_color = Color(0.75,0.92,0.95)
	guide.light_energy = 0.75
	guide.omni_range = 6.5
	guide.shadow_enabled = false
	add_child(guide)
	_gate_status_material = _material(Color.WHITE,0,0.7,true,Color(1,0.65,0.15),0.45)
	var status := _box("GateStatusStrip",Vector3(0,3.05,-31.85),Vector3(2.1,0.12,0.08),_gate_status_material,false)
	status.get_child(0).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_override_sound = _make_sound("OverridePressure",ProceduralCinematicAudio.create_pressure_air(0.6,111110),-12.0)
	_latch_sound = _make_sound("OverrideLatch",ProceduralCinematicAudio.create_physical_signal(0.3,[0.01],111111,0.35),-8.0)
	_build_arch_hardware()
	var trim := _box("CatwalkEdgeTrim",Vector3(0,3.12,-14.79),Vector3(18,0.05,0.04),_material(Color(0.12,0.5,0.58),0.1,0.7,true,Color(0.15,0.65,0.72),0.65),false)
	trim.get_child(0).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Dedicated room layers keep the new fills off Echo's face and clothing.
	# Existing world and fixture shadows remain enabled.
	for mesh in find_children("*","MeshInstance3D",true,false): mesh.layers |= PRESENTATION_LAYER
	for mesh in find_children("*","MultiMeshInstance3D",true,false): mesh.layers |= PRESENTATION_LAYER
	_arch_fill = _make_environment_fill("ArchUVFillLight",Vector3(0,2.5,-1.3),Color(0.65,0.70,0.95),0.95,8.0)
	_make_environment_fill("UnderCatwalkFillLight",Vector3(-1.2,1.85,-15.5),Color(0.45,0.78,0.88),0.65,8.0)
	_refresh_presentation_state()

func _build_arch_hardware() -> void:
	var hardware := MultiMeshInstance3D.new()
	hardware.name = "UVArchHardware"
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = BoxMesh.new()
	batch.mesh.size = Vector3.ONE
	batch.instance_count = 16
	var index := 0
	for arch in 2:
		var z := -3.5-arch*3.0
		for side in [-1.0,1.0]:
			batch.set_instance_transform(index,Transform3D(Basis.IDENTITY.scaled(Vector3(0.05,3.5,0.08)),Vector3(side*1.58,2.0,z)))
			index += 1
		for nozzle in 6:
			batch.set_instance_transform(index,Transform3D(Basis.IDENTITY.scaled(Vector3(0.14,0.10,0.16)),Vector3(-1.35+nozzle*0.54,3.73,z)))
			index += 1
	hardware.multimesh = batch
	hardware.material_override = _arch_emitter_material
	hardware.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(hardware)

func _make_environment_fill(label: String, point: Vector3, color: Color, energy: float, radius: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = label
	light.position = point
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.light_cull_mask = PRESENTATION_LAYER
	light.shadow_enabled = false
	add_child(light)
	return light

func _make_sound(label: String,stream: AudioStream,volume: float) -> AudioStreamPlayer3D:
	var sound := AudioStreamPlayer3D.new()
	sound.name = label
	sound.position = Vector3(0,3.8,-16)
	sound.stream = stream
	sound.volume_db = volume
	sound.max_distance = 12.0
	add_child(sound)
	return sound

func _process(delta: float) -> void:
	if not _mist_material: return
	if not reduced_motion:
		_mist_time += minf(delta,0.1)
		_mist_amount = move_toward(_mist_amount,0.0 if override_done else 1.0,delta*0.9)
	_mist_material.set_shader_parameter("motion_time",_mist_time)
	_mist_material.set_shader_parameter("mist_amount",_mist_amount)
	for card in _mist_cards: card.visible = not reduced_motion and _mist_amount>0.001

func _refresh_presentation_state() -> void:
	# Leave the sensor active: an older checkpoint can register the terminal
	# again without requiring the player to leave and re-enter its area.
	if is_instance_valid(_terminal_body):
		var area: Area3D = _terminal_body.get_node("InteractionArea")
		for body in area.get_overlapping_bodies():
			if override_done and body.has_method("unregister_nearby_interactable"):
				body.unregister_nearby_interactable(_terminal_body)
			elif not override_done and body.has_method("register_nearby_interactable"):
				body.register_nearby_interactable(_terminal_body)
	var color := Color(0.25,0.95,0.65) if override_done else Color(0.0,0.85,0.9)
	if _terminal_light: _terminal_light.light_color = color
	if _terminal_screen_material: _terminal_screen_material.emission = color
	if _gate_status_material: _gate_status_material.emission = Color(0.25,0.95,0.65) if gate_open or override_done else Color(1,0.65,0.15)
	if _arch_emitter_material:
		var emitter_color := Color(0.25,0.95,0.65) if override_done else Color(0.58,0.16,0.96)
		_arch_emitter_material.albedo_color = Color(emitter_color.r*0.35,emitter_color.g*0.35,emitter_color.b*0.35)
		_arch_emitter_material.emission = emitter_color
		_arch_emitter_material.emission_energy_multiplier = 0.75 if override_done else 1.1
	if _arch_fill:
		_arch_fill.light_color = Color(0.25,0.90,0.72) if override_done else Color(0.65,0.70,0.95)
		_arch_fill.light_energy = 0.55 if override_done else 0.95
	if _mist_material:
		_mist_material.set_shader_parameter("mist_amount",_mist_amount)
		for card in _mist_cards: card.visible = not reduced_motion and _mist_amount>0.001

func _stop_presentation_audio() -> void:
	if is_instance_valid(_override_sound): _override_sound.stop()
	if is_instance_valid(_latch_sound): _latch_sound.stop()

func set_audio_muted(muted: bool) -> void:
	audio_muted = muted
