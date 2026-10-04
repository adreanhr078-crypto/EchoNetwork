extends Node3D

## Airlock Decompression Buffer (Sector 11 Buffer Zone)
## Bridges the Vertical Maintenance Shaft exit (Z = -32.0m, Y = 5.4m)
## and the Security Checkpoint entrance (Z = -50.5m, Y = 5.4m).
## Enforces the Anti-Crowding Invariant: zero shared walls, hermetic collision,
## acoustic isolation (-40dB), and double interlock cycle.

signal decompression_started
signal decompression_completed
signal outer_gate_opened
signal outer_gate_closed
signal inner_gate_opened
signal inner_gate_closed
signal player_passed_airlock

enum AirlockState {
	IDLE_OPEN_OUTER,   # Ready for entry from maintenance; outer gate open, inner locked
	SEALING_OUTER,     # Player entered; outer gate closing
	DECOMPRESSING,     # Both gates locked; steam venting & pressure equalizing (1.5s)
	EQUALIZED,         # Equalization finished; inner gate unlocking
	OPEN_INNER,        # Inner gate open; clear path to Security Checkpoint
	SEALING_INNER,     # Player exited; inner gate closing
	SECURED            # Both gates locked and sealed
}

const RELEASE_AUDIO = preload("res://assets/audio/maintenance_service_release_v1.ogg")
const CERAMIC = preload("res://assets/environments/maintenance_jutsu_v1_Maintenance ceramic grain 512.png")
const GRAPHITE = preload("res://assets/environments/maintenance_jutsu_v1_Maintenance brushed graphite 512.png")

# Geometry constants (Local space: Origin at global Vector3(0, 5.4, -32.0))
# Length: 18.5m (Z = 0.0 to -18.5m)
# Width: 2.4m interior (X = -1.2m to +1.2m)
# Height: 3.0m interior (Y = 0.0m to +3.0m)
const BUFFER_LENGTH := 18.5
const CORRIDOR_WIDTH := 2.4
const CORRIDOR_HEIGHT := 3.0
const WALL_THICKNESS := 0.4
const GATE_WIDTH := 1.8
const GATE_HEIGHT := 2.6
const PORTAL_HEIGHT := 2.8

# Z Locations in local space:
# Z = 0.0: Maintenance connection aperture (1.8m x 2.4m)
# Z = -5.5: Outer Blast Gate
# Z = -9.0: Decompression Chamber Midpoint (Safe Anchor)
# Z = -12.5: Inner Blast Gate
# Z = -18.5: Security Checkpoint connection aperture (1.8m x 2.8m)
const Z_ENTRY_PORTAL := 0.0
const Z_OUTER_GATE := -5.5
const Z_CHAMBER_CENTER := -9.0
const Z_INNER_GATE := -12.5
const Z_EXIT_PORTAL := -18.5

var state: AirlockState = AirlockState.IDLE_OPEN_OUTER
var reduced_motion := false
var audio_muted := false
var player: Node3D

var _outer_gate_body: StaticBody3D
var _outer_gate_shape: CollisionShape3D
var _outer_gate_mesh: MeshInstance3D
var _inner_gate_body: StaticBody3D
var _inner_gate_shape: CollisionShape3D
var _inner_gate_mesh: MeshInstance3D

var _outer_beacon: OmniLight3D
var _inner_beacon: OmniLight3D
var _chamber_light: OmniLight3D
var _outer_beacon_mat: StandardMaterial3D
var _inner_beacon_mat: StandardMaterial3D

var _vent_audio: AudioStreamPlayer3D
var _purge_timer := 0.0
var _is_cycling := false
var _player_detected_in_chamber := false
var _player_detected_in_exit := false

var _gate_open_y := 2.6
var _gate_closed_y := 1.3

func _ready() -> void:
	_build_airlock_architecture()
	_update_beacon_visuals()

