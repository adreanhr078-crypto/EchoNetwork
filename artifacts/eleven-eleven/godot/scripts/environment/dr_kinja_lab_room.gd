extends Node3D

## Room 10/11: Dr. Kinja's Observation Lab & Zero Contract Chamber
## Connects from Buffer 9-10 (Surveillance-to-Lab Conduit) South Entrance at Z = 0.0m
## to Dimensional Breach North Exit at Z = -40.0m.
## Enforces the Anti-Crowding and Quality Gate Invariants:
## - Watertight Hull (32.0m x 40.0m x 10.0m), solid collision envelope, zero light bleed.
## - Narrative & Gameplay Flow:
##   * Central Surgical Neural Rig Theater at Z = -20.0m, Y = 1.2m with cold overhead spotlight (#E0FAFF).
##   * Kinja confrontation and Memory Drowning protocol (Yuki & Shizuka stasis pods).
##   * Manifestation of Zero in the Void Altar at Z = -32.0m (#D90429 Crimson / #7209B7 Purple).
##   * Accepting Zero's shadow contract (trigger_interaction on Zero Contract Altar).
##   * Explosive stasis freeze event at 11:11 locking all displays in purple and opening the breach.
## - 3-Tier Safe Anchors (Entry, Theater, Contract).
## - Full accessibility: reduced motion, audio mute, durable state save/restore.

signal memory_confrontation_started
signal memory_drowning_completed
signal zero_manifested
signal zero_contract_accepted
signal stasis_1111_activated
signal exit_breach_opened
signal contract_decision_requested
signal revenge_completed
signal wish_decision_requested
signal retry_requested(anchor: Vector3)

enum RoomState {
	ENTRY_SURGICAL,
	THEATER_CONFRONTATION,
	MEMORY_DROWNING,
	ZERO_MANIFESTED,
	CONTRACT_ACCEPTED,
	STASIS_1111,
	BREACH_READY
}

const CERAMIC = preload("res://assets/environments/maintenance_jutsu_v1_Maintenance ceramic grain 512.png")
const GRAPHITE = preload("res://assets/environments/maintenance_jutsu_v1_Maintenance brushed graphite 512.png")
const SIGNAL_CONSOLE_PROP = preload("res://assets/props/signal_console_jutsu.glb")

const ROOM_WIDTH := 32.0 # X: -16.0m to +16.0m (center = 0.0m)
const ROOM_LENGTH := 40.0 # Z: 0.0m to -40.0m (center = -20.0m)
const ROOM_HEIGHT := 10.0 # Y: 0.0m to +10.0m
const WALL_THICKNESS := 0.5

const SAFE_ANCHOR_ENTRY := Vector3(0.0, 0.1, -2.0)
const SAFE_ANCHOR_THEATER := Vector3(0.0, 1.3, -20.0)
const SAFE_ANCHOR_CONTRACT := Vector3(0.0, 0.1, -32.0)

var state: RoomState = RoomState.ENTRY_SURGICAL
var current_anchor: Vector3 = SAFE_ANCHOR_ENTRY
var reduced_motion := false
var audio_muted := false
var presentation_language := "ar"
var player: Node3D

var confrontation_done := false
var contract_done := false
var breach_open := false
var revenge_done := false
var wish_done := false
var campaign_decisions := false

var _breach_portal: StaticBody3D
var _breach_shape: CollisionShape3D
var _breach_material: StandardMaterial3D
var _breach_closed_y := 1.4
var _breach_open_y := 5.2

var _surgical_light: SpotLight3D
var _zero_light: OmniLight3D
var _stasis_light: OmniLight3D

var _neural_terminal: StaticBody3D
var _contract_altar: StaticBody3D

var _yuki_pod: MeshInstance3D
var _shizuka_pod: MeshInstance3D
var story_presentation: Node3D

