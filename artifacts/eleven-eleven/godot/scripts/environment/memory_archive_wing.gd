extends Node3D

## Room 6: Memory Archive Wing (Sector 11 Data Vault & Holographic Core)
## Follows Specimen Containment Wing via the 14m Arched Cable Conduit.
## Enforces the Anti-Crowding Invariant:
## - Watertight Hull (22.0m x 28.0m x 8.5m), solid collision envelope, zero light bleed.
## - Narrative & Gameplay Flow:
##   * Pacing Reset: Calm, haunting digital stillness contrasting with Room 5's stealth panic.
##   * Vertical parkour traversal on server racks and elevated catwalks.
##   * Recovery of 3 fractured memory shards (Shizuka, Yuki, Sector 11 Abduction).
##   * Central console decoding sequence that unlocks the North Blast Gate to Room 7.
## - Full accessibility: reduced motion, audio mute, safe anchors, durable state save/restore.

signal memory_shard_collected(shard_id: String)
signal memory_sequence_activated(shard_id: String)
signal archive_unlocked
signal exit_gate_opened
signal retry_requested(anchor: Vector3)
signal passage_ready

enum RoomState {
	ENTRY_TUNNEL,
	ARCHIVE_EXPLORATION,
	SHARDS_COLLECTED,
	ARCHIVE_UNLOCKED,
	EXIT_CORRIDOR
}

const CERAMIC = preload("res://assets/environments/maintenance_jutsu_v1_Maintenance ceramic grain 512.png")
const GRAPHITE = preload("res://assets/environments/maintenance_jutsu_v1_Maintenance brushed graphite 512.png")
const SERVER_RACK_PROP = preload("res://assets/props/server_rack.glb")
const SIGNAL_CONSOLE_PROP = preload("res://assets/props/signal_console_jutsu.glb")

const ROOM_WIDTH := 22.0 # X: 0.0m to -22.0m (center = -11.0m)
const ROOM_LENGTH := 28.0 # Z: +14.0m to -14.0m (center = 0.0m)
const ROOM_HEIGHT := 8.5 # Y: 0.0m to +8.5m
const WALL_THICKNESS := 0.4

const SAFE_ANCHOR_ENTRY := Vector3(-2.0, 0.1, 0.0)
const SAFE_ANCHOR_CENTER := Vector3(-11.0, 0.1, 0.0)
const SAFE_ANCHOR_CATWALK := Vector3(-11.0, 3.7, 0.0)

var state: RoomState = RoomState.ENTRY_TUNNEL
var reduced_motion := false
var audio_muted := false
var player: Node3D

var collected_shards: Array[String] = []
var archive_decoded := false
var gate_open := false

var _gate: StaticBody3D
var _gate_shape: CollisionShape3D
var _gate_closed_y := 1.4
var _gate_open_y := 4.8

var _core_light: OmniLight3D
var _core_pillar: MeshInstance3D
var _console_body: Node3D
var _shard_nodes: Dictionary = {}

func _ready() -> void:
	_build_room_geometry()
	_build_catwalk_and_racks()
	_build_holographic_core()
	_build_memory_shards()
	_build_console_terminal()
	_build_exit_gate()
	preload("res://scripts/environment/room_service_lighting.gd").install(self,Rect2(-22,-14,22,28),8.5)

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

