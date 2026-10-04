extends SceneTree

const AIRLOCK_SCENE = preload("res://scenes/environment/airlock_decompression_buffer.tscn")
const PLAYER_SCENE = preload("res://scenes/player/echo_player.tscn")

var airlock: Node3D
var player: EchoPlayer

var decompression_started_fired := false
var decompression_completed_fired := false
var passed_airlock_fired := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("--- Starting Airlock Decompression Buffer Smoke Test ---")
	
	# 1. Instantiate Airlock Buffer Scene
	airlock = AIRLOCK_SCENE.instantiate()
	if not _check(airlock != null, "Failed to instantiate airlock_decompression_buffer.tscn"):
		return
	root.add_child(airlock)
	
	for i in range(4):
		await process_frame
	
	# 2. Structural & Architectural Audit (Anti-Crowding Invariant)
	var floor_body := airlock.get_node_or_null("Floor") as StaticBody3D
	var ceiling_body := airlock.get_node_or_null("Ceiling") as StaticBody3D
	var west_wall := airlock.get_node_or_null("WestWall") as StaticBody3D
	var east_wall := airlock.get_node_or_null("EastWall") as StaticBody3D
	var outer_gate := airlock.get_node_or_null("OuterGate") as StaticBody3D
	var inner_gate := airlock.get_node_or_null("InnerGate") as StaticBody3D
	
	if not _check(floor_body and ceiling_body and west_wall and east_wall, "Airlock missing hermetic envelope boundaries"):
		return
	if not _check(outer_gate and inner_gate, "Airlock missing dual blast gates"):
		return
	
	# Verify continuous floor length covers 18.5m buffer zone
	var floor_col: CollisionShape3D = floor_body.get_node("CollisionShape3D")
	var floor_box: BoxShape3D = floor_col.shape as BoxShape3D
	if not _check(is_equal_approx(floor_box.size.z, 18.5), "Airlock floor length must be exactly 18.5m to span Z = -32.0m to -50.5m"):
		return
	if not _check(is_equal_approx(floor_box.size.x, 2.4), "Airlock floor width must be 2.4m"):
		return
	
	# Verify Initial Double Interlock State: Outer Gate is OPEN, Inner Gate is CLOSED
	var outer_shape: CollisionShape3D = outer_gate.get_node("CollisionShape3D")
	var inner_shape: CollisionShape3D = inner_gate.get_node("CollisionShape3D")
	if not _check(outer_shape.disabled == true, "Outer gate must start OPEN for entry from maintenance"):
		return
	if not _check(inner_shape.disabled == false, "Inner gate must start CLOSED and locked"):
		return
	
	# 3. Connect signals
	airlock.decompression_started.connect(func(): decompression_started_fired = true)
	airlock.decompression_completed.connect(func(): decompression_completed_fired = true)
	airlock.player_passed_airlock.connect(func(): passed_airlock_fired = true)
	
	# 4. Spawn Player in Entry Vestibule
	player = PLAYER_SCENE.instantiate()
	player.position = Vector3(0.0, 0.1, -2.0)
	root.add_child(player)
	player.finish_opening_recovery()
	player.surface_traversal_enabled = true
	airlock.player = player
	airlock.set_audio_muted(true) # Mute audio for headless CI
	
	for i in range(15):
		await physics_frame
	
	if not _check(player.is_on_floor(), "Player failed to ground in airlock entry vestibule"):
		return
	
	# 5. Move Player into Decompression Chamber Core (Z = -8.0)
	player.position = Vector3(0.0, 0.1, -8.0)
	for i in range(10):
		await physics_frame
	
	# Verify outer gate closed behind player
	if not _check(airlock.state == airlock.AirlockState.SEALING_OUTER or airlock.state == airlock.AirlockState.DECOMPRESSING, "Airlock failed to initiate decompression upon chamber entry"):
		return
	
	# Wait for outer gate to seal and decompression purge to start
	var wait_cycles := 0
	while airlock.state != airlock.AirlockState.DECOMPRESSING and wait_cycles < 60:
		await physics_frame
		wait_cycles += 1
	
	if not _check(airlock.state == airlock.AirlockState.DECOMPRESSING, "Airlock failed to enter DECOMPRESSING state"):
		return
	if not _check(outer_shape.disabled == false and inner_shape.disabled == false, "Both gates must be locked and collidable during decompression"):
		return
	if not _check(decompression_started_fired, "decompression_started signal did not fire"):
		return
	
	# Advance time for 1.5s decompression purge to complete
	for purge_frame in range(110): # ~1.8 seconds at 60Hz physics
		await physics_frame
	
	if not _check(decompression_completed_fired, "decompression_completed signal did not fire"):
		return
	if not _check(airlock.state == airlock.AirlockState.OPEN_INNER, "Airlock failed to open inner gate after purge"):
		return
	
	# Wait for inner gate 0.8s opening tween to finish and disable collision
	var wait_open := 0
	while not inner_shape.disabled and wait_open < 70:
		await physics_frame
		wait_open += 1
	
	if not _check(inner_shape.disabled == true, "Inner gate collision must be disabled when OPEN"):
		return
	if not _check(outer_shape.disabled == false, "Outer gate must remain locked while inner gate is open"):
		return
	
	# 6. Move Player through Inner Gate to Exit Corridor (Z = -14.5)
	player.position = Vector3(0.0, 0.1, -14.5)
	for i in range(10):
		await physics_frame
	
	if not _check(passed_airlock_fired, "player_passed_airlock signal did not fire"):
		return
	
	# 7. Safe Anchor Verification
	var anchor: Vector3 = airlock.get_safe_anchor()
	if not _check(is_equal_approx(anchor.z, -9.0) and is_equal_approx(anchor.x, 0.0), "Safe anchor must be centered at chamber midpoint (Z = -9.0)"):
		return
	
	# 8. State Save & Restore Audit
	var state_dict: Dictionary = airlock.get_state()
	if not _check(state_dict.has("state") and state_dict.has("outer_closed") and state_dict.has("inner_closed"), "Airlock state dictionary malformed"):
		return
	
	var restored: bool = airlock.restore_state(state_dict)
	if not _check(restored, "Airlock restore_state failed"):
		return
	
	# Cleanup
	player.queue_free()
	airlock.queue_free()
	await process_frame
	
	print("PASS airlock decompression buffer: 18.5m hermetic span, double interlock sequence, sealed hull, safe anchor, and durable state restoration")
	quit(0)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
		return false
	return true