func _ready() -> void:
	preload("res://scripts/environment/room_service_lighting.gd").install(self,Rect2(-16,-40,32,40),10.0)
	_build_room_hull()
	_build_surgical_theater()
	_build_memory_drowning_pool()
	_build_zero_contract_altar()
	_build_stasis_displays()
	_build_exit_breach()
	var ramp_mat := _material(Color(0.35,0.38,0.43),0.2,0.8)
	preload("res://scripts/environment/room_path_support.gd").add_ramp(self,"TheaterApproach",Vector3(0,0,-9),Vector3(0,1.2,-13.8),3.2,ramp_mat)
	story_presentation=preload("res://scripts/cinematics/pact_revenge_presentation.gd").new()
	story_presentation.name="PactRevengePresentation"
	add_child(story_presentation)
	set_presentation_language(presentation_language)

func set_presentation_language(language: String) -> void:
	presentation_language="ar" if language=="ar" else "en"
	if is_instance_valid(_contract_altar) and _contract_altar.has_method("set_presentation_language"):
		_contract_altar.set_presentation_language(presentation_language)

func _physics_process(_delta: float) -> void:
	if not player or not is_instance_valid(player):
		return
	
	var pz: float = to_local(player.global_position).z
	var py: float = to_local(player.global_position).y
	
	# Monotonic safe anchor progression
	if pz < -34.0 and breach_open:
		current_anchor = SAFE_ANCHOR_CONTRACT
	elif pz < -28.0 and confrontation_done:
		current_anchor = SAFE_ANCHOR_CONTRACT
	elif pz < -16.0 and py > 1.0:
		if current_anchor != SAFE_ANCHOR_CONTRACT:
			current_anchor = SAFE_ANCHOR_THEATER
	elif current_anchor == SAFE_ANCHOR_ENTRY and pz < -6.0:
		state = RoomState.THEATER_CONFRONTATION

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
	var wall_mat := _material(Color(0.55, 0.59, 0.67), 0.15, 0.76)
	wall_mat.albedo_texture = CERAMIC
	wall_mat.uv1_scale = Vector3(4.0, 4.0, 1.0)
	
	var floor_mat := _material(Color(0.51, 0.56, 0.65), 0.17, 0.68)
	floor_mat.albedo_texture = GRAPHITE
	floor_mat.uv1_scale = Vector3(5.0, 5.0, 1.0)
	
	var center_z := -ROOM_LENGTH * 0.5 # -20.0m
	var center_y := ROOM_HEIGHT * 0.5 # 5.0m
	
	# 1. Floor (solid) at Y = 0.0m
	_box("Floor", Vector3(0.0, -WALL_THICKNESS * 0.5, center_z), Vector3(ROOM_WIDTH, WALL_THICKNESS, ROOM_LENGTH), floor_mat, true)
	
	# 2. Ceiling (solid) at Y = 10.0m
	_box("Ceiling", Vector3(0.0, ROOM_HEIGHT + WALL_THICKNESS * 0.5, center_z), Vector3(ROOM_WIDTH, WALL_THICKNESS, ROOM_LENGTH), wall_mat, true)
	
	# 3. West Wall (solid) at X = -16.0m
	_box("WestWall", Vector3(-ROOM_WIDTH * 0.5 - WALL_THICKNESS * 0.5, center_y, center_z), Vector3(WALL_THICKNESS, ROOM_HEIGHT, ROOM_LENGTH), wall_mat, true)
	
	# 4. East Wall (solid) at X = +16.0m
	_box("EastWall", Vector3(ROOM_WIDTH * 0.5 + WALL_THICKNESS * 0.5, center_y, center_z), Vector3(WALL_THICKNESS, ROOM_HEIGHT, ROOM_LENGTH), wall_mat, true)
	
	# 5. South Wall (solid) at Z = 0.0m with Entrance Portal (Width 2.6m x Height 3.2m)
	var south_z := WALL_THICKNESS * 0.5
	# SouthWest: from X = -16.0m to -1.3m (width = 14.7m, center X = -8.65m)
	_box("SouthWallWest", Vector3(-8.65, center_y, south_z), Vector3(14.7, ROOM_HEIGHT, WALL_THICKNESS), wall_mat, true)
	# SouthEast: from X = +1.3m to +16.0m (width = 14.7m, center X = +8.65m)
	_box("SouthWallEast", Vector3(8.65, center_y, south_z), Vector3(14.7, ROOM_HEIGHT, WALL_THICKNESS), wall_mat, true)
	# SouthLintel: above portal from Y = 3.2m to 10.0m (height = 6.8m, center Y = 6.6m, width = 2.6m)
	_box("SouthLintel", Vector3(0.0, 6.6, south_z), Vector3(2.6, 6.8, WALL_THICKNESS), wall_mat, true)
	
	# 6. North Wall (solid) at Z = -40.0m with Dimensional Glitch Breach (Width 2.05m x Height 2.8m)
	var north_z := -ROOM_LENGTH - WALL_THICKNESS * 0.5
	# NorthWest: from X = -16.0m to -1.025m (width = 14.975m, center X = -8.5125m)
	_box("NorthWallWest", Vector3(-8.5125, center_y, north_z), Vector3(14.975, ROOM_HEIGHT, WALL_THICKNESS), wall_mat, true)
	# NorthEast: from X = +1.025m to +16.0m (width = 14.975m, center X = +8.5125m)
	_box("NorthWallEast", Vector3(8.5125, center_y, north_z), Vector3(14.975, ROOM_HEIGHT, WALL_THICKNESS), wall_mat, true)
	# NorthLintel: above exit from Y = 2.8m to 10.0m (height = 7.2m, center Y = 6.4m, width = 2.05m)
	_box("NorthLintel", Vector3(0.0, 6.4, north_z), Vector3(2.05, 7.2, WALL_THICKNESS), wall_mat, true)

