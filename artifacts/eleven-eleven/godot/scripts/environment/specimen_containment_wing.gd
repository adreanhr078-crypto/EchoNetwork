extends Node3D

## Room 5: Specimen Containment Wing (Sector 11 Bio-Preservation Facility)
## Follows Security Checkpoint exit via westward descending biological drainage.
## Enforces the Anti-Crowding Invariant:
## - Hermetic hull (30.0m x 24.0m x 7.2m), watertight collision, zero light bleed.
## - Narrative revelation: Echo discovers failed test subjects EX-005 to EX-010,
##   and reads the alarming status for EX-011 (Echo himself: MISSING / ACTIVE BREACH).
## - Stealth traversal: Heavy biological filter plinths occlude the automated ceiling surveillance scanner.
## - Bilingual dialogue and inspection logs (Arabic & English), audio mute, reduced motion, safe anchors.

signal specimen_inspected(subject_id: String)
signal terminal_accessed(log_id: String)
signal exit_gate_opened
signal retry_requested(anchor: Vector3)
signal passage_ready

enum RoomState {
	ENTRY_VESTIBULE,
	STEALTH_TRAVERSAL,
	TERMINAL_DISCOVERED,
	GATE_UNLOCKED,
	EXIT_CORRIDOR
}

const RELEASE_AUDIO = preload("res://assets/audio/maintenance_service_release_v1.ogg")
const CERAMIC = preload("res://assets/environments/maintenance_jutsu_v1_Maintenance ceramic grain 512.png")
const GRAPHITE = preload("res://assets/environments/maintenance_jutsu_v1_Maintenance brushed graphite 512.png")

# Geometry metrics (Local coordinate system: Origin at Vector3(-20.0, -4.0, -75.0))
# Width (along X): 30.0m (X = 0.0m to -30.0m)
# Length (along Z): 24.0m (Z = +6.0m to -18.0m)
# Height (along Y): 7.2m (Y = 0.0m to +7.2m)
const ROOM_WIDTH := 30.0
const ROOM_LENGTH := 24.0
const ROOM_HEIGHT := 7.2
const WALL_THICKNESS := 0.4

const SAFE_ANCHOR_ENTRY := Vector3(-2.5, 0.1, 2.0)
const SAFE_ANCHOR_MIDPOINT := Vector3(-15.0, 0.1, -6.0)
const SAFE_ANCHOR_TERMINAL := Vector3(-24.0, 0.1, -12.0)

var state: RoomState = RoomState.ENTRY_VESTIBULE
var reduced_motion := false
var audio_muted := false
var player: Node3D

var gate_open := false
var terminal_read := false
var discoveries: Array[String] = []

var _scanner_head: Node3D
var _scanner_beam: Light3D
var _scanner_cone: MeshInstance3D
var _scanner_sweep_angle := 0.0
var _scanner_sweep_speed := 1.2
var _scanner_active := true

var _gate: StaticBody3D
var _gate_shape: CollisionShape3D
var _gate_open_y := 4.8
var _gate_closed_y := 1.4

var _terminal_body: StaticBody3D
var _terminal_light: OmniLight3D

var _specimen_tanks: Array[Dictionary] = []
var _cover_plinths: Array[StaticBody3D] = []

func _ready() -> void:
	_build_room_geometry()
	_build_specimen_tanks()
	_build_cover_plinths()
	_build_scanner_system()
	_build_terminal()
	_build_exit_gate()

var _alert_timer := 0.0
const ALERT_GRACE_TIME := 0.6

func _physics_process(delta: float) -> void:
	if _scanner_active and _scanner_head:
		if not reduced_motion:
			_scanner_sweep_angle += _scanner_sweep_speed * delta
			_scanner_head.rotation.y = sin(_scanner_sweep_angle) * 0.75 + PI * 0.5
			_scanner_head.rotation.x = -0.6 # Angled downward toward floor traversal
		
		# Check if scanner spots player
		if player and is_instance_valid(player):
			if _scanner_sees(player):
				_alert_timer += delta
				if _alert_timer < ALERT_GRACE_TIME:
					# Phase 2: Amber Suspicion (reaction window for player to slide into cover)
					if _scanner_beam:
						_scanner_beam.light_color = Color(1.0, 0.72, 0.05)
				else:
					# Phase 3: Crimson Alarm & safe reposition
					_on_player_spotted()
			else:
				# Cool down back to Phase 1: Cold Cyan
				_alert_timer = maxf(0.0, _alert_timer - delta * 2.5)
				if _alert_timer <= 0.0 and _scanner_beam:
					_scanner_beam.light_color = Color(0.0, 0.9, 1.0)