func _physics_process(delta: float) -> void:
	if _is_cycling and state == AirlockState.DECOMPRESSING:
		_purge_timer -= delta
		if _purge_timer <= 0.0:
			_complete_decompression()
	
	if not is_instance_valid(player):
		return
	
	var local_pos := to_local(player.global_position)
	
	# Detect player entering chamber core (between Z = -6.2 and Z = -11.8)
	if state == AirlockState.IDLE_OPEN_OUTER and local_pos.z < (Z_OUTER_GATE - 0.8) and local_pos.z > (Z_INNER_GATE + 0.5):
		if absf(local_pos.x) < 1.1 and local_pos.y >= -0.2 and local_pos.y <= 2.8:
			_player_detected_in_chamber = true
			trigger_decompression_cycle()
	
	# Detect player passing through inner gate into exit corridor (Z < -13.2)
	if state == AirlockState.OPEN_INNER and local_pos.z < (Z_INNER_GATE - 0.7):
		if not _player_detected_in_exit:
			_player_detected_in_exit = true
			player_passed_airlock.emit()
			# Automatically seal inner gate behind player after 1.5s
			var seal_timer := get_tree().create_timer(1.5)
			seal_timer.timeout.connect(_seal_inner_gate)

func trigger_decompression_cycle() -> void:
	if state != AirlockState.IDLE_OPEN_OUTER:
		return
	
	state = AirlockState.SEALING_OUTER
	_update_beacon_visuals()
	
	if reduced_motion:
		_set_outer_gate_closed()
		_start_decompression_purge()
	else:
		var tween := create_tween()
		tween.tween_property(_outer_gate_body, "position:y", _gate_closed_y, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_callback(func():
			_set_outer_gate_closed()
			_start_decompression_purge()
		)

func _start_decompression_purge() -> void:
	state = AirlockState.DECOMPRESSING
	_is_cycling = true
	_purge_timer = 1.5 # 1.5s duration specified in Section 3.2
	_update_beacon_visuals()
	decompression_started.emit()
	
	if not audio_muted and _vent_audio:
		_vent_audio.play()

func _complete_decompression() -> void:
	_is_cycling = false
	state = AirlockState.EQUALIZED
	_update_beacon_visuals()
	decompression_completed.emit()
	
	# Open Inner Gate to allow entry into exit corridor / Security Checkpoint
	state = AirlockState.OPEN_INNER
	_update_beacon_visuals()
	
	if reduced_motion:
		_set_inner_gate_open()
	else:
		var tween := create_tween()
		tween.tween_property(_inner_gate_body, "position:y", _gate_open_y, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_callback(_set_inner_gate_open)

func _set_outer_gate_closed() -> void:
	_outer_gate_body.position.y = _gate_closed_y
	_outer_gate_shape.set_deferred("disabled", false)
	outer_gate_closed.emit()

func _set_outer_gate_open() -> void:
	_outer_gate_body.position.y = _gate_open_y
	_outer_gate_shape.set_deferred("disabled", true)
	outer_gate_opened.emit()

func _set_inner_gate_open() -> void:
	_inner_gate_body.position.y = _gate_open_y
	_inner_gate_shape.set_deferred("disabled", true)
	inner_gate_opened.emit()

func _set_inner_gate_closed() -> void:
	_inner_gate_body.position.y = _gate_closed_y
	_inner_gate_shape.set_deferred("disabled", false)
	inner_gate_closed.emit()

func _seal_inner_gate() -> void:
	if state != AirlockState.OPEN_INNER:
		return
	state = AirlockState.SEALING_INNER
	_update_beacon_visuals()
	
	if reduced_motion:
		_set_inner_gate_closed()
		state = AirlockState.SECURED
		_update_beacon_visuals()
	else:
		var tween := create_tween()
		tween.tween_property(_inner_gate_body, "position:y", _gate_closed_y, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_callback(func():
			_set_inner_gate_closed()
			state = AirlockState.SECURED
			_update_beacon_visuals()
		)

func set_reduced_motion(reduced: bool) -> void:
	reduced_motion = reduced

func set_audio_muted(muted: bool) -> void:
	audio_muted = muted
	if _vent_audio:
		_vent_audio.volume_db = -80.0 if muted else -18.0

func get_safe_anchor() -> Vector3:
	return to_global(Vector3(0.0, 0.1, Z_CHAMBER_CENTER))

func get_state() -> Dictionary:
	return {
		"state": int(state),
		"outer_closed": not _outer_gate_shape.disabled,
		"inner_closed": not _inner_gate_shape.disabled,
		"passed": _player_detected_in_exit
	}

func restore_state(data: Dictionary) -> bool:
	if not data.has("state"):
		return false
	state = data.state as AirlockState
	if data.get("outer_closed", false):
		_set_outer_gate_closed()
	else:
		_set_outer_gate_open()
	if data.get("inner_closed", true):
		_set_inner_gate_closed()
	else:
		_set_inner_gate_open()
	_player_detected_in_exit = data.get("passed", false)
	_update_beacon_visuals()
	return true

func _update_beacon_visuals() -> void:
	match state:
		AirlockState.IDLE_OPEN_OUTER:
			_set_beacon_color(_outer_beacon_mat, _outer_beacon, Color(0.12, 0.85, 0.4), 1.2) # Green entry
			_set_beacon_color(_inner_beacon_mat, _inner_beacon, Color(1.0, 0.2, 0.1), 0.8)   # Red locked
		AirlockState.SEALING_OUTER, AirlockState.DECOMPRESSING:
			_set_beacon_color(_outer_beacon_mat, _outer_beacon, Color(1.0, 0.55, 0.1), 1.8) # Amber pulse
			_set_beacon_color(_inner_beacon_mat, _inner_beacon, Color(1.0, 0.55, 0.1), 1.8) # Amber pulse
		AirlockState.EQUALIZED, AirlockState.OPEN_INNER:
			_set_beacon_color(_outer_beacon_mat, _outer_beacon, Color(1.0, 0.2, 0.1), 0.8)   # Red locked
			_set_beacon_color(_inner_beacon_mat, _inner_beacon, Color(0.12, 0.85, 0.75), 1.5) # Cyan passage
		AirlockState.SEALING_INNER, AirlockState.SECURED:
			_set_beacon_color(_outer_beacon_mat, _outer_beacon, Color(0.5, 0.5, 0.5), 0.4)
			_set_beacon_color(_inner_beacon_mat, _inner_beacon, Color(0.5, 0.5, 0.5), 0.4)

func _set_beacon_color(mat: StandardMaterial3D, lamp: OmniLight3D, color: Color, energy: float) -> void:
	if mat:
		mat.albedo_color = color
		mat.emission = color
		mat.emission_energy_multiplier = energy
	if lamp:
		lamp.light_color = color
		lamp.light_energy = energy

func _material(color: Color, metal: float = 0.0, rough: float = 0.7, emission: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = rough
	if emission:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.0
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
		collision.shape = BoxShape3D.new()
		collision.shape.size = size
		node.add_child(collision)
	add_child(node)
	return node

func _build_airlock_architecture() -> void:
	var wall_mat := _material(Color(0.28, 0.32, 0.36), 0.2, 0.6)
	wall_mat.albedo_texture = CERAMIC
	wall_mat.uv1_scale = Vector3(1.5, 1.5, 1.0)
	
	var floor_mat := _material(Color(0.2, 0.23, 0.26), 0.4, 0.65)
	floor_mat.albedo_texture = GRAPHITE
	floor_mat.uv1_scale = Vector3(2.0, 4.0, 1.0)
	
	var metal_mat := _material(Color(0.18, 0.22, 0.25), 0.6, 0.45)
	var trim_mat := _material(Color(0.5, 0.55, 0.58), 0.1, 0.8)
	var gate_mat := _material(Color(0.15, 0.18, 0.22), 0.75, 0.35)
	
	_outer_beacon_mat = _material(Color(0.12, 0.85, 0.4), 0.0, 0.3, true)
	_inner_beacon_mat = _material(Color(1.0, 0.2, 0.1), 0.0, 0.3, true)
	
	# 1. Continuous Hermetic Floor (Z = 0.0 to -18.5, thickness 0.4m, top at Y = 0.0)
	_box("Floor", Vector3(0.0, -WALL_THICKNESS * 0.5, -BUFFER_LENGTH * 0.5), Vector3(CORRIDOR_WIDTH, WALL_THICKNESS, BUFFER_LENGTH), floor_mat, true)
	
	# 2. Continuous Hermetic Ceiling (Z = 0.0 to -18.5, thickness 0.4m, bottom at Y = 3.0)
	_box("Ceiling", Vector3(0.0, CORRIDOR_HEIGHT + WALL_THICKNESS * 0.5, -BUFFER_LENGTH * 0.5), Vector3(CORRIDOR_WIDTH, WALL_THICKNESS, BUFFER_LENGTH), wall_mat, true)
	
	# 3. Continuous Hermetic Side Walls (West X = -1.4, East X = +1.4)
	var side_x := CORRIDOR_WIDTH * 0.5 + WALL_THICKNESS * 0.5
	_box("WestWall", Vector3(-side_x, CORRIDOR_HEIGHT * 0.5, -BUFFER_LENGTH * 0.5), Vector3(WALL_THICKNESS, CORRIDOR_HEIGHT, BUFFER_LENGTH), wall_mat, true)
	_box("EastWall", Vector3(side_x, CORRIDOR_HEIGHT * 0.5, -BUFFER_LENGTH * 0.5), Vector3(WALL_THICKNESS, CORRIDOR_HEIGHT, BUFFER_LENGTH), wall_mat, true)
	
	# 4. Entry Bulkhead Wall at Z = 0.0 (Aligns with Maintenance Exit, 1.8m x 2.4m aperture)
	# Left/Right Piers and Top Lintel
	var pier_width := (CORRIDOR_WIDTH - GATE_WIDTH) * 0.5 + WALL_THICKNESS
	var pier_center_x := GATE_WIDTH * 0.5 + pier_width * 0.5
	_box("EntryPierWest", Vector3(-pier_center_x, CORRIDOR_HEIGHT * 0.5, WALL_THICKNESS * 0.5), Vector3(pier_width, CORRIDOR_HEIGHT, WALL_THICKNESS), metal_mat, true)
	_box("EntryPierEast", Vector3(pier_center_x, CORRIDOR_HEIGHT * 0.5, WALL_THICKNESS * 0.5), Vector3(pier_width, CORRIDOR_HEIGHT, WALL_THICKNESS), metal_mat, true)
	_box("EntryLintel", Vector3(0.0, 2.7, WALL_THICKNESS * 0.5), Vector3(GATE_WIDTH, 0.6, WALL_THICKNESS), metal_mat, true)
	
	# 5. Exit Bulkhead Wall at Z = -18.5 (Aligns with Security Entry, 1.8m x 2.8m aperture)
	_box("ExitPierWest", Vector3(-pier_center_x, CORRIDOR_HEIGHT * 0.5, -BUFFER_LENGTH - WALL_THICKNESS * 0.5), Vector3(pier_width, CORRIDOR_HEIGHT, WALL_THICKNESS), metal_mat, true)
	_box("ExitPierEast", Vector3(pier_center_x, CORRIDOR_HEIGHT * 0.5, -BUFFER_LENGTH - WALL_THICKNESS * 0.5), Vector3(pier_width, CORRIDOR_HEIGHT, WALL_THICKNESS), metal_mat, true)
	_box("ExitLintel", Vector3(0.0, 2.9, -BUFFER_LENGTH - WALL_THICKNESS * 0.5), Vector3(GATE_WIDTH, 0.2, WALL_THICKNESS), metal_mat, true)
	
	# 6. Outer Blast Gate Structure (Z = -5.5)
	# Arch Frame:
	_box("OuterGateFrameWest", Vector3(-GATE_WIDTH * 0.5 - 0.15, CORRIDOR_HEIGHT * 0.5, Z_OUTER_GATE), Vector3(0.3, CORRIDOR_HEIGHT, 0.3), metal_mat, true)
	_box("OuterGateFrameEast", Vector3(GATE_WIDTH * 0.5 + 0.15, CORRIDOR_HEIGHT * 0.5, Z_OUTER_GATE), Vector3(0.3, CORRIDOR_HEIGHT, 0.3), metal_mat, true)
	_box("OuterGateFrameTop", Vector3(0.0, 2.8, Z_OUTER_GATE), Vector3(GATE_WIDTH + 0.6, 0.4, 0.3), metal_mat, true)
	
	# Outer Sliding Gate Panel:
	_outer_gate_body = StaticBody3D.new()
	_outer_gate_body.name = "OuterGate"
	_outer_gate_body.position = Vector3(0.0, _gate_open_y, Z_OUTER_GATE)
	_outer_gate_mesh = MeshInstance3D.new()
	_outer_gate_mesh.mesh = BoxMesh.new()
	_outer_gate_mesh.mesh.size = Vector3(GATE_WIDTH, GATE_HEIGHT, 0.18)
	_outer_gate_mesh.material_override = gate_mat
	_outer_gate_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_outer_gate_body.add_child(_outer_gate_mesh)
	_outer_gate_shape = CollisionShape3D.new()
	_outer_gate_shape.name = "CollisionShape3D"
	var outer_shape := BoxShape3D.new()
	outer_shape.size = Vector3(GATE_WIDTH, GATE_HEIGHT, 0.18)
	_outer_gate_shape.shape = outer_shape
	_outer_gate_shape.disabled = true # Starts open
	_outer_gate_body.add_child(_outer_gate_shape)
	add_child(_outer_gate_body)
	
	# Outer Gate Status Beacon:
	var outer_beacon_mesh := MeshInstance3D.new()
	outer_beacon_mesh.mesh = BoxMesh.new()
	outer_beacon_mesh.mesh.size = Vector3(0.4, 0.12, 0.08)
	outer_beacon_mesh.position = Vector3(0.0, 2.75, Z_OUTER_GATE + 0.18)
	outer_beacon_mesh.material_override = _outer_beacon_mat
	add_child(outer_beacon_mesh)
	
	_outer_beacon = OmniLight3D.new()
	_outer_beacon.position = Vector3(0.0, 2.65, Z_OUTER_GATE + 0.35)
	_outer_beacon.omni_range = 3.5
	_outer_beacon.light_energy = 1.2
	_outer_beacon.shadow_enabled = false
	add_child(_outer_beacon)
	
	# 7. Inner Blast Gate Structure (Z = -12.5)
	_box("InnerGateFrameWest", Vector3(-GATE_WIDTH * 0.5 - 0.15, CORRIDOR_HEIGHT * 0.5, Z_INNER_GATE), Vector3(0.3, CORRIDOR_HEIGHT, 0.3), metal_mat, true)
	_box("InnerGateFrameEast", Vector3(GATE_WIDTH * 0.5 + 0.15, CORRIDOR_HEIGHT * 0.5, Z_INNER_GATE), Vector3(0.3, CORRIDOR_HEIGHT, 0.3), metal_mat, true)
	_box("InnerGateFrameTop", Vector3(0.0, 2.8, Z_INNER_GATE), Vector3(GATE_WIDTH + 0.6, 0.4, 0.3), metal_mat, true)
	
	# Inner Sliding Gate Panel:
	_inner_gate_body = StaticBody3D.new()
	_inner_gate_body.name = "InnerGate"
	_inner_gate_body.position = Vector3(0.0, _gate_closed_y, Z_INNER_GATE)
	_inner_gate_mesh = MeshInstance3D.new()
	_inner_gate_mesh.mesh = BoxMesh.new()
	_inner_gate_mesh.mesh.size = Vector3(GATE_WIDTH, GATE_HEIGHT, 0.18)
	_inner_gate_mesh.material_override = gate_mat
	_inner_gate_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_inner_gate_body.add_child(_inner_gate_mesh)
	_inner_gate_shape = CollisionShape3D.new()
	_inner_gate_shape.name = "CollisionShape3D"
	var inner_shape := BoxShape3D.new()
	inner_shape.size = Vector3(GATE_WIDTH, GATE_HEIGHT, 0.18)
	_inner_gate_shape.shape = inner_shape
	_inner_gate_shape.disabled = false # Starts closed
	_inner_gate_body.add_child(_inner_gate_shape)
	add_child(_inner_gate_body)
	
	# Inner Gate Status Beacon:
	var inner_beacon_mesh := MeshInstance3D.new()
	inner_beacon_mesh.mesh = BoxMesh.new()
	inner_beacon_mesh.mesh.size = Vector3(0.4, 0.12, 0.08)
	inner_beacon_mesh.position = Vector3(0.0, 2.75, Z_INNER_GATE - 0.18)
	inner_beacon_mesh.material_override = _inner_beacon_mat
	add_child(inner_beacon_mesh)
	
	_inner_beacon = OmniLight3D.new()
	_inner_beacon.position = Vector3(0.0, 2.65, Z_INNER_GATE - 0.35)
	_inner_beacon.omni_range = 3.5
	_inner_beacon.light_energy = 0.8
	_inner_beacon.shadow_enabled = false
	add_child(_inner_beacon)
	
	# 8. Decompression Chamber Core Interior Details (Between Z = -5.5 and Z = -12.5)
	# Wall Ribs & Pressure Ducts:
	for z_rib in [-7.2, -9.0, -10.8]:
		_box("ChamberRibWest_" + str(z_rib), Vector3(-1.12, 1.5, z_rib), Vector3(0.12, 2.8, 0.2), metal_mat)
		_box("ChamberRibEast_" + str(z_rib), Vector3(1.12, 1.5, z_rib), Vector3(0.12, 2.8, 0.2), metal_mat)
		_box("FloorTrough_" + str(z_rib), Vector3(0.0, 0.005, z_rib), Vector3(2.2, 0.01, 0.15), trim_mat)
	
	# Overhead Diffused Chamber Lighting:
	_chamber_light = OmniLight3D.new()
	_chamber_light.name = "ChamberLight"
	_chamber_light.position = Vector3(0.0, 2.6, Z_CHAMBER_CENTER)
	_chamber_light.light_color = Color(0.75, 0.82, 0.9)
	_chamber_light.light_energy = 0.85
	_chamber_light.omni_range = 6.0
	_chamber_light.shadow_enabled = true # One controlled shadow caster per budget
	add_child(_chamber_light)
	
	# Entry & Exit Transition Soft Lamps (Non-shadow casting):
	var entry_lamp := OmniLight3D.new()
	entry_lamp.name = "EntryLamp"
	entry_lamp.position = Vector3(0.0, 2.6, -2.5)
	entry_lamp.light_color = Color(0.65, 0.75, 0.85)
	entry_lamp.light_energy = 0.6
	entry_lamp.omni_range = 4.0
	entry_lamp.shadow_enabled = false
	add_child(entry_lamp)
	
	var exit_lamp := OmniLight3D.new()
	exit_lamp.name = "ExitLamp"
	exit_lamp.position = Vector3(0.0, 2.6, -15.5)
	exit_lamp.light_color = Color(0.7, 0.72, 0.8)
	exit_lamp.light_energy = 0.6
	exit_lamp.omni_range = 4.0
	exit_lamp.shadow_enabled = false
	add_child(exit_lamp)
	
	# Vent Audio Player:
	_vent_audio = AudioStreamPlayer3D.new()
	_vent_audio.name = "DecompressionAudio"
	_vent_audio.stream = RELEASE_AUDIO
	_vent_audio.position = Vector3(0.0, 2.4, Z_CHAMBER_CENTER)
	_vent_audio.volume_db = -18.0
	_vent_audio.max_distance = 12.0
	add_child(_vent_audio)