func _build_surgical_theater() -> void:
	var metal_mat := _material(Color(0.2, 0.23, 0.28), 0.8, 0.3)
	var chrome_mat := _material(Color(0.4, 0.45, 0.5), 0.95, 0.15)
	
	# Central Elevated Surgical Dais: centered at X = 0.0m, Z = -20.0m, Y = 1.2m (12.0m x 12.0m)
	_box("SurgicalDaisPlatform", Vector3(0.0, 0.6, -20.0), Vector3(12.0, 1.2, 12.0), metal_mat, true)
	
	# Neural Rig Examination Table at center
	_box("NeuralRigTable", Vector3(0.0, 1.45, -20.0), Vector3(1.4, 0.5, 2.6), chrome_mat, true)
	
	# Overhead Surgical Spotlight (Ice Blue #E0FAFF, Spot Angle 28°)
	_surgical_light = SpotLight3D.new()
	_surgical_light.name = "SurgicalSpotlight"
	_surgical_light.position = Vector3(0.0, 9.2, -20.0)
	_surgical_light.rotation.x = -PI * 0.5
	_surgical_light.spot_angle = 28.0
	_surgical_light.spot_range = 14.0
	_surgical_light.light_color = Color(0.88, 0.98, 1.0) # Ice Blue
	_surgical_light.light_energy = 4.0
	_surgical_light.shadow_enabled = true
	add_child(_surgical_light)
	
	# Kinja Neural Rig Terminal (Terminal on Dais)
	var term_script = preload("res://scripts/environment/kinja_rig_terminal.gd")
	_neural_terminal = term_script.new()
	_neural_terminal.name = "KinjaNeuralRigTerminal"
	_neural_terminal.position = Vector3(2.5, 1.2, -20.0)
	
	var prop := SIGNAL_CONSOLE_PROP.instantiate()
	prop.name = "Prop"
	_neural_terminal.add_child(prop)
	
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 1.4, 0.9)
	col.shape = box
	_neural_terminal.add_child(col)
	
	var area := Area3D.new()
	area.name = "InteractionArea"
	var area_col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.4
	area_col.shape = sphere
	area.add_child(area_col)
	
	area.body_entered.connect(func(body: Node3D):
		if body.has_method("register_nearby_interactable"):
			body.register_nearby_interactable(_neural_terminal)
	)
	area.body_exited.connect(func(body: Node3D):
		if body.has_method("unregister_nearby_interactable"):
			body.unregister_nearby_interactable(_neural_terminal)
	)
	_neural_terminal.add_child(area)
	add_child(_neural_terminal)