func _scanner_sees(target: Node3D) -> bool:
	if not _scanner_head or not target:
		return false
	
	var scanner_pos := _scanner_head.global_position
	var target_torso := target.global_position + Vector3.UP * 0.9
	var to_target := target_torso - scanner_pos
	var dist := to_target.length()
	
	# Scanner range is 22.0m
	if dist > 22.0:
		return false
	
	# Conical angle check: forward direction of scanner head
	var scanner_fwd: Vector3 = -_scanner_head.global_transform.basis.z.normalized()
	var dir_to_target := to_target.normalized()
	var dot := scanner_fwd.dot(dir_to_target)
	
	# Conical field of view (~45 degrees half-angle)
	if dot < 0.70:
		return false
	
	# Direct Physics Raycast to check for cover occlusion
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(scanner_pos, target_torso)
	if target is CollisionObject3D:
		query.exclude = [(target as CollisionObject3D).get_rid()]
	
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return true # Unobstructed line of sight
	
	# If ray hit target collider directly, player is seen
	if hit.collider == target:
		return true
	
	# Ray hit cover plinth or wall; player is safely occluded!
	return false

func _on_player_spotted() -> void:
	# Alert state: turn scanner crimson
	if _scanner_beam:
		_scanner_beam.light_color = Color(1.0, 0.15, 0.1) # Crimson alarm
	_alert_timer = 0.0
	
	# Trigger retry to safe anchor
	var anchor := SAFE_ANCHOR_ENTRY
	if global_position.distance_to(player.global_position) > 16.0:
		anchor = SAFE_ANCHOR_MIDPOINT
	
	retry_requested.emit(anchor)

func request_terminal_access() -> Dictionary:
	terminal_read = true
	if not discoveries.has("ex_011_log"):
		discoveries.append("ex_011_log")
	
	terminal_accessed.emit("ex_011_log")
	
	# Terminal reading unlocks the exit blast gate
	if not gate_open:
		_open_exit_gate()
	
	return {
		"accepted": true,
		"log_id": "EX_011_RECORD",
		"subject": "Echo (Designation EX-011)",
		"status": "ANOMALOUS / CONTRACT CANDIDATE",
		"text_en": "SPECIMEN LOG 011: Subject awakened prematurely without memory suppression. Neurological baseline intact. Dr. Kinja orders containment.",
		"text_ar": "سجل العينة 011: استيقظت العينة مبكراً دون إخماد الذاكرة. مؤشرات الدماغ سليمة. د. كينجا يأمر بضبط الاحتواء فوراً."
	}

func inspect_tank(tank_index: int) -> Dictionary:
	if tank_index < 0 or tank_index >= _specimen_tanks.size():
		return {"accepted": false}
	
	var tank: Dictionary = _specimen_tanks[tank_index]
	var id: String = tank["id"]
	if not discoveries.has(id):
		discoveries.append(id)
	
	specimen_inspected.emit(id)
	return {
		"accepted": true,
		"id": id,
		"name": tank["name"],
		"status_en": tank["status_en"],
		"status_ar": tank["status_ar"]
	}

func _open_exit_gate() -> void:
	if gate_open:
		return
	
	gate_open = true
	state = RoomState.GATE_UNLOCKED
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

func set_audio_muted(muted: bool) -> void:
	audio_muted = muted

func get_state() -> Dictionary:
	return {
		"state": state,
		"gate_open": gate_open,
		"terminal_read": terminal_read,
		"discoveries": discoveries.duplicate()
	}

func restore_state(saved: Dictionary) -> bool:
	if not saved.is_empty() and saved.has("gate_open"):
		state = saved.get("state", RoomState.ENTRY_VESTIBULE)
		gate_open = saved.get("gate_open", false)
		terminal_read = saved.get("terminal_read", false)
		discoveries = saved.get("discoveries", []).duplicate()
		
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