func _build_room_geometry() -> void:
	var wall_mat := _material(Color(0.22, 0.25, 0.29), 0.2, 0.6)
	wall_mat.albedo_texture = CERAMIC
	wall_mat.uv1_scale = Vector3(3.0, 3.0, 1.0)
	
	var floor_mat := _material(Color(0.14, 0.16, 0.2), 0.6, 0.5)
	floor_mat.albedo_texture = GRAPHITE
	floor_mat.uv1_scale = Vector3(4.0, 4.0, 1.0)
	
	var metal_mat := _material(Color(0.18, 0.2, 0.24), 0.75, 0.4)
	
	var center_x := -ROOM_WIDTH * 0.5 # -11.0m
	var center_z := 0.0 # 0.0m
	
	# 1. Floor (Y = 0.0m, thickness 0.4m)
	_box("Floor", Vector3(center_x, -WALL_THICKNESS * 0.5, center_z), Vector3(ROOM_WIDTH, WALL_THICKNESS, ROOM_LENGTH), floor_mat, true)
	
	# 2. Ceiling (Y = 8.5m, thickness 0.4m)
	_box("Ceiling", Vector3(center_x, ROOM_HEIGHT + WALL_THICKNESS * 0.5, center_z), Vector3(ROOM_WIDTH, WALL_THICKNESS, ROOM_LENGTH), wall_mat, true)
	
	# 3. South Wall (Z = +14.0m, solid)
	_box("SouthWall", Vector3(center_x, ROOM_HEIGHT * 0.5, 14.0 + WALL_THICKNESS * 0.5), Vector3(ROOM_WIDTH, ROOM_HEIGHT, WALL_THICKNESS), wall_mat, true)
	
	# 4. West Wall (X = -22.0m, solid)
	_box("WestWall", Vector3(-ROOM_WIDTH - WALL_THICKNESS * 0.5, ROOM_HEIGHT * 0.5, center_z), Vector3(WALL_THICKNESS, ROOM_HEIGHT, ROOM_LENGTH), wall_mat, true)
	
	# 5. East Wall (X = 0.0m) with Entrance Portal from conduit
	# Entrance portal: 2.6m wide (Z = -1.3m to +1.3m) x 3.2m high
	var east_x := WALL_THICKNESS * 0.5
	# EastWallNorth: Z = -14.0m to -1.3m (length = 12.7m, center Z = -7.65m)
	_box("EastWallNorth", Vector3(east_x, ROOM_HEIGHT * 0.5, -7.65), Vector3(WALL_THICKNESS, ROOM_HEIGHT, 12.7), wall_mat, true)
	# EastWallSouth: Z = +1.3m to +14.0m (length = 12.7m, center Z = +7.65m)
	_box("EastWallSouth", Vector3(east_x, ROOM_HEIGHT * 0.5, 7.65), Vector3(WALL_THICKNESS, ROOM_HEIGHT, 12.7), wall_mat, true)
	# EastLintel: above portal from Y = 3.2m to 8.5m (height = 5.3m, center Y = 5.85m, length = 2.6m)
	_box("EastLintel", Vector3(east_x, 5.85, 0.0), Vector3(WALL_THICKNESS, 5.3, 2.6), metal_mat, true)
	
	# 6. North Wall (Z = -14.0m) with Exit Blast Gate
	# Exit doorway: 2.05m wide (X = -12.025m to -9.975m) x 2.8m high at center X = -11.0m
	var north_z := -14.0 - WALL_THICKNESS * 0.5
	# NorthWallWest: from X = -22.0m to -12.025m (width = 9.975m, center X = -17.0125m)
	_box("NorthWallWest", Vector3(-17.0125, ROOM_HEIGHT * 0.5, north_z), Vector3(9.975, ROOM_HEIGHT, WALL_THICKNESS), wall_mat, true)
	# NorthWallEast: from X = -9.975m to 0.0m (width = 9.975m, center X = -4.9875m)
	_box("NorthWallEast", Vector3(-4.9875, ROOM_HEIGHT * 0.5, north_z), Vector3(9.975, ROOM_HEIGHT, WALL_THICKNESS), wall_mat, true)
	# NorthLintel: above exit doorway from Y = 2.8m to 8.5m (height = 5.7m, center Y = 5.65m, width = 2.05m)
	_box("NorthLintel", Vector3(-11.0, 5.65, north_z), Vector3(2.05, 5.7, WALL_THICKNESS), metal_mat, true)

func _build_catwalk_and_racks() -> void:
	var catwalk_mat := _material(Color(0.2, 0.23, 0.28), 0.7, 0.4)
	var rail_mat := _material(Color(0.15, 0.18, 0.22), 0.8, 0.3)
	
	# Elevated Catwalk Bridge at Y = 3.6m along Z = 0.0m (spanning from X = -3.0m to -19.0m, width 2.2m)
	_box("CatwalkBridge", Vector3(-11.0, 3.5, 0.0), Vector3(16.0, 0.2, 2.2), catwalk_mat, true)
	
	# Catwalk Railings
	_box("CatwalkRailNorth", Vector3(-11.0, 4.1, -1.05), Vector3(16.0, 1.0, 0.1), rail_mat, true)
	_box("CatwalkRailSouth", Vector3(-11.9, 4.1, 1.05), Vector3(14.2, 1.0, 0.1), rail_mat, true)
	
	# Access Stairs from Floor (Y = 0) to Catwalk (Y = 3.6) near East entrance
	for i in range(12):
		var step_y := i * 0.3
		var step_z := 7.9 - i * 0.55
		_box("CatwalkStair_%d" % i, Vector3(-3.8, step_y + 0.15, step_z), Vector3(1.8, 0.3, 0.58), catwalk_mat, false)
	# Continuous support under the visible treads; a capsule cannot step up
	# twelve 30cm collision risers without repeatedly jumping.
	var support = preload("res://scripts/environment/room_path_support.gd")
	support.add_ramp(self, "CatwalkStairSupport", Vector3(-3.8,0,8.4), Vector3(-3.8,3.6,1.6), 1.8)
	support.add_ramp(self, "CatwalkStairLanding", Vector3(-3.8,3.6,1.6), Vector3(-3.8,3.6,0.8), 1.8, catwalk_mat)
	
	# Server Rack Rows (North row at Z = -6.5m, South row at Z = +6.5m)
	# Instantiating 3D props with collision
	var rack_x_coords := [-6.0, -11.0, -16.0]
	for rx in rack_x_coords:
		_create_server_tower(Vector3(rx, 0.0, -6.5), "NorthRack_%d" % int(abs(rx)))
		_create_server_tower(Vector3(rx, 0.0, 6.5), "SouthRack_%d" % int(abs(rx)))

