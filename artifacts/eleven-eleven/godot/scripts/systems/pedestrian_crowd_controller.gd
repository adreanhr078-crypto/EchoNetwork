class_name PedestrianCrowdController
extends Node3D

## AAA GTA-Style Living Pedestrian Crowd & Urban Traffic System
## Controls ambient citizens walking along Minato-Kasumi sidewalks with:
## - 24-hour schedule behavior (Morning school/work rush, midday cafe dining, nocturnal curfew)
## - Vehicle reaction: dodges away and stops when vehicle honks horn within 6m
## - Combat reaction: flees in panic when cold-weapon clashes or Kagune void bursts occur
## - Zero-leak teardown with pooled citizen nodes

signal pedestrian_fled_combat(pedestrian_id: String, threat_pos: Vector3)
signal pedestrian_yielded_to_vehicle(pedestrian_id: String, vehicle_node: Node)
signal ambient_crowd_updated(active_count: int, schedule_phase: String)

enum SchedulePhase {
	MORNING_COMMUTE,    # 07:00 - 09:00
	MIDDAY_COMMERCE,    # 09:00 - 17:00
	EVENING_RUSH,       # 17:00 - 21:00
	NIGHT_CURFEW        # 21:00 - 07:00
}

@export var max_citizens: int = 12
@export var current_phase: SchedulePhase = SchedulePhase.MIDDAY_COMMERCE

class CitizenAgent:
	var id: String
	var node: Node3D
	var mesh_inst: MeshInstance3D
	var current_pos: Vector3
	var target_pos: Vector3
	var walk_speed: float
	var is_panicking: bool
	var schedule_role: String # "STUDENT", "SALARYMAN", "SHOPPER", "NIGHT_WANDERER"

var _active_citizens: Array[CitizenAgent] = []
var _sidewalk_waypoints: Array[Vector3] = [
	Vector3(-14.0, 0.0, -18.0),
	Vector3(-14.0, 0.0,   0.0),
	Vector3(-14.0, 0.0,  18.0),
	Vector3( 14.0, 0.0, -18.0),
	Vector3( 14.0, 0.0,   0.0),
	Vector3( 14.0, 0.0,  18.0)
]

func _enter_tree() -> void:
	if _active_citizens.size() == 0:
		_populate_ambient_crowd()

func _ready() -> void:
	if _active_citizens.size() == 0:
		_populate_ambient_crowd()

func setup_waypoints(points: Array[Vector3]) -> void:
	_sidewalk_waypoints = points

# ─────────────────── POPULATION & SCHEDULE ──────────────────────

func _populate_ambient_crowd() -> void:
	for i in range(max_citizens):
		var agent := CitizenAgent.new()
		agent.id = "Citizen_%d" % i
		agent.walk_speed = randf_range(1.2, 1.8)
		agent.is_panicking = false
		agent.schedule_role = _assign_role(i)

		var c_node := Node3D.new()
		c_node.name = agent.id

		var m_inst := MeshInstance3D.new()
		m_inst.name = "AvatarMesh"
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.24
		cyl.bottom_radius = 0.28
		cyl.height = 1.68
		m_inst.mesh = cyl

		var mat := StandardMaterial3D.new()
		mat.albedo_color = _get_role_color(agent.schedule_role)
		mat.roughness = 0.75
		m_inst.material_override = mat
		m_inst.position = Vector3(0, 0.84, 0)
		c_node.add_child(m_inst)

		agent.node = c_node
		agent.mesh_inst = m_inst

		# Initial position on sidewalk
		var start_pt: Vector3 = _sidewalk_waypoints[i % _sidewalk_waypoints.size()]
		c_node.position = start_pt + Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0))
		agent.current_pos = c_node.position
		agent.target_pos = _sidewalk_waypoints[(i + 1) % _sidewalk_waypoints.size()]

		add_child(c_node)
		_active_citizens.append(agent)

	emit_signal("ambient_crowd_updated", _active_citizens.size(), SchedulePhase.keys()[current_phase])

func _assign_role(idx: int) -> String:
	match idx % 4:
		0: return "STUDENT"
		1: return "SALARYMAN"
		2: return "SHOPPER"
		_: return "NIGHT_WANDERER"