# ─── Architectural Construction (Anti-Crowding & Watertight Hull) ─────────────

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
	var wall_mat := _material(Color(0.25, 0.28, 0.32), 0.2, 0.6)
	wall_mat.albedo_texture = CERAMIC
	wall_mat.uv1_scale = Vector3(3.0, 2.0, 1.0)
	
	var floor_mat := _material(Color(0.16, 0.18, 0.22), 0.5, 0.6)
	floor_mat.albedo_texture = GRAPHITE
	floor_mat.uv1_scale = Vector3(4.0, 4.0, 1.0)
	
	var metal_mat := _material(Color(0.18, 0.22, 0.25), 0.7, 0.4)
	
	# Center of room: X = -15.0m, Z = -6.0m
	var center_x := -ROOM_WIDTH * 0.5
	var center_z := -6.0
	
	# 1. Watertight Floor (top at Y = 0.0)
	_box("Floor", Vector3(center_x, -WALL_THICKNESS * 0.5, center_z), Vector3(ROOM_WIDTH, WALL_THICKNESS, ROOM_LENGTH), floor_mat, true)
	
	# 2. Watertight Ceiling (bottom at Y = 7.2m)
	_box("Ceiling", Vector3(center_x, ROOM_HEIGHT + WALL_THICKNESS * 0.5, center_z), Vector3(ROOM_WIDTH, WALL_THICKNESS, ROOM_LENGTH), wall_mat, true)
	
	# 3. North Wall (Z = -18.0m)
	_box("NorthWall", Vector3(center_x, ROOM_HEIGHT * 0.5, -18.0 - WALL_THICKNESS * 0.5), Vector3(ROOM_WIDTH, ROOM_HEIGHT, WALL_THICKNESS), wall_mat, true)
	
	# 4. South Wall (Z = +6.0m) with Entry Portal for drainage from Room 4
	# Portal opening: exactly 2.6m wide (X = -3.8m to -1.2m) x 3.0m high at center X = -2.5m
	var south_z := 6.0 + WALL_THICKNESS * 0.5
	# SouthWallWest spans from X = -30.0m to -3.8m (width = 26.2m, center = -16.9m)
	_box("SouthWallWest", Vector3(-16.9, ROOM_HEIGHT * 0.5, south_z), Vector3(26.2, ROOM_HEIGHT, WALL_THICKNESS), wall_mat, true)
	# SouthWallEast spans from X = -1.2m to 0.0m (width = 1.2m, center = -0.6m)
	_box("SouthWallEast", Vector3(-0.6, ROOM_HEIGHT * 0.5, south_z), Vector3(1.2, ROOM_HEIGHT, WALL_THICKNESS), wall_mat, true)
	# SouthLintel spans above the portal from Y = 3.0m to 7.2m (height = 4.2m, center Y = 5.1m)
	_box("SouthLintel", Vector3(-2.5, 5.1, south_z), Vector3(2.6, 4.2, WALL_THICKNESS), metal_mat, true)
	
	# 5. East Wall (X = 0.0m)
	_box("EastWall", Vector3(WALL_THICKNESS * 0.5, ROOM_HEIGHT * 0.5, center_z), Vector3(WALL_THICKNESS, ROOM_HEIGHT, ROOM_LENGTH), wall_mat, true)
	
	# 6. West Wall (X = -30.0m) with Exit Blast Gate opening (2.05m wide from Z = -13.025m to -10.975m, 2.8m high)
	var west_x := -ROOM_WIDTH - WALL_THICKNESS * 0.5
	_box("WestWallNorth", Vector3(west_x, ROOM_HEIGHT * 0.5, -15.5), Vector3(WALL_THICKNESS, ROOM_HEIGHT, 5.0), wall_mat, true)
	_box("WestWallSouth", Vector3(west_x, ROOM_HEIGHT * 0.5, -2.5), Vector3(WALL_THICKNESS, ROOM_HEIGHT, 17.0), wall_mat, true)
	_box("WestExitLintel", Vector3(west_x, 5.0, -12.0), Vector3(WALL_THICKNESS, 4.4, 2.05), metal_mat, true)

