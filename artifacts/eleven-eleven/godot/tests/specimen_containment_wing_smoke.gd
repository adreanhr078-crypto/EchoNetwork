extends SceneTree

const SPECIMEN_SCENE = preload("res://scenes/environment/specimen_containment_wing.tscn")
const PLAYER_SCENE = preload("res://scenes/player/echo_player.tscn")

var wing: Node3D
var player: EchoPlayer

var tank_inspected_fired := false
var terminal_accessed_fired := false
var gate_opened_fired := false
var retry_requested_fired := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("--- Starting Room 5 Specimen Containment Wing Smoke Test ---")
	
	# 1. Instantiate Room 5 Scene
	wing = SPECIMEN_SCENE.instantiate()
	if not _check(wing != null, "Failed to instantiate specimen_containment_wing.tscn"):
		return
	root.add_child(wing)
	
	for i in range(4):
		await process_frame
	
	# 2. Structural & Architectural Audit (Anti-Crowding Invariant)
	var floor_body := wing.get_node_or_null("Floor") as StaticBody3D
	var ceiling_body := wing.get_node_or_null("Ceiling") as StaticBody3D
	var north_wall := wing.get_node_or_null("NorthWall") as StaticBody3D
	var east_wall := wing.get_node_or_null("EastWall") as StaticBody3D
	var south_west := wing.get_node_or_null("SouthWallWest") as StaticBody3D
	var south_east := wing.get_node_or_null("SouthWallEast") as StaticBody3D
	var south_lintel := wing.get_node_or_null("SouthLintel") as StaticBody3D
	var gate_body := wing.get_node_or_null("ExitBlastGate") as StaticBody3D
	var terminal_body := wing.get_node_or_null("SpecimenLogTerminal") as StaticBody3D
	
	if not _check(floor_body and ceiling_body and north_wall and east_wall, "Missing hermetic hull envelope components"):
		return
	if not _check(south_west and south_east and south_lintel, "Missing south wall components"):
		return
	if not _check(gate_body != null, "Missing ExitBlastGate"):
		return
	if not _check(terminal_body != null, "Missing SpecimenLogTerminal"):
		return
	
	# Verify South Wall hermetic watertight envelope (zero gap)
	var sw_shape: BoxShape3D = south_west.get_node("CollisionShape3D").shape as BoxShape3D
	var se_shape: BoxShape3D = south_east.get_node("CollisionShape3D").shape as BoxShape3D
	var sl_shape: BoxShape3D = south_lintel.get_node("CollisionShape3D").shape as BoxShape3D
	if not _check(is_equal_approx(sw_shape.size.x, 26.2), "SouthWallWest must span 26.2m to seal from X=-30.0 to -3.8"):
		return
	if not _check(is_equal_approx(se_shape.size.x, 1.2), "SouthWallEast must span 1.2m to seal from X=-1.2 to 0.0"):
		return
	if not _check(is_equal_approx(sl_shape.size.x, 2.6), "SouthLintel must span 2.6m to cover portal from X=-3.8 to -1.2"):
		return
	
	# Verify floor dimensions (30m wide x 24m long)
	var floor_col: CollisionShape3D = floor_body.get_node("CollisionShape3D")
	var floor_box: BoxShape3D = floor_col.shape as BoxShape3D
	if not _check(is_equal_approx(floor_box.size.x, 30.0), "Room width must be 30.0m"):
		return
	if not _check(is_equal_approx(floor_box.size.z, 24.0), "Room length must be 24.0m"):
		return
	
	# Verify Gate starts closed and locked with watertight width (>= 2.0m)
	var gate_shape: CollisionShape3D = gate_body.get_node("CollisionShape3D")
	var gate_box: BoxShape3D = gate_shape.shape as BoxShape3D
	if not _check(gate_shape.disabled == false, "Exit gate must start closed and collidable"):
		return
	if not _check(gate_box.size.z >= 2.0, "Exit gate must span at least 2.0m to prevent light bleed"):
		return
	
	# 3. Verify Specimen Tanks (EX-005 to EX-011)
	var expected_tanks := ["ex_005", "ex_007", "ex_008", "ex_009", "ex_010", "ex_011"]
	for tid in expected_tanks:
		var tank := wing.get_node_or_null("Tank_" + tid) as StaticBody3D
		if not _check(tank != null, "Missing specimen tank for " + tid):
			return
		var tank_col: CollisionShape3D = tank.get_node_or_null("CollisionShape3D")
		if not _check(tank_col != null and tank_col.shape is CylinderShape3D, "Tank " + tid + " missing cylinder collision shape"):
			return
	
	# Connect signals
	wing.specimen_inspected.connect(func(id: String): tank_inspected_fired = true)
	wing.terminal_accessed.connect(func(log_id: String): terminal_accessed_fired = true)
	wing.exit_gate_opened.connect(func(): gate_opened_fired = true)
	wing.retry_requested.connect(func(anchor: Vector3): retry_requested_fired = true)
	
	# Test Tank Inspection API
	var tank_res: Dictionary = wing.inspect_tank(5) # EX-011
	if not _check(tank_res.get("accepted", false), "Failed to inspect EX-011 tank"):
		return
	if not _check(tank_res.get("id", "") == "ex_011", "Tank ID mismatch"):
		return
	if not _check(tank_inspected_fired, "specimen_inspected signal did not fire"):
		return
	
	# 4. Stealth & Scanner Physics Verification
	var scanner_head := wing.get_node_or_null("ScannerHead") as Node3D
	if not _check(scanner_head != null, "Missing ScannerHead node"):
		return
	
	# Spawn Player
	player = PLAYER_SCENE.instantiate()
	player.position = Vector3(-2.5, 0.1, 2.0) # Entry anchor
	root.add_child(player)
	player.finish_opening_recovery()
	player.surface_traversal_enabled = true
	wing.player = player
	wing.set_audio_muted(true)
	
	for i in range(10):
		await physics_frame
	
	if not _check(player.is_on_floor(), "Player failed to ground on floor"):
		return
	
	# Test A: Unobstructed Line of Sight Detection
	# Temporarily aim scanner directly at player at Vector3(-20.0, 0.1, -6.0)
	wing._scanner_active = false
	scanner_head.look_at(Vector3(-20.0, 0.9, -6.0), Vector3.UP)
	# Rotate 180 on Y because look_at points -Z forward
	player.position = Vector3(-20.0, 0.1, -6.0)
	await physics_frame
	await physics_frame
	
	var sees_in_open: bool = wing._scanner_sees(player)
	if not _check(sees_in_open, "Scanner must see player when standing directly in open beam"):
		return
	
	# Test B: Raycast Occlusion behind Cover Plinth
	# CoverPlinth_2 is at Vector3(-17.0, 0.9, -6.0)
	# Position player on the opposite side of plinth relative to scanner at Vector3(-15.0, 6.6, -6.0)
	player.position = Vector3(-18.5, 0.1, -6.0)
	await physics_frame
	await physics_frame
	
	var sees_behind_cover: bool = wing._scanner_sees(player)
	if not _check(not sees_behind_cover, "Scanner must NOT see player when occluded by CoverPlinth_2"):
		return
	
	# Test C: Alert Escalation & retry_requested signal
	wing._scanner_active = true
	scanner_head.look_at(Vector3(-20.0, 0.9, -6.0), Vector3.UP)
	player.position = Vector3(-20.0, 0.1, -6.0)
	
	# Advance frames across 0.6s grace period
	for frame in range(45):
		await physics_frame
	
	if not _check(retry_requested_fired, "Scanner failed to emit retry_requested after grace period in open sight"):
		return
	
	# 5. In-Game Interaction with Terminal (Area3D + trigger_interaction)
	# Move player near terminal InteractionArea at Vector3(-26.0, 0.1, -12.0)
	player.position = Vector3(-25.2, 0.1, -12.0)
	for i in range(5):
		await physics_frame
	
	var interact_res: Dictionary = player.interact_with_nearest()
	if not _check(interact_res.get("accepted", false), "player.interact_with_nearest() failed to trigger terminal"):
		return
	if not _check(interact_res.get("subject", "").contains("EX-011"), "Terminal log did not mention EX-011"):
		return
	if not _check(terminal_accessed_fired, "terminal_accessed signal did not fire"):
		return
	if not _check(gate_opened_fired, "exit_gate_opened signal did not fire"):
		return
	
	# Wait for gate opening tween to finish (~0.8s)
	var wait_gate := 0
	while not gate_shape.disabled and wait_gate < 70:
		await physics_frame
		wait_gate += 1
	
	if not _check(gate_shape.disabled == true, "Exit blast gate collision must be disabled when open"):
		return
	if not _check(wing.gate_open == true, "wing.gate_open should be true"):
		return
	
	# 6. State Save & Restore Audit
	var state_dict: Dictionary = wing.get_state()
	if not _check(state_dict.has("gate_open") and state_dict.has("terminal_read") and state_dict.has("discoveries"), "State dictionary malformed"):
		return
	
	var restored: bool = wing.restore_state(state_dict)
	if not _check(restored, "restore_state failed"):
		return
	
	# Cleanup
	player.queue_free()
	wing.queue_free()
	await process_frame
	
	print("PASS specimen containment wing: 30x24m hermetic hull, EX-005..EX-011 stasis tanks, stealth scanner with occlusion and alert grace, terminal Area3D interaction, gate unlock, and state restoration")
	quit(0)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
		return false
	return true