func _create_server_tower(pos: Vector3, label: String) -> void:
	var tower := StaticBody3D.new()
	tower.name = label
	tower.position = pos
	
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 6.5, 1.8)
	col.shape = shape
	col.position = Vector3(0.0, 3.25, 0.0)
	tower.add_child(col)
	
	if SERVER_RACK_PROP:
		var visual = SERVER_RACK_PROP.instantiate()
		visual.name = "Model"
		visual.scale = Vector3(1.2, 1.3, 1.2)
		tower.add_child(visual)
	else:
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(2.4, 6.5, 1.8)
		visual.mesh = mesh
		visual.position = Vector3(0.0, 3.25, 0.0)
		tower.add_child(visual)
	
	# Climbable ladder rungs on the side of the rack for vertical parkour
	for r in range(10):
		var rung_y := 0.6 + r * 0.6
		var rung := _box(label + "_Rung_%d" % r, pos + Vector3(1.25, rung_y, 0.0), Vector3(0.15, 0.1, 0.8), _material(Color(0.0, 0.8, 0.9, 1.0), 0.5, 0.3, true, Color(0.0, 0.8, 0.9), 1.2), true)
		# Tag as climbable surface for surface traversal motor
		rung.set_meta("climbable", true)
	
	add_child(tower)

func _build_holographic_core() -> void:
	var core_mat := _material(Color(0.1, 0.15, 0.2), 0.8, 0.2)
	var glow_mat := _material(Color(0.9, 0.85, 0.6, 0.7), 0.0, 0.1, true, Color(1.0, 0.9, 0.65), 2.8)
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# Central circular pedestal under catwalk
	var pedestal := StaticBody3D.new()
	pedestal.name = "HolographicCorePedestal"
	pedestal.position = Vector3(-11.0, 0.5, 0.0)
	
	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.5
	cyl.bottom_radius = 2.8
	cyl.height = 1.0
	mesh_inst.mesh = cyl
	mesh_inst.material_override = core_mat
	pedestal.add_child(mesh_inst)
	
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape := CylinderShape3D.new()
	shape.radius = 2.8
	shape.height = 1.0
	col.shape = shape
	pedestal.add_child(col)
	add_child(pedestal)
	
	# Holographic projection pillar
	_core_pillar = MeshInstance3D.new()
	_core_pillar.name = "CoreBeamPillar"
	var beam := CylinderMesh.new()
	beam.top_radius = 0.8
	beam.bottom_radius = 0.8
	beam.height = 7.5
	_core_pillar.mesh = beam
	_core_pillar.position = Vector3(-11.0, 4.25, 0.0)
	_core_pillar.material_override = glow_mat
	add_child(_core_pillar)
	
	# Warm memory ambient light
	_core_light = OmniLight3D.new()
	_core_light.name = "CoreLight"
	_core_light.position = Vector3(-11.0, 3.5, 0.0)
	_core_light.omni_range = 16.0
	_core_light.light_color = Color(1.0, 0.92, 0.7) # Warm ivory-gold memory radiance
	_core_light.light_energy = 2.2
	_core_light.shadow_enabled = true
	add_child(_core_light)

