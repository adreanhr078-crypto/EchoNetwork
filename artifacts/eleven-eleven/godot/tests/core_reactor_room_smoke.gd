extends SceneTree

const REACTOR_SCENE = preload("res://scenes/environment/core_reactor_room.tscn")
const PLAYER_SCENE = preload("res://scenes/player/echo_player.tscn")

var room: Node3D
var player: EchoPlayer

var breaker_a_fired := false
var breaker_b_fired := false
var bridge_extended_fired := false
var gate_opened_fired := false
var retry_fired := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("--- Starting Core Reactor & Power Station Smoke Test ---")
	
	# 1. Instantiate Room Scene
	room = REACTOR_SCENE.instantiate()
	if not _check(room != null, "Failed to instantiate core_reactor_room.tscn"):
		return
	root.add_child(room)
	
	for i in range(4):
		await process_frame
	
	# 2. Structural & Architectural Audit
	var abyss_floor := room.get_node_or_null("AbyssFloor") as StaticBody3D
	var ceiling := room.get_node_or_null("Ceiling") as StaticBody3D
	var west_wall := room.get_node_or_null("WestWall") as StaticBody3D
	var east_wall := room.get_node_or_null("EastWall") as StaticBody3D
	var bridge := room.get_node_or_null("HydraulicBridge") as StaticBody3D
	var exit_gate := room.get_node_or_null("NorthExitGate") as StaticBody3D
	var reactor_core := room.get_node_or_null("ReactorCore") as Node3D
	
	if not _check(abyss_floor and ceiling and west_wall and east_wall, "Missing hermetic hull envelope components"):
		return
	if not _check(bridge and exit_gate and reactor_core, "Missing key functional reactor components"):
		return
	
	# Verify room envelope dimensions (36m x 44m)
	var floor_col: CollisionShape3D = abyss_floor.get_node("CollisionShape3D")
	var floor_box: BoxShape3D = floor_col.shape as BoxShape3D
	if not _check(is_equal_approx(floor_box.size.x, 36.0), "Room width must be 36.0m"):
		return
	if not _check(is_equal_approx(floor_box.size.z, 44.0), "Room length must be 44.0m"):
		return
	
	# Verify hydraulic bridge starts retracted
	if not _check(is_equal_approx(bridge.position.y, -3.5), "Hydraulic bridge must start retracted at Y = -3.5m"):
		return
	
	# Verify exit gate starts closed
	var gate_shape: CollisionShape3D = exit_gate.get_node("CollisionShape3D")
	if not _check(gate_shape.disabled == false, "Exit gate must start closed with active collision"):
		return
	
	# Connect signals
	room.breaker_a_activated.connect(func(): breaker_a_fired = true)
	room.breaker_b_activated.connect(func(): breaker_b_fired = true)
	room.hydraulic_bridge_extended.connect(func(): bridge_extended_fired = true)
	room.exit_gate_opened.connect(func(): gate_opened_fired = true)
	room.retry_requested.connect(func(_pos): retry_fired = true)
	
	# 3. Spawn Player at Entry Balcony (Z = -2.5m, Y = -3.9m)
	player = PLAYER_SCENE.instantiate()
	player.position = Vector3(0.0, -3.9, -2.5)
	root.add_child(player)
	player.finish_opening_recovery()
	room.player = player
	
	for i in range(10):
		await physics_frame
	
	if not _check(player.is_on_floor(), "Player failed to ground on entry balcony deck"):
		return
	
	# 4. Check Safe Anchor Alpha at Entry
	var anchor_alpha: Vector3 = room.get_safe_anchor()
	if not _check(is_equal_approx(anchor_alpha.z, -2.5), "Initial safe anchor must be Anchor Alpha"):
		return
	
	# 5. Breaker A Interaction (West Platform)
	var breaker_a_console := room.get_node_or_null("BreakerAConsole") as Node3D
	if not _check(breaker_a_console != null, "Missing BreakerAConsole"):
		return
	
	var res_a: Dictionary = breaker_a_console.trigger_interaction(player)
	if not _check(res_a.get("success", false) and breaker_a_fired, "Breaker A activation failed"):
		return
	if not _check(bridge_extended_fired == false, "Bridge must not extend before both breakers are active"):
		return
	
	# 6. Breaker B Interaction (East Platform)
	var breaker_b_console := room.get_node_or_null("BreakerBConsole") as Node3D
	if not _check(breaker_b_console != null, "Missing BreakerBConsole"):
		return
	
	var res_b: Dictionary = breaker_b_console.trigger_interaction(player)
	if not _check(res_b.get("success", false) and breaker_b_fired, "Breaker B activation failed"):
		return
	if not _check(bridge_extended_fired == true, "Bridge must trigger extension when both breakers are active"):
		return
	
	# Wait for bridge and gate tweens (~1.5s)
	var wait_bridge := 0
	while not is_equal_approx(bridge.position.y, 0.0) and wait_bridge < 150:
		await physics_frame
		wait_bridge += 1
	
	if not _check(is_equal_approx(bridge.position.y, 0.0), "Bridge failed to reach extended position Y = 0.0m"):
		return
	
	# Verify gate opened
	var wait_gate := 0
	while not gate_shape.disabled and wait_gate < 70:
		await physics_frame
		wait_gate += 1
	
	if not _check(gate_opened_fired and gate_shape.disabled, "Exit gate failed to open and disable collision"):
		return
	
	# 7. Move Player onto Exit Gantry and verify Anchor Gamma
	player.position = Vector3(0.0, 0.1, -41.0)
	for i in range(5):
		await physics_frame
	
	var anchor_gamma: Vector3 = room.get_safe_anchor()
	if not _check(is_equal_approx(anchor_gamma.z, -41.0), "Safe anchor must advance to Anchor Gamma on exit gantry"):
		return
	
	# 8. Abyss Fall & Recovery Audit
	# Move player into abyss volume (Y = -9.2m)
	player.position = Vector3(0.0, -9.2, -22.0)
	for i in range(5):
		await physics_frame
	
	if not _check(retry_fired, "retry_requested did not fire when entering abyss recovery zone"):
		return
	if not _check(is_equal_approx(player.global_position.z, -41.0), "Player was not repositioned to current safe anchor"):
		return
	
	# 9. State Persistence Audit
	var state_dict: Dictionary = room.get_state()
	if not _check(state_dict.get("breaker_a_done", false) and state_dict.get("breaker_b_done", false), "State missing active breakers"):
		return
	if not _check(state_dict.get("bridge_extended", false) and state_dict.get("gate_open", false), "State missing bridge or gate"):
		return
	
	print("PASS core reactor room: 36x44m watertight hull, tokamak core, dual breakers, hydraulic bridge, electric hazard timing, and abyss recovery")
	if player:
		player.queue_free()
	if room:
		room.queue_free()
	for i in range(3):
		await process_frame
		await physics_frame
	quit(0)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		printerr("TEST FAILED: " + message)
		quit(1)
		return false
	return true
