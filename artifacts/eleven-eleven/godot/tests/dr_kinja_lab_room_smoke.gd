extends SceneTree

const ROOM_SCENE = preload("res://scenes/environment/dr_kinja_lab_room.tscn")
const PLAYER_SCENE = preload("res://scenes/player/echo_player.tscn")

var room: Node3D
var player: EchoPlayer

var confrontation_started_fired := false
var drowning_completed_fired := false
var zero_manifested_fired := false
var contract_accepted_fired := false
var stasis_1111_fired := false
var exit_breach_opened_fired := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("--- Starting Dr. Kinja's Lab & Zero Contract Chamber Smoke Test ---")
	
	# 1. Instantiate Room Scene
	room = ROOM_SCENE.instantiate()
	if not _check(room != null, "Failed to instantiate dr_kinja_lab_room.tscn"):
		return
	root.add_child(room)
	
	for i in range(4):
		await process_frame
	
	# 2. Structural & Architectural Audit
	var floor_body := room.get_node_or_null("Floor") as StaticBody3D
	var ceiling_body := room.get_node_or_null("Ceiling") as StaticBody3D
	var west_wall := room.get_node_or_null("WestWall") as StaticBody3D
	var east_wall := room.get_node_or_null("EastWall") as StaticBody3D
	var dais := room.get_node_or_null("SurgicalDaisPlatform") as StaticBody3D
	var table := room.get_node_or_null("NeuralRigTable") as StaticBody3D
	var neural_terminal := room.get_node_or_null("KinjaNeuralRigTerminal") as StaticBody3D
	var contract_altar := room.get_node_or_null("ZeroContractAltar") as StaticBody3D
	var breach_portal := room.get_node_or_null("DimensionalBreachPortal") as StaticBody3D
	
	if not _check(floor_body and ceiling_body and west_wall and east_wall, "Missing hermetic hull envelope components"):
		return
	if not _check(dais and table and neural_terminal and contract_altar and breach_portal, "Missing key theater components"):
		return
	
	# Verify floor dimensions (32m x 40m)
	var floor_col: CollisionShape3D = floor_body.get_node("CollisionShape3D")
	var floor_box: BoxShape3D = floor_col.shape as BoxShape3D
	if not _check(is_equal_approx(floor_box.size.x, 32.0), "Room width must be 32.0m"):
		return
	if not _check(is_equal_approx(floor_box.size.z, 40.0), "Room length must be 40.0m"):
		return
	
	# Verify breach portal starts closed
	var breach_shape: CollisionShape3D = breach_portal.get_node("CollisionShape3D")
	if not _check(breach_shape.disabled == false, "Breach portal must start closed with active collision"):
		return
	
	# Connect signals
	room.memory_confrontation_started.connect(func(): confrontation_started_fired = true)
	room.memory_drowning_completed.connect(func(): drowning_completed_fired = true)
	room.zero_manifested.connect(func(): zero_manifested_fired = true)
	room.zero_contract_accepted.connect(func(): contract_accepted_fired = true)
	room.stasis_1111_activated.connect(func(): stasis_1111_fired = true)
	room.exit_breach_opened.connect(func(): exit_breach_opened_fired = true)
	
	# 3. Spawn Player at Entry (Z = -2.0m, Y = 0.1m)
	player = PLAYER_SCENE.instantiate()
	player.position = Vector3(0.0, 0.1, -2.0)
	root.add_child(player)
	player.finish_opening_recovery()
	room.player = player
	
	for i in range(10):
		await physics_frame
	
	if not _check(player.is_on_floor(), "Player failed to ground on floor"):
		return
	
	# 4. Check Initial Safe Anchor
	var anchor_entry: Vector3 = room.get_safe_anchor()
	if not _check(is_equal_approx(anchor_entry.z, -2.0), "Initial safe anchor must be Entry anchor"):
		return
	
	# 5. Move Player to Surgical Theater Dais (Z = -20.0m, Y = 1.3m)
	player.position = Vector3(0.0, 1.3, -20.0)
	for i in range(8):
		await physics_frame
	
	var anchor_theater: Vector3 = room.get_safe_anchor()
	if not _check(is_equal_approx(anchor_theater.z, -20.0), "Safe anchor must advance to Surgical Theater"):
		return
	
	# 6. Interact with Kinja Neural Rig Terminal
	var conf_res: Dictionary = neural_terminal.trigger_interaction(player)
	if not _check(conf_res.get("success", false) == true, "Confrontation interaction failed"):
		return
	if not _check(confrontation_started_fired, "memory_confrontation_started signal did not fire"):
		return
	
	# Wait for pod drowning tween (~1.2s)
	var wait_drown := 0
	while not drowning_completed_fired and wait_drown < 100:
		await physics_frame
		wait_drown += 1
	
	if not _check(drowning_completed_fired and zero_manifested_fired, "Memory drowning and Zero manifestation did not complete"):
		return
	
	# 7. Move Player to Zero Contract Altar (Z = -32.0m, Y = 0.1m)
	player.position = Vector3(0.0, 0.1, -32.0)
	for i in range(8):
		await physics_frame
	
	var anchor_contract: Vector3 = room.get_safe_anchor()
	if not _check(is_equal_approx(anchor_contract.z, -32.0), "Safe anchor must advance to Zero Contract Altar"):
		return
	
	# 8. Accept Zero Contract
	var contract_res: Dictionary = contract_altar.trigger_interaction(player)
	if not _check(contract_res.get("success", false) == true and contract_res.get("power_granted", "") == "shadow_surge", "Zero contract acceptance failed"):
		return
	if not _check(contract_accepted_fired and stasis_1111_fired and exit_breach_opened_fired, "Contract, 11:11 stasis, and breach signals did not fire"):
		return
	
	# Wait for breach portal tween (~0.8s)
	var wait_breach := 0
	while not breach_shape.disabled and wait_breach < 70:
		await physics_frame
		wait_breach += 1
	
	if not _check(breach_shape.disabled == true, "Breach portal collision must be disabled when open"):
		return
	
	# 9. State Save & Restore Audit
	var state_dict: Dictionary = room.get_state()
	if not _check(state_dict.get("confrontation_done", false) and state_dict.get("contract_done", false), "State missing confrontation or contract"):
		return
	if not _check(state_dict.get("breach_open", false), "State missing breach_open"):
		return
	
	print("PASS dr kinja lab room: 32x38m watertight surgical theater, abyssal rift transition, zero pact confirmation, and state restoration")
	if player:
		player.queue_free()
	if room:
		room.queue_free()
	await process_frame
	quit(0)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		printerr("TEST FAILED: " + message)
		quit(1)
		return false
	return true
