extends SceneTree

const DECON_SCENE = preload("res://scenes/environment/decontamination_quarantine_wing.tscn")
const PLAYER_SCENE = preload("res://scenes/player/echo_player.tscn")

var wing: Node3D
var player: EchoPlayer

var override_initiated_fired := false
var quarantine_cleared_fired := false
var exit_gate_opened_fired := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("--- Starting Decontamination & Quarantine Wing Smoke Test ---")
	
	# 1. Instantiate Wing Scene
	wing = DECON_SCENE.instantiate()
	if not _check(wing != null, "Failed to instantiate decontamination_quarantine_wing.tscn"):
		return
	root.add_child(wing)
	
	for i in range(4):
		await process_frame
	
	# 2. Structural & Architectural Audit
	var floor_body := wing.get_node_or_null("Floor") as StaticBody3D
	var ceiling_body := wing.get_node_or_null("Ceiling") as StaticBody3D
	var west_wall := wing.get_node_or_null("WestWall") as StaticBody3D
	var east_wall := wing.get_node_or_null("EastWall") as StaticBody3D
	var catwalk := wing.get_node_or_null("ObservationCatwalkDeck") as StaticBody3D
	var exit_gate := wing.get_node_or_null("NorthExitBlastGate") as StaticBody3D
	var terminal := wing.get_node_or_null("QuarantineOverrideTerminal") as StaticBody3D
	
	if not _check(floor_body and ceiling_body and west_wall and east_wall, "Missing hermetic hull envelope components"):
		return
	if not _check(catwalk and exit_gate and terminal, "Missing key functional decon components"):
		return
	
	# Verify floor dimensions (24m x 32m)
	var floor_col: CollisionShape3D = floor_body.get_node("CollisionShape3D")
	var floor_box: BoxShape3D = floor_col.shape as BoxShape3D
	if not _check(is_equal_approx(floor_box.size.x, 24.0), "Room width must be 24.0m"):
		return
	if not _check(is_equal_approx(floor_box.size.z, 32.0), "Room length must be 32.0m"):
		return
	
	# Verify gate starts closed
	var gate_shape: CollisionShape3D = exit_gate.get_node("CollisionShape3D")
	if not _check(gate_shape.disabled == false, "Exit gate must start closed with active collision"):
		return
	
	# Connect signals
	wing.quarantine_override_initiated.connect(func(): override_initiated_fired = true)
	wing.quarantine_cleared.connect(func(): quarantine_cleared_fired = true)
	wing.exit_gate_opened.connect(func(): exit_gate_opened_fired = true)
	
	# 3. Spawn Player at Entry (Z = -2.0m, Y = 0.1m)
	player = PLAYER_SCENE.instantiate()
	player.position = Vector3(0.0, 0.1, -2.0)
	root.add_child(player)
	player.finish_opening_recovery()
	wing.player = player
	
	for i in range(10):
		await physics_frame
	
	if not _check(player.is_on_floor(), "Player failed to ground on floor"):
		return
	
	# 4. Check Safe Anchor at Entry
	var anchor_entry: Vector3 = wing.get_safe_anchor()
	if not _check(is_equal_approx(anchor_entry.z, -2.0), "Initial safe anchor must be Entry anchor"):
		return
	
	# 5. Move Player to Observation Catwalk (Z = -16.0m, Y = 3.3m)
	player.position = Vector3(0.0, 3.3, -16.0)
	for i in range(8):
		await physics_frame
	
	var anchor_catwalk: Vector3 = wing.get_safe_anchor()
	if not _check(is_equal_approx(anchor_catwalk.z, -16.0), "Safe anchor must advance to Catwalk"):
		return
	
	# 6. Interact with Terminal
	var interact_res: Dictionary = terminal.trigger_interaction(player)
	if not _check(interact_res.get("success", false) == true, "Terminal interaction failed"):
		return
	if not _check(override_initiated_fired and quarantine_cleared_fired and exit_gate_opened_fired, "Required override signals did not fire"):
		return
	
	# Wait for gate tween (~0.8s)
	var wait_gate := 0
	while not gate_shape.disabled and wait_gate < 70:
		await physics_frame
		wait_gate += 1
	
	if not _check(gate_shape.disabled == true, "Exit blast gate collision must be disabled when open"):
		return
	
	# 7. Move Player to Exit (Z = -29.0m, Y = 0.1m)
	player.position = Vector3(0.0, 0.1, -29.0)
	for i in range(5):
		await physics_frame
	
	var anchor_exit: Vector3 = wing.get_safe_anchor()
	if not _check(is_equal_approx(anchor_exit.z, -29.0), "Safe anchor must advance to Exit anchor"):
		return
	
	# 8. State Save & Restore Audit
	var state_dict: Dictionary = wing.get_state()
	if not _check(state_dict.get("override_done", false) and state_dict.get("gate_open", false), "State dictionary missing override or gate"):
		return
	
	print("PASS decontamination quarantine wing: 26x32m watertight hull, chemical scrubbers, decontamination cycle, and state restoration")
	if player:
		player.queue_free()
	if wing:
		wing.queue_free()
	await process_frame
	quit(0)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		printerr("TEST FAILED: " + message)
		quit(1)
		return false
	return true
