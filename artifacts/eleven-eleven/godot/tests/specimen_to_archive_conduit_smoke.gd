extends SceneTree

const CONDUIT_SCENE = preload("res://scenes/environment/specimen_to_archive_conduit.tscn")
const PLAYER_SCENE = preload("res://scenes/player/echo_player.tscn")

var conduit: Node3D
var player: EchoPlayer

var bulkhead_opened_fired := false
var player_passed_fired := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("--- Starting Specimen to Archive Conduit Buffer Smoke Test ---")
	
	# 1. Instantiate Conduit Scene
	conduit = CONDUIT_SCENE.instantiate()
	if not _check(conduit != null, "Failed to instantiate specimen_to_archive_conduit.tscn"):
		return
	root.add_child(conduit)
	
	for i in range(4):
		await process_frame
	
	# 2. Structural & Architectural Audit
	var floor_body := conduit.get_node_or_null("Floor") as StaticBody3D
	var ceiling_body := conduit.get_node_or_null("Ceiling") as StaticBody3D
	var north_wall := conduit.get_node_or_null("NorthWall") as StaticBody3D
	var south_wall := conduit.get_node_or_null("SouthWall") as StaticBody3D
	var bulkhead_gate := conduit.get_node_or_null("MidpointBulkheadGate") as StaticBody3D
	
	if not _check(floor_body and ceiling_body and north_wall and south_wall, "Missing hermetic hull envelope components"):
		return
	if not _check(bulkhead_gate != null, "Missing MidpointBulkheadGate"):
		return
	
	# Verify floor length = 14.0m, width = 2.6m
	var floor_col: CollisionShape3D = floor_body.get_node("CollisionShape3D")
	var floor_box: BoxShape3D = floor_col.shape as BoxShape3D
	if not _check(is_equal_approx(floor_box.size.x, 14.0), "Conduit length must be exactly 14.0m to span between Room 5 and 6"):
		return
	if not _check(is_equal_approx(floor_box.size.z, 2.6), "Conduit width must be 2.6m"):
		return
	
	# Verify bulkhead starts closed
	var bh_shape: CollisionShape3D = bulkhead_gate.get_node("CollisionShape3D")
	if not _check(bh_shape.disabled == false, "Bulkhead must start closed and collidable"):
		return
	
	# Connect signals
	conduit.bulkhead_opened.connect(func(): bulkhead_opened_fired = true)
	conduit.player_passed_conduit.connect(func(): player_passed_fired = true)
	
	# 3. Spawn Player at Entry (X = -1.5m)
	player = PLAYER_SCENE.instantiate()
	player.position = Vector3(-1.5, 0.1, 0.0)
	root.add_child(player)
	player.finish_opening_recovery()
	conduit.player = player
	
	for i in range(10):
		await physics_frame
	
	if not _check(player.is_on_floor(), "Player failed to ground on conduit floor"):
		return
	
	# 4. Move Player toward Midpoint Bulkhead (X = -6.5m)
	player.position = Vector3(-6.5, 0.1, 0.0)
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
	
	# 5. Move Player to Conduit Exit (X = -13.0m)
	player.position = Vector3(-13.0, 0.1, 0.0)
	for i in range(5):
		await physics_frame
	
	if not _check(player_passed_fired, "player_passed_conduit signal did not fire"):
		return
	
	# 6. Safe Anchor Verification
	var anchor: Vector3 = conduit.get_safe_anchor()
	if not _check(is_equal_approx(anchor.x, -7.0) and is_equal_approx(anchor.z, 0.0), "Safe anchor must be centered at midpoint"):
		return
	
	# 7. State Save & Restore Audit
	var state_dict: Dictionary = conduit.get_state()
	if not _check(state_dict.has("bulkhead_open") and state_dict.has("state"), "State dictionary malformed"):
		return
	
	var restored: bool = conduit.restore_state(state_dict)
	if not _check(restored, "conduit restore_state failed"):
		return
	
	# Cleanup
	player.queue_free()
	conduit.queue_free()
	await process_frame
	
	print("PASS specimen to archive conduit: 14.0m dedicated spatial buffer, watertight envelope, midpoint bulkhead, safe anchor, and state restoration")
	quit(0)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
		return false
	return true