func _build_memory_shards() -> void:
	var shard_configs := [
		{
			"id": "shard_shizuka",
			"pos": Vector3(-6.0, 0.85, 4.1),
			"title_en": "Memory fragment 01: Shizuka",
			"title_ar": "شظية الذاكرة 01: شيزوكا",
			"text_en": "Shizuka. A familiar presence in a memory that has not fully returned.",
			"text_ar": "شيزوكا. حضور تعرفه في ذاكرة لم تستعدها كاملة."
		},
		{
			"id": "shard_yuki",
			"pos": Vector3(-16.0, 0.85, -4.1),
			"title_en": "Memory fragment 02: Yuki",
			"title_ar": "شظية الذاكرة 02: يوكي",
			"text_en": "Yuki. You recognize him, but the memory remains fragmented.",
			"text_ar": "يوكي. تعرفه، لكن الذاكرة ما زالت متقطعة."
		},
		{
			"id": "shard_sector11",
			"pos": Vector3(-11.0, 3.95, 0.0),
			"title_en": "Memory fragment 03: EX-011",
			"title_ar": "شظية الذاكرة 03: EX-011",
			"text_en": "EX-011. The identifier links this fragment to the experiment. Recover the remaining fragments.",
			"text_ar": "EX-011. الرمز يربط هذه الشظية بالتجربة. استعد بقية الشظايا."
		}
	]
	
	var crystal_mat := _material(Color(0.2, 0.85, 1.0, 0.85), 0.1, 0.1, true, Color(0.1, 0.9, 1.0), 3.0)
	crystal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	for cfg in shard_configs:
		var sid: String = cfg["id"]
		var pos: Vector3 = cfg["pos"]
		
		var shard_body := Area3D.new()
		shard_body.name = "Shard_" + sid
		shard_body.position = pos
		shard_body.set_meta("shard_config", cfg)
		
		# Visual floating octahedron / diamond crystal
		var mesh_inst := MeshInstance3D.new()
		var prism := BoxMesh.new()
		prism.size = Vector3(0.45, 0.7, 0.45)
		mesh_inst.mesh = prism
		mesh_inst.rotation = Vector3(PI * 0.25, 0.0, PI * 0.25)
		mesh_inst.material_override = crystal_mat
		shard_body.add_child(mesh_inst)
		
		# Collision Area
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var sphere := SphereShape3D.new()
		sphere.radius = 1.4
		col.shape = sphere
		shard_body.add_child(col)
		
		# Local glow light
		var light := OmniLight3D.new()
		light.name = "ShardLight"
		light.omni_range = 3.5
		light.light_color = Color(0.2, 0.85, 1.0)
		light.light_energy = 1.8
		shard_body.add_child(light)
		
		shard_body.body_entered.connect(func(body: Node3D):
			if body.has_method("finish_opening_recovery"):
				_collect_shard(sid)
		)
		
		add_child(shard_body)
		_shard_nodes[sid] = shard_body

func _collect_shard(shard_id: String) -> Dictionary:
	if collected_shards.has(shard_id):
		return {"already_collected": true}
	
	collected_shards.append(shard_id)
	memory_shard_collected.emit(shard_id)
	
	# Deactivate visual and collision for collected shard
	if _shard_nodes.has(shard_id):
		var node: Area3D = _shard_nodes[shard_id]
		var col: CollisionShape3D = node.get_node_or_null("CollisionShape3D")
		if col:
			col.set_deferred("disabled", true)
		node.visible = false
	
	# Check if all shards gathered
	if collected_shards.size() >= 3:
		state = RoomState.SHARDS_COLLECTED
		# Warm pulse in central core
		if _core_light:
			_core_light.light_color = Color(1.0, 0.8, 0.3)
			_core_light.light_energy = 3.6
	
	return {"success": true, "shard_id": shard_id, "total": collected_shards.size()}

func _build_console_terminal() -> void:
	_console_body = StaticBody3D.new()
	_console_body.name = "ArchiveDecoderConsole"
	_console_body.position = Vector3(-11.0, 0.6, -3.2)
	
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 1.2, 1.2)
	col.shape = shape
	_console_body.add_child(col)
	
	if SIGNAL_CONSOLE_PROP:
		var model = SIGNAL_CONSOLE_PROP.instantiate()
		model.name = "Model"
		model.scale = Vector3(1.0, 1.0, 1.0)
		_console_body.add_child(model)
	else:
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.8, 1.2, 1.2)
		visual.mesh = mesh
		visual.material_override = _material(Color(0.2, 0.24, 0.28), 0.7, 0.4)
		_console_body.add_child(visual)
	
	# Interactive Area for Player 'E' / touch interaction
	var area := Area3D.new()
	area.name = "InteractionArea"
	var area_col := CollisionShape3D.new()
	area_col.name = "CollisionShape3D"
	var cyl := CylinderShape3D.new()
	cyl.radius = 2.4
	cyl.height = 2.5
	area_col.shape = cyl
	area.add_child(area_col)
	_console_body.add_child(area)
	
	area.body_entered.connect(func(body: Node3D):
		if body.has_method("register_nearby_interactable"):
			body.register_nearby_interactable(self)
	)
	area.body_exited.connect(func(body: Node3D):
		if body.has_method("unregister_nearby_interactable"):
			body.unregister_nearby_interactable(self)
	)
	
	add_child(_console_body)