func _build_memory_drowning_pool() -> void:
	var pool_mat := _material(Color(0.02, 0.02, 0.03), 0.1, 0.1, true, Color(0.1, 0.05, 0.2), 0.8)
	var pod_mat := _material(Color(0.2, 0.4, 0.6, 0.5), 0.2, 0.1, true, Color(0.0, 0.7, 0.9), 1.4)
	pod_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# Inky liquid pool floor surrounding the dais (Y = 0.05m)
	_box("DrowningPoolFloor", Vector3(0.0, 0.02, -20.0), Vector3(24.0, 0.04, 20.0), pool_mat, false)
	
	# Floating Memory Pod: Shizuka (West side at X = -7.0m, Z = -20.0m)
	_shizuka_pod = MeshInstance3D.new()
	var s_cyl := CylinderMesh.new()
	s_cyl.top_radius = 0.8
	s_cyl.bottom_radius = 0.8
	s_cyl.height = 2.6
	_shizuka_pod.mesh = s_cyl
	_shizuka_pod.position = Vector3(-7.0, 1.3, -20.0)
	_shizuka_pod.material_override = pod_mat
	add_child(_shizuka_pod)
	
	# Floating Memory Pod: Yuki (East side at X = +7.0m, Z = -20.0m)
	_yuki_pod = MeshInstance3D.new()
	_yuki_pod.mesh = s_cyl
	_yuki_pod.position = Vector3(7.0, 1.3, -20.0)
	_yuki_pod.material_override = pod_mat
	add_child(_yuki_pod)

func _build_zero_contract_altar() -> void:
	var altar_mat := _material(Color(0.075, 0.06, 0.10), 0.6, 0.3)
	
	var altar_script = preload("res://scripts/environment/zero_contract_altar.gd")
	_contract_altar = altar_script.new()
	_contract_altar.name = "ZeroContractAltar"
	_contract_altar.position = Vector3(0.0, 0.0, -32.0)
	
	# Altar plinth mesh
	var plinth := MeshInstance3D.new()
	var p_mesh := CylinderMesh.new()
	p_mesh.top_radius=1.05
	p_mesh.bottom_radius=1.18
	p_mesh.height=1.2
	p_mesh.radial_segments=12
	plinth.mesh = p_mesh
	plinth.position = Vector3(0.0, 0.6, 0.0)
	plinth.material_override = altar_mat
	_contract_altar.add_child(plinth)
	
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 1.2, 2.4)
	col.shape = box
	col.position = Vector3(0.0, 0.6, 0.0)
	_contract_altar.add_child(col)
	
	# Interaction Area3D
	var area := Area3D.new()
	area.name = "InteractionArea"
	var area_col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.8
	area_col.shape = sphere
	area.add_child(area_col)
	
	area.body_entered.connect(func(body: Node3D):
		if body.has_method("register_nearby_interactable"):
			body.register_nearby_interactable(_contract_altar)
	)
	area.body_exited.connect(func(body: Node3D):
		if body.has_method("unregister_nearby_interactable"):
			body.unregister_nearby_interactable(_contract_altar)
	)
	_contract_altar.add_child(area)
	
	# Zero's dual-tone atmospheric lighting (Crimson / Deep Purple)
	_zero_light = OmniLight3D.new()
	_zero_light.name = "ZeroAuraLight"
	_zero_light.position = Vector3(0.0, 2.8, -32.0)
	_zero_light.light_color = Color(0.7, 0.05, 0.8) # Deep Violet
	_zero_light.light_energy = 2.5
	_zero_light.omni_range = 10.0
	_zero_light.shadow_enabled = true
	add_child(_zero_light)
	
	add_child(_contract_altar)