func _build_specimen_tanks() -> void:
	var tank_mat := _material(Color(0.2, 0.4, 0.45, 0.6), 0.1, 0.2)
	tank_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	var fluid_mat := _material(Color(0.0, 0.8, 0.85, 0.75), 0.0, 0.3, true, Color(0.0, 0.8, 0.85), 1.8)
	var base_metal := _material(Color(0.15, 0.18, 0.22), 0.8, 0.3)
	
	var tank_configs := [
		{"x": -8.0, "z": 0.0, "id": "ex_005", "name": "Subject Alpha (EX-005)", "status_en": "Cellular Necrosis / Terminal", "status_ar": "نخر خلوي حاد / منتهية"},
		{"x": -14.0, "z": 0.0, "id": "ex_007", "name": "Subject Gamma (EX-007)", "status_en": "Neural Rejection / Failed", "status_ar": "رفض عصبي تام / فاشلة"},
		{"x": -20.0, "z": 0.0, "id": "ex_008", "name": "Subject Delta (EX-008)", "status_en": "Organ Liquefaction / Dissolved", "status_ar": "تحلل عضوي / مذاب"},
		{"x": -8.0, "z": -12.0, "id": "ex_009", "name": "Subject Epsilon (EX-009)", "status_en": "Cardiac Rupture / Deceased", "status_ar": "تمزق قلبي / متوفى"},
		{"x": -14.0, "z": -12.0, "id": "ex_010", "name": "Subject Zeta (EX-010)", "status_en": "Brainstem Death / Preserved", "status_ar": "موت جذع الدماغ / محفوظة"},
		{"x": -20.0, "z": -12.0, "id": "ex_011", "name": "Subject Echo (EX-011)", "status_en": "MISSING / ACTIVE BREACH", "status_ar": "مفقودة / اختراق نشط"}
	]
	
	for cfg in tank_configs:
		var x: float = cfg["x"]
		var z: float = cfg["z"]
		
		# Cylindrical glass tank
		var tank_body := StaticBody3D.new()
		tank_body.name = "Tank_" + cfg["id"]
		tank_body.position = Vector3(x, 2.1, z)
		
		var mesh_inst := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.1
		cyl.bottom_radius = 1.1
		cyl.height = 4.2
		mesh_inst.mesh = cyl
		mesh_inst.material_override = tank_mat
		mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		tank_body.add_child(mesh_inst)
		
		# Inner fluid cylinder
		var fluid_inst := MeshInstance3D.new()
		var fluid_cyl := CylinderMesh.new()
		fluid_cyl.top_radius = 0.95
		fluid_cyl.bottom_radius = 0.95
		fluid_cyl.height = 3.8
		fluid_inst.mesh = fluid_cyl
		fluid_inst.material_override = fluid_mat
		tank_body.add_child(fluid_inst)
		
		# Collision shape
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var cyl_shape := CylinderShape3D.new()
		cyl_shape.radius = 1.1
		cyl_shape.height = 4.2
		col.shape = cyl_shape
		tank_body.add_child(col)
		
		# Base & Cap rings
		_box("TankBase_" + cfg["id"], Vector3(x, 0.15, z), Vector3(2.5, 0.3, 2.5), base_metal, true)
		_box("TankCap_" + cfg["id"], Vector3(x, 4.35, z), Vector3(2.5, 0.3, 2.5), base_metal, true)
		
		# Internal bio-glow light
		var glow := OmniLight3D.new()
		glow.position = Vector3(x, 2.1, z)
		glow.omni_range = 4.5
		glow.light_color = Color(0.0, 0.85, 0.9) if cfg["id"] != "ex_011" else Color(1.0, 0.45, 0.1)
		glow.light_energy = 1.6
		glow.shadow_enabled = false
		add_child(glow)
		
		add_child(tank_body)
		_specimen_tanks.append(cfg)

func _build_cover_plinths() -> void:
	var metal_mat := _material(Color(0.22, 0.26, 0.3), 0.6, 0.4)
	
	# Staged heavy filter plinths along central traversal line (Z = -6.0m)
	# Providing crouching cover from the ceiling scanner
	var plinth_positions := [
		Vector3(-5.0, 0.9, -6.0),
		Vector3(-11.0, 0.9, -6.0),
		Vector3(-17.0, 0.9, -6.0),
		Vector3(-23.0, 0.9, -6.0)
	]
	
	for i in range(plinth_positions.size()):
		var pos: Vector3 = plinth_positions[i]
		var plinth := _box("CoverPlinth_%d" % i, pos, Vector3(2.2, 1.8, 1.4), metal_mat, true) as StaticBody3D
		_cover_plinths.append(plinth)