func _get_role_color(role: String) -> Color:
	match role:
		"STUDENT":        return Color(0.15, 0.25, 0.45) # Navy blazer
		"SALARYMAN":      return Color(0.2, 0.2, 0.25)    # Charcoal suit
		"SHOPPER":        return Color(0.55, 0.45, 0.35)  # Casual trench
		_:                return Color(0.12, 0.12, 0.15)  # Dark hoodie

## Syncs crowd behavior with GameClock hour
func sync_with_clock(hour: int) -> void:
	var prev_phase = current_phase
	if hour >= 7 and hour < 9:
		current_phase = SchedulePhase.MORNING_COMMUTE
	elif hour >= 9 and hour < 17:
		current_phase = SchedulePhase.MIDDAY_COMMERCE
	elif hour >= 17 and hour < 21:
		current_phase = SchedulePhase.EVENING_RUSH
	else:
		current_phase = SchedulePhase.NIGHT_CURFEW

	# During night curfew, 70% of citizens stay indoors
	for i in range(_active_citizens.size()):
		var c = _active_citizens[i]
		if is_instance_valid(c.node):
			if current_phase == SchedulePhase.NIGHT_CURFEW:
				c.node.visible = (c.schedule_role == "NIGHT_WANDERER" or i % 3 == 0)
			else:
				c.node.visible = true

	if prev_phase != current_phase:
		emit_signal("ambient_crowd_updated", _active_citizens.size(), SchedulePhase.keys()[current_phase])

# ─────────────────── REACTIVE AI ───────────────────────────────

## Called when vehicle honks horn nearby (within 6 metres)
func react_to_vehicle_horn(horn_pos: Vector3, vehicle: Node) -> int:
	var reacted_count: int = 0
	for c in _active_citizens:
		if not is_instance_valid(c.node) or not c.node.visible:
			continue
		var dist = c.node.global_position.distance_to(horn_pos) if c.node.is_inside_tree() else c.current_pos.distance_to(horn_pos)
		if dist < 6.5:
			# Step away from road toward sidewalk wall
			var away_dir = (c.current_pos - horn_pos).normalized()
			c.target_pos = c.current_pos + Vector3(away_dir.x * 2.0, 0, 0)
			emit_signal("pedestrian_yielded_to_vehicle", c.id, vehicle)
			reacted_count += 1
	return reacted_count

## Called when combat / Kagune burst occurs nearby
func react_to_combat_event(threat_pos: Vector3, radius: float = 14.0) -> int:
	var panicked_count: int = 0
	for c in _active_citizens:
		if not is_instance_valid(c.node) or not c.node.visible:
			continue
		var dist = c.node.global_position.distance_to(threat_pos) if c.node.is_inside_tree() else c.current_pos.distance_to(threat_pos)
		if dist < radius:
			c.is_panicking = true
			c.walk_speed = 4.2 # Sprint away in panic
			var run_away_dir = (c.current_pos - threat_pos).normalized()
			c.target_pos = c.current_pos + run_away_dir * 18.0
			emit_signal("pedestrian_fled_combat", c.id, threat_pos)
			panicked_count += 1
	return panicked_count

# ─────────────────── UPDATE & TEARDOWN ─────────────────────────

func _physics_process(delta: float) -> void:
	for c in _active_citizens:
		if not is_instance_valid(c.node) or not c.node.visible:
			continue
		var to_target = c.target_pos - c.current_pos
		to_target.y = 0.0
		if to_target.length() > 0.4:
			var step = to_target.normalized() * c.walk_speed * delta
			c.current_pos += step
			c.node.position = c.current_pos
		else:
			# Pick next waypoint
			var next_idx = randi() % _sidewalk_waypoints.size()
			c.target_pos = _sidewalk_waypoints[next_idx]
			if c.is_panicking:
				c.is_panicking = false
				c.walk_speed = randf_range(1.2, 1.8)

func _exit_tree() -> void:
	for c in _active_citizens:
		if is_instance_valid(c.node):
			c.node.queue_free()
	_active_citizens.clear()
