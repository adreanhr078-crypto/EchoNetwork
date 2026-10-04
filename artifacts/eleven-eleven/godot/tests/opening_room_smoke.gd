extends SceneTree

const OPENING_ROOM_SCENE = preload("res://scenes/environment/opening_room.tscn")
const PLAYER_SCENE = preload("res://scenes/player/echo_player.tscn")

var room: Node3D
var player: EchoPlayer

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("--- Starting Opening Room (Awakening Cryo-Chamber) Smoke Test ---")
	
	room = OPENING_ROOM_SCENE.instantiate()
	if not _check(room != null, "Failed to instantiate opening_room.tscn"):
		return
	root.add_child(room)
	
	for i in range(4):
		await process_frame
	
	# 1. Structural Verification: Opening Shell and Containment
	var shell = room.get_node_or_null("Sector11OpeningShell")
	if not _check(shell != null, "Opening room missing Sector11OpeningShell"):
		return
	if not _check(shell.get("opening_only") == true, "Sector11OpeningShell must have opening_only = true"):
		return
	
	# Verify Hermetic South Containment Wall
	var south_wall = shell.get_node_or_null("SouthContainmentWall_Body/Collider")
	if not _check(south_wall != null, "Opening room missing hermetic South containment wall"):
		return
	
	# Verify Hermetic North Bulkhead
	var north_bulkhead = shell.get_node_or_null("Gate1_Bulkhead_West_Body/Collider")
	if not _check(north_bulkhead != null, "Opening room missing hermetic North bulkhead"):
		return
	
	# 2. Gate Verification: Primary Blast Gate must be locked at Z = -18.0
	var gate = room.get_node_or_null("PrimaryBlastGate")
	if not _check(gate != null, "Opening room missing PrimaryBlastGate"):
		return
	if not _check(is_equal_approx(gate.position.z, -18.0), "PrimaryBlastGate must be placed at Z = -18.0"):
		return
	if not _check(gate.get("state") == 0, "PrimaryBlastGate must start LOCKED to prevent unauthorized exit"):
		return
	
	# 3. Vent Duct Verification: High Wall Aperture (Section 3.1)
	var vent_anchor: Vector3 = room.get_vent_anchor()
	if not _check(is_equal_approx(vent_anchor.x, 3.2) and is_equal_approx(vent_anchor.y, 1.8) and is_equal_approx(vent_anchor.z, -18.0), "Vent duct aperture must be located at (3.2, 1.8, -18.0) per specification"):
		return
	
	# 4. Terminal & Evidence Props
	var terminal = room.get_node_or_null("SectorTerminal")
	var clock = room.get_node_or_null("OpeningClock")
	var photo = room.get_node_or_null("OpeningPhotograph")
	if not _check(terminal and clock and photo, "Opening room missing required terminal or evidence props"):
		return
	
	# 5. Spawn Player & Test Grounding
	player = PLAYER_SCENE.instantiate()
	player.position = Vector3(0.0, 0.1, 0.0)
	root.add_child(player)
	player.finish_opening_recovery()
	player.surface_traversal_enabled = true
	
	for i in range(15):
		await physics_frame
	
	if not _check(player.is_on_floor(), "Player failed to ground on flooded catwalk floor"):
		return
	
	# Cleanup
	player.queue_free()
	room.queue_free()
	await process_frame
	
	print("PASS opening room: 18x25.4m isolated chamber, watertight containment, locked blast gate, high vent aperture, and grounded player")
	quit(0)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
		return false
	return true
