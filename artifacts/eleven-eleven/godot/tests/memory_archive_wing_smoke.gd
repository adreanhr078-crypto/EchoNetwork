extends SceneTree

const ARCHIVE_SCENE = preload("res://scenes/environment/memory_archive_wing.tscn")
const PLAYER_SCENE = preload("res://scenes/player/echo_player.tscn")

var wing: Node3D
var player: EchoPlayer

var shard_collected_fired := false
var archive_unlocked_fired := false
var gate_opened_fired := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("--- Starting Room 6 Memory Archive Wing Smoke Test ---")
	
	# 1. Instantiate Room 6 Scene
	wing = ARCHIVE_SCENE.instantiate()
	if not _check(wing != null, "Failed to instantiate memory_archive_wing.tscn"):
		return
	root.add_child(wing)
	
	for i in range(4):
		await process_frame
	
	# 2. Structural & Architectural Audit (Anti-Crowding Invariant)
	var floor_body := wing.get_node_or_null("Floor") as StaticBody3D
	var ceiling_body := wing.get_node_or_null("Ceiling") as StaticBody3D
	var south_wall := wing.get_node_or_null("SouthWall") as StaticBody3D
	var west_wall := wing.get_node_or_null("WestWall") as StaticBody3D
	var east_north := wing.get_node_or_null("EastWallNorth") as StaticBody3D
	var east_south := wing.get_node_or_null("EastWallSouth") as StaticBody3D
	var north_west := wing.get_node_or_null("NorthWallWest") as StaticBody3D
	var north_east := wing.get_node_or_null("NorthWallEast") as StaticBody3D
	var gate_body := wing.get_node_or_null("NorthExitBlastGate") as StaticBody3D
	var console_body := wing.get_node_or_null("ArchiveDecoderConsole") as StaticBody3D
	var catwalk_body := wing.get_node_or_null("CatwalkBridge") as StaticBody3D
	var pedestal_body := wing.get_node_or_null("HolographicCorePedestal") as StaticBody3D
	
	if not _check(floor_body and ceiling_body and south_wall and west_wall, "Missing hermetic hull outer envelope"):
		return
	if not _check(east_north and east_south and north_west and north_east, "Missing portal wall envelope partitions"):
		return
	if not _check(gate_body != null, "Missing NorthExitBlastGate"):
		return
	if not _check(console_body != null, "Missing ArchiveDecoderConsole"):
		return
	if not _check(catwalk_body != null and pedestal_body != null, "Missing catwalk bridge or holographic pedestal"):
		return
	
	# Verify floor dimensions (22.0m wide x 28.0m long)
	var floor_col: CollisionShape3D = floor_body.get_node("CollisionShape3D")
	var floor_box: BoxShape3D = floor_col.shape as BoxShape3D
	if not _check(is_equal_approx(floor_box.size.x, 22.0), "Room width must be 22.0m"):
		return
	if not _check(is_equal_approx(floor_box.size.z, 28.0), "Room length must be 28.0m"):
		return
	
	# Verify Exit Blast Gate starts locked and sealed (2.05m wide)
	var gate_shape: CollisionShape3D = gate_body.get_node("CollisionShape3D")
	var gate_box: BoxShape3D = gate_shape.shape as BoxShape3D
	if not _check(gate_shape.disabled == false, "Exit gate must start closed and collidable"):
		return
	if not _check(is_equal_approx(gate_box.size.x, 2.05) or gate_box.size.x >= 2.04, "Exit gate must span 2.05m to cover doorway"):
		return
	
	# Verify Server Racks and Climbable Rungs
	var north_rack := wing.get_node_or_null("NorthRack_6") as StaticBody3D
	var south_rack := wing.get_node_or_null("SouthRack_6") as StaticBody3D
	if not _check(north_rack != null and south_rack != null, "Missing server rack towers"):
		return
	var rung := wing.get_node_or_null("NorthRack_6_Rung_0") as Node3D
	if not _check(rung != null and rung.has_meta("climbable") and rung.get_meta("climbable") == true, "Server rack rungs must be tagged as climbable"):
		return
	
	# 3. Verify Memory Shards (Shizuka, Yuki, Sector 11)
	var expected_shards := ["shard_shizuka", "shard_yuki", "shard_sector11"]
	for sid in expected_shards:
		var shard_node := wing.get_node_or_null("Shard_" + sid) as Area3D
		if not _check(shard_node != null, "Missing memory shard node: " + sid):
			return
		var shard_col: CollisionShape3D = shard_node.get_node_or_null("CollisionShape3D")
		if not _check(shard_col != null and shard_col.shape is SphereShape3D, "Shard missing sphere collision shape: " + sid):
			return
	
	# Connect signals
	wing.memory_shard_collected.connect(func(id: String): shard_collected_fired = true)
	wing.archive_unlocked.connect(func(): archive_unlocked_fired = true)
	wing.exit_gate_opened.connect(func(): gate_opened_fired = true)
	
	# 4. Spawn Player
	player = PLAYER_SCENE.instantiate()
	player.position = Vector3(-2.0, 0.1, 0.0) # Entry anchor
	root.add_child(player)
	player.finish_opening_recovery()
	player.surface_traversal_enabled = true
	wing.player = player
	
	for i in range(10):
		await physics_frame
	
	if not _check(player.is_on_floor(), "Player failed to ground on floor"):
		return
	
	# 5. Premature Decode Attempt Check (Must Reject when shards are missing)
	var pre_dec: Dictionary = wing.decode_archive_and_unlock()
	if not _check(pre_dec.get("success", true) == false, "Archive decode must fail when shards are missing"):
		return
	if not _check(pre_dec.get("reason", "") == "missing_shards", "Rejection reason must be missing_shards"):
		return
	
	# 6. Collect All 3 Shards
	var c1: Dictionary = wing._collect_shard("shard_shizuka")
	var c2: Dictionary = wing._collect_shard("shard_yuki")
	var c3: Dictionary = wing._collect_shard("shard_sector11")
	if not _check(c1.get("success", false) and c2.get("success", false) and c3.get("success", false), "Failed to collect shards"):
		return
	if not _check(shard_collected_fired, "memory_shard_collected signal did not fire"):
		return
	if not _check(wing.collected_shards.size() == 3, "All 3 shards must be in collected_shards"):
		return
	if not _check(wing.state == wing.RoomState.SHARDS_COLLECTED, "Room state must be SHARDS_COLLECTED"):
		return
	
	# 7. In-Game Interaction with Terminal (Area3D + trigger_interaction)
	# Move player into InteractionArea of console at Vector3(-11.0, 0.6, -3.2)
	player.position = Vector3(-11.0, 0.1, -2.5)
	for i in range(5):
		await physics_frame
	
	var interact_res: Dictionary = player.interact_with_nearest()
	if not _check(interact_res.get("success", false) == true, "player.interact_with_nearest() failed to interact with console"):
		return
	if not _check(interact_res.get("decoded", false) == true, "Console did not return decoded=true"):
		return
	if not _check(archive_unlocked_fired, "archive_unlocked signal did not fire"):
		return
	if not _check(gate_opened_fired, "exit_gate_opened signal did not fire"):
		return
	
	# Wait for gate opening tween (~0.8s)
	var wait_gate := 0
	while not gate_shape.disabled and wait_gate < 70:
		await physics_frame
		wait_gate += 1
	
	if not _check(gate_shape.disabled == true, "Exit blast gate collision must be disabled when open"):
		return
	if not _check(wing.gate_open == true, "wing.gate_open should be true"):
		return
	
	# 8. State Save & Restore Audit
	var state_dict: Dictionary = wing.get_state()
	if not _check(state_dict.has("collected_shards") and state_dict.has("archive_decoded") and state_dict.has("gate_open"), "State dictionary malformed"):
		return
	
	var restored: bool = wing.restore_state(state_dict)
	if not _check(restored, "restore_state failed"):
		return
	
	# Cleanup
	player.queue_free()
	wing.queue_free()
	await process_frame
	
	print("PASS memory archive wing: 22x28m watertight hull, climbable server towers, 3 memory shards, console decoding, gate unlock, and state restoration")
	quit(0)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
		return false
	return true