func _build_scanner_system() -> void:
	var metal_mat := _material(Color(0.2, 0.22, 0.25), 0.8, 0.3)
	var cone_mat := _material(Color(0.0, 0.9, 1.0, 0.15), 0.0, 0.1, true, Color(0.0, 0.9, 1.0), 1.2)
	cone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# Scanner mount on ceiling at center: X = -15.0m, Y = 6.8m, Z = -6.0m
	var mount := _box("ScannerMount", Vector3(-15.0, 7.0, -6.0), Vector3(1.2, 0.4, 1.2), metal_mat, true)
	
	_scanner_head = Node3D.new()
	_scanner_head.name = "ScannerHead"
	_scanner_head.position = Vector3(-15.0, 6.6, -6.0)
	
	# Scanner physical visual eye
	var eye := MeshInstance3D.new()
	var eye_box := BoxMesh.new()
	eye_box.size = Vector3(0.5, 0.4, 0.8)
	eye.mesh = eye_box
	eye.material_override = metal_mat
	_scanner_head.add_child(eye)
	
	# Visual light cone pointing along local -Z (forward/down)
	_scanner_cone = MeshInstance3D.new()
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.2
	cone_mesh.bottom_radius = 3.8
	cone_mesh.height = 8.0
	_scanner_cone.mesh = cone_mesh
	_scanner_cone.position = Vector3(0.0, 0.0, -4.0)
	_scanner_cone.rotation.x = PI * 0.5
	_scanner_cone.material_override = cone_mat
	_scanner_head.add_child(_scanner_cone)
	
	# Dynamic spot light shining down along -Z
	_scanner_beam = SpotLight3D.new()
	_scanner_beam.name = "ScannerBeam"
	_scanner_beam.position = Vector3(0.0, 0.0, 0.0)
	_scanner_beam.spot_range = 22.0
	_scanner_beam.spot_angle = 40.0
	_scanner_beam.light_color = Color(0.0, 0.9, 1.0) # Cold Cyan Search
	_scanner_beam.light_energy = 3.5
	_scanner_beam.shadow_enabled = true
	_scanner_head.add_child(_scanner_beam)
	
	# Pitch head downward 35 degrees towards the floor
	_scanner_head.rotation.x = -0.6
	
	add_child(_scanner_head)

func _build_terminal() -> void:
	var metal_mat := _material(Color(0.2, 0.24, 0.28), 0.7, 0.4)
	var screen_mat := _material(Color(0.05, 0.12, 0.15), 0.0, 0.2, true, Color(0.0, 0.85, 0.9), 1.5)
	
	_terminal_body = StaticBody3D.new()
	_terminal_body.name = "SpecimenLogTerminal"
	_terminal_body.position = Vector3(-26.0, 0.6, -12.0)
	
	var base_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.2, 1.2, 0.8)
	base_mesh.mesh = box
	base_mesh.material_override = metal_mat
	_terminal_body.add_child(base_mesh)
	
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.2, 1.2, 0.8)
	col.shape = shape
	_terminal_body.add_child(col)
	
	# Terminal Screen
	var screen := MeshInstance3D.new()
	var s_mesh := BoxMesh.new()
	s_mesh.size = Vector3(0.8, 0.5, 0.04)
	screen.mesh = s_mesh
	screen.position = Vector3(0.0, 0.7, 0.35)
	screen.rotation.x = -0.35
	screen.material_override = screen_mat
	_terminal_body.add_child(screen)
	
	_terminal_light = OmniLight3D.new()
	_terminal_light.position = Vector3(-26.0, 1.5, -11.5)
	_terminal_light.omni_range = 3.0
	_terminal_light.light_color = Color(0.0, 0.85, 0.9)
	_terminal_light.light_energy = 1.2
	_terminal_light.shadow_enabled = false
	add_child(_terminal_light)
	
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
	_terminal_body.add_child(area)
	
	area.body_entered.connect(func(body: Node3D):
		if body.has_method("register_nearby_interactable"):
			body.register_nearby_interactable(self)
	)
	area.body_exited.connect(func(body: Node3D):
		if body.has_method("unregister_nearby_interactable"):
			body.unregister_nearby_interactable(self)
	)
	
	add_child(_terminal_body)

func trigger_interaction(_interactor: Node = null) -> Dictionary:
	return request_terminal_access()

func _build_exit_gate() -> void:
	var metal_mat := _material(Color(0.18, 0.22, 0.25), 0.75, 0.35)
	
	# Gate frame on West Wall at Z = -12.0m (2.05m doorway opening)
	_box("ExitGateFrameTop", Vector3(-ROOM_WIDTH, 3.2, -12.0), Vector3(0.5, 0.4, 2.25), metal_mat, true)
	
	_gate = StaticBody3D.new()
	_gate.name = "ExitBlastGate"
	_gate.position = Vector3(-ROOM_WIDTH, _gate_closed_y, -12.0)
	
	var gate_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.25, 2.8, 2.05)
	gate_mesh.mesh = box
	gate_mesh.material_override = metal_mat
	gate_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_gate.add_child(gate_mesh)
	
	_gate_shape = CollisionShape3D.new()
	_gate_shape.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.25, 2.8, 2.05)
	_gate_shape.shape = shape
	_gate_shape.disabled = false # Starts locked
	_gate.add_child(_gate_shape)
	
	add_child(_gate)
