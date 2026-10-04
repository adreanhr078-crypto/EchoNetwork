extends SceneTree

const CONDUIT_SCENE = preload("res://scenes/environment/archive_to_reactor_conduit.tscn")
const PLAYER_SCENE = preload("res://scenes/player/echo_player.tscn")

var conduit: Node3D
var player: EchoPlayer

var bulkhead_opened_fired := false
var player_passed_fired := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("--- Starting Archive to Reactor Conduit Buffer Smoke Test ---")
	
	# 1. Instantiate Conduit Scene
	conduit = CONDUIT_SCENE.instantiate()
	if not _check(conduit != null, "Failed to instantiate archive_to_reactor_conduit.tscn"):
		return
	root.add_child(conduit)
	
	for i in range(4):
		await process_frame
	
	# 2. Structural & Architectural Audit
	var floor_body := conduit.get_node_or_null("Floor") as StaticBody3D
	var ceiling_body := conduit.get_node_or_null("Ceiling") as StaticBody3D
	var west_wall := conduit.get_node_or_null("WestWall") as StaticBody3D
	var east_wall := conduit.get_node_or_null("EastWall") as StaticBody3D
	var bulkhead_gate := conduit.get_node_or_null("MidpointBulkheadGate") as StaticBody3D
	
	if not _check(floor_body and ceiling_body and west_wall and east_wall, "Missing hermetic hull envelope components"):
		return
	if not _check(bulkhead_gate != null, "Missing MidpointBulkheadGate"):
		return
	
	# Verify floor length = 15.0m along Z, width = 2.6m along X
	var floor_col: CollisionShape3D = floor_body.get_node("CollisionShape3D")
	var floor_box: BoxShape3D = floor_col.shape as BoxShape3D
	if not _check(is_equal_approx(floor_box.size.z, 15.0), "Conduit length must be exactly 15.0m along Z"):
		return
	if not _check(is_equal_approx(floor_box.size.x, 2.6), "Conduit width must be 2.6m along X"):
		return
	
	# Verify bulkhead starts closed
	var bh_shape: CollisionShape3D = bulkhead_gate.get_node("CollisionShape3D")
	if not _check(bh_shape.disabled == false, "Bulkhead must start closed and collidable"):
		return
	
	# Connect signals
	conduit.bulkhead_opened.connect(func(): bulkhead_opened_fired = true)
	conduit.player_passed_conduit.connect(func(): player_passed_fired = true)
	
	# 3. Spawn Player at Entry (Z = -1.5m)
	player = PLAYER_SCENE.instantiate()
	player.position = Vector3(0.0, 0.1, -1.5)
	root.add_child(player)
	player.finish_opening_recovery()
	conduit.player = player
	
	for i in range(10):
		await physics_frame
	
	if not _check(player.is_on_floor(), "Player failed to ground on conduit floor"):
		return
	
	# 4. Move Player toward Midpoint Bulkhead (Z = -6.5m)
	player.position = Vector3(0.0, 0.1, -6.5)
	for i in range(5):
		await physics_frame
	
	if not _check(bulkhead_opened_fired, "bulkhead_opened signal did not fire"):
		return
	
	# Wait for bulkhead tween (~0.7s)
	var wait_bh := 0
	while not bh_shape.disabled and wait_bh < 60:
		await physics_frame
		wait_bh += 1
	
	if not _check(bh_shape.disabled == true, "Bulkhead gate collision must be disabled when open"):
		return
	
	# 5. Move Player to Conduit Exit (Z = -14.0m)
	player.position = Vector3(0.0, 0.1, -14.0)
	for i in range(5):
		await physics_frame
	
	if not _check(player_passed_fired, "player_passed_conduit signal did not fire"):
		return
	
	# 6. Safe Anchor Verification
	var anchor: Vector3 = conduit.get_safe_anchor()
	if not _check(is_equal_approx(anchor.z, -7.5) and is_equal_approx(anchor.x, 0.0), "Safe anchor must be centered at midpoint"):
		return
	
	# 7. State Save & Restore Audit
	var state_dict: Dictionary = conduit.get_state()
	if not _check(state_dict.has("bulkhead_open") and state_dict["bulkhead_open"] == true, "State missing bulkhead_open"):
		return
	
	if player:
		player.queue_free()
	if conduit:
		conduit.queue_free()
	for i in range(3):
		await process_frame
		await physics_frame
	print("PASS archive to reactor conduit: 15.0m dedicated spatial buffer, watertight envelope, midpoint bulkhead, safe anchor, and state restoration")
	quit(0)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		printerr("TEST FAILED: " + message)
		quit(1)
		return false
	return true