func trigger_interaction(_interactor: Node = null) -> Dictionary:
	return decode_archive_and_unlock()

func get_interaction_position() -> Vector3:
	return _console_body.global_position + Vector3.UP * 0.5

func decode_archive_and_unlock() -> Dictionary:
	if collected_shards.size() < 3:
		return {
			"success": false,
			"reason": "missing_shards",
			"collected": collected_shards.size(),
			"required": 3,
			"message_en": "Memory Resonance Incomplete: %d/3 shards inserted." % collected_shards.size(),
			"message_ar": "رنين الذاكرة غير مكتمل: تم إدخال %d/3 شظايا فقط." % collected_shards.size()
		}
	
	if archive_decoded:
		return {"success": true, "already_decoded": true}
	
	archive_decoded = true
	state = RoomState.ARCHIVE_UNLOCKED
	archive_unlocked.emit()
	
	_open_exit_gate()
	
	return {
		"success": true,
		"decoded": true,
		"message_en": "Archive sequence reconstructed: EX-011 neural lock disengaged. Reactor conduit open.",
		"message_ar": "تم فك تشفير مصفوفة الذاكرة: رنين قفل EX-011 ملغى. ممر المفاعل مفتوح الآن."
	}

func _build_exit_gate() -> void:
	var metal_mat := _material(Color(0.18, 0.22, 0.26), 0.75, 0.35)
	
	# Lintel frame above doorway on North Wall at Z = -14.0m
	_box("ExitGateFrameTop", Vector3(-11.0, 3.2, -14.0), Vector3(2.25, 0.4, 0.5), metal_mat, true)
	
	_gate = StaticBody3D.new()
	_gate.name = "NorthExitBlastGate"
	_gate.position = Vector3(-11.0, _gate_closed_y, -14.0)
	
	var gate_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.05, 2.8, 0.25)
	gate_mesh.mesh = box
	gate_mesh.material_override = metal_mat
	gate_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_gate.add_child(gate_mesh)
	
	_gate_shape = CollisionShape3D.new()
	_gate_shape.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.05, 2.8, 0.25)
	_gate_shape.shape = shape
	_gate_shape.disabled = false # Starts locked
	_gate.add_child(_gate_shape)
	
	add_child(_gate)

func _open_exit_gate() -> void:
	if gate_open:
		return
	gate_open = true
	exit_gate_opened.emit()
	passage_ready.emit()
	
	if reduced_motion:
		if _gate:
			_gate.position.y = _gate_open_y
		if _gate_shape:
			_gate_shape.set_deferred("disabled", true)
	else:
		if _gate:
			var tween := create_tween()
			tween.tween_property(_gate, "position:y", _gate_open_y, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			tween.tween_callback(func():
				if _gate_shape:
					_gate_shape.set_deferred("disabled", true)
			)

func get_state() -> Dictionary:
	return {
		"state": state,
		"collected_shards": collected_shards.duplicate(),
		"archive_decoded": archive_decoded,
		"gate_open": gate_open
	}

func restore_state(saved: Dictionary) -> bool:
	if not saved.is_empty() and saved.has("collected_shards"):
		state = saved.get("state", RoomState.ENTRY_TUNNEL)
		collected_shards.assign(saved.get("collected_shards", []))
		archive_decoded = saved.get("archive_decoded", false)
		gate_open = saved.get("gate_open", false)
		
		# Restore collected shards visibility & collision
		for sid in collected_shards:
			if _shard_nodes.has(sid):
				var node: Area3D = _shard_nodes[sid]
				var col: CollisionShape3D = node.get_node_or_null("CollisionShape3D")
				if col:
					col.disabled = true
				node.visible = false
		
		if gate_open:
			if _gate:
				_gate.position.y = _gate_open_y
			if _gate_shape:
				_gate_shape.disabled = true
		else:
			if _gate:
				_gate.position.y = _gate_closed_y
			if _gate_shape:
				_gate_shape.disabled = false
		return true
	return false