func _build_stasis_displays() -> void:
	# North Wall 11:11 Stasis Clock Displays
	var screen_mat := _material(Color(0.025, 0.028, 0.045), 0.3, 0.4)
	
	var stasis_screen := MeshInstance3D.new()
	var s_mesh := BoxMesh.new()
	s_mesh.size = Vector3(10.0, 2.4, 0.1)
	stasis_screen.mesh = s_mesh
	stasis_screen.position = Vector3(0.0, 5.0, -39.7)
	stasis_screen.material_override = screen_mat
	add_child(stasis_screen)
	var digits:=Label3D.new()
	digits.name="StasisClock1111"
	digits.text="11:11"
	digits.font_size=100
	digits.pixel_size=0.018
	digits.position=Vector3(0,5.0,-39.61)
	digits.modulate=Color(0.73,0.58,0.94)
	digits.outline_size=0
	digits.no_depth_test=false
	add_child(digits)
	
	_stasis_light = OmniLight3D.new()
	_stasis_light.name = "Stasis1111Light"
	_stasis_light.position = Vector3(0.0, 5.0, -38.5)
	_stasis_light.light_color = Color(0.65, 0.1, 0.9)
	_stasis_light.light_energy = 1.0
	_stasis_light.omni_range = 14.0
	add_child(_stasis_light)

func _build_exit_breach() -> void:
	_breach_material = _material(Color(0.06, 0.075, 0.10), 0.35, 0.5)
	
	_breach_portal = StaticBody3D.new()
	_breach_portal.name = "DimensionalBreachPortal"
	_breach_portal.position = Vector3(0.0, _breach_closed_y, -40.0)
	
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = Vector3(2.05, 2.8, 0.2)
	mesh.material_override = _breach_material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_breach_portal.add_child(mesh)
	
	_breach_shape = CollisionShape3D.new()
	_breach_shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(2.05, 2.8, 0.2)
	_breach_shape.shape = box
	_breach_portal.add_child(_breach_shape)
	
	add_child(_breach_portal)

func initiate_memory_confrontation() -> Dictionary:
	if confrontation_done:
		return {"success": true, "already_confronted": true}
	
	confrontation_done = true
	state = RoomState.MEMORY_DROWNING
	memory_confrontation_started.emit()
	
	# Lower memory pods into liquid drowning pool
	if reduced_motion:
		if _shizuka_pod:
			_shizuka_pod.position.y = -0.5
		if _yuki_pod:
			_yuki_pod.position.y = -0.5
		_on_drowning_complete()
	else:
		var tween := create_tween()
		if _shizuka_pod:
			tween.parallel().tween_property(_shizuka_pod, "position:y", -0.5, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		if _yuki_pod:
			tween.parallel().tween_property(_yuki_pod, "position:y", -0.5, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_callback(_on_drowning_complete)
	
	return {"success": true, "confrontation_started": true}

func _on_drowning_complete() -> void:
	state = RoomState.ZERO_MANIFESTED
	set_presentation_language(presentation_language)
	if story_presentation: story_presentation.set_stage("manifested")
	memory_drowning_completed.emit()
	zero_manifested.emit()
	if _zero_light:
		_zero_light.light_energy = 1.4

func accept_zero_contract() -> Dictionary:
	if contract_done:
		return {"success": true, "already_contracted": true}
	if not confrontation_done or state != RoomState.ZERO_MANIFESTED:
		return {"success": false, "reason": "zero_not_manifested"}
	
	contract_done = true
	state = RoomState.CONTRACT_ACCEPTED
	if story_presentation: story_presentation.set_stage("accepted")
	zero_contract_accepted.emit()
	
	return {"success": true, "contract_accepted": true, "power_granted": "shadow_surge"}

func request_contract_decision() -> Dictionary:
	if not confrontation_done or state != RoomState.ZERO_MANIFESTED:
		return {"success":false,"reason":"zero_not_manifested"}
	if not campaign_decisions: return {"success":false,"reason":"explicit_decision_required"}
	contract_decision_requested.emit()
	return {"success":true,"decision_requested":true}

func complete_revenge() -> bool:
	if not contract_done or revenge_done: return false
	revenge_done=true
	if story_presentation: story_presentation.set_stage("revenge")
	revenge_completed.emit()
	wish_decision_requested.emit()
	return true

func confirm_escape_wish(choice: String) -> bool:
	if not contract_done or not revenge_done or wish_done or choice != "ESCAPE_SYSTEM_AT_ANY_COST": return false
	wish_done=true
	_trigger_1111_stasis()
	return true

func _trigger_1111_stasis() -> void:
	state = RoomState.STASIS_1111
	if story_presentation: story_presentation.set_stage("stasis")
	stasis_1111_activated.emit()
	
	if _stasis_light:
		_stasis_light.light_energy = 5.0
	
	_open_exit_breach()

func _open_exit_breach() -> void:
	if breach_open:
		return
	breach_open = true
	_breach_material.emission_enabled=true
	_breach_material.emission=Color(0.45,0.58,0.74)
	_breach_material.emission_energy_multiplier=1.2
	state = RoomState.BREACH_READY
	exit_breach_opened.emit()
	
	if reduced_motion:
		if _breach_portal:
			_breach_portal.position.y = _breach_open_y
		if _breach_shape:
			_breach_shape.set_deferred("disabled", true)
		return
	
	if _breach_portal:
		var tween := create_tween()
		tween.tween_property(_breach_portal, "position:y", _breach_open_y, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func():
			if _breach_shape:
				_breach_shape.set_deferred("disabled", true)
		)

func get_safe_anchor() -> Vector3:
	return current_anchor

func get_state() -> Dictionary:
	return {
		"state": state,
		"current_anchor": current_anchor,
		"confrontation_done": confrontation_done,
		"contract_done": contract_done,
		"revenge_done": revenge_done,
		"wish_done": wish_done,
		"breach_open": breach_open,
		"breach_pos_y": _breach_portal.position.y if _breach_portal else _breach_closed_y,
		"breach_col_disabled": _breach_shape.disabled if _breach_shape else false
	}

func restore_state(data: Dictionary) -> void:
	if data.has("state"):
		state = data["state"]
	if data.has("current_anchor"):
		current_anchor = data["current_anchor"]
	if data.has("confrontation_done"):
		confrontation_done = data["confrontation_done"]
	if data.has("contract_done"):
		contract_done = data["contract_done"]
	if data.has("breach_open"):
		breach_open = data["breach_open"] and contract_done and data.get("revenge_done",false) and data.get("wish_done",false)
	revenge_done=data.get("revenge_done",false) and contract_done
	wish_done=data.get("wish_done",false) and revenge_done
	if _breach_portal and data.has("breach_pos_y"):
		_breach_portal.position.y = data["breach_pos_y"]
	if _breach_shape and data.has("breach_col_disabled"):
		_breach_shape.disabled = data["breach_col_disabled"]
	if story_presentation:
		var restored_stage := "stasis" if wish_done else ("revenge" if revenge_done else ("accepted" if contract_done else ("manifested" if confrontation_done else "dormant")))
		story_presentation.set_stage(restored_stage,true)
	if _breach_material:
		_breach_material.emission_enabled=breach_open
		_breach_material.emission=Color(0.45,0.58,0.74)
		_breach_material.emission_energy_multiplier=1.2
	set_presentation_language(presentation_language)
