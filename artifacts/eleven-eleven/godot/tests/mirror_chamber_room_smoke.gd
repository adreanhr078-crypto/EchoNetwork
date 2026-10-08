extends SceneTree

const ROOM_SCENE = preload("res://scenes/environment/mirror_chamber_room.tscn")
const PLAYER_SCENE = preload("res://scenes/player/echo_player.tscn")

var room: Node3D
var player: EchoPlayer

var mirror_inspected_fired := false
var override_initiated_fired := false
var security_cleared_fired := false
var exit_gate_opened_fired := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("--- Starting Mirror Chamber & Surveillance Hub Smoke Test ---")
	
	# 1. Instantiate Room Scene
	room = ROOM_SCENE.instantiate()
	if not _check(room != null, "Failed to instantiate mirror_chamber_room.tscn"):
		return
	root.add_child(room)
	
	for i in range(4):
		await process_frame
	
	# 2. Structural & Architectural Audit
	var floor_body := room.get_node_or_null("Floor") as StaticBody3D
	var ceiling_body := room.get_node_or_null("Ceiling") as StaticBody3D
	var west_wall := room.get_node_or_null("WestWall") as StaticBody3D
	var east_wall := room.get_node_or_null("EastWall") as StaticBody3D
	var dais := room.get_node_or_null("CommandDaisDeck") as StaticBody3D
	var exit_gate := room.get_node_or_null("SurveillanceExitGate") as StaticBody3D
	var terminal := room.get_node_or_null("MasterSecurityTerminal") as StaticBody3D
	var mirror_chamber := room.get_node_or_null("SurveillanceMirrorChamber") as Node3D
	
	if not _check(floor_body and ceiling_body and west_wall and east_wall, "Missing hermetic hull envelope components"):
		return
	if not _check(dais and exit_gate and terminal and mirror_chamber, "Missing key functional surveillance components"):
		return
	
	# Verify floor dimensions (28m x 36m)
	var floor_col: CollisionShape3D = floor_body.get_node("CollisionShape3D")
	var floor_box: BoxShape3D = floor_col.shape as BoxShape3D
	if not _check(is_equal_approx(floor_box.size.x, 28.0), "Room width must be 28.0m"):
		return
	if not _check(is_equal_approx(floor_box.size.z, 36.0), "Room length must be 36.0m"):
		return
	
	# Verify exit gate starts closed
	var gate_shape: CollisionShape3D = exit_gate.get_node("CollisionShape3D")
	if not _check(gate_shape.disabled == false, "Exit gate must start closed with active collision"):
		return
	
	# Connect signals
	room.mirror_examined.connect(func(): mirror_inspected_fired = true)
	room.lockdown_override_initiated.connect(func(): override_initiated_fired = true)
	room.security_cleared.connect(func(): security_cleared_fired = true)
	room.exit_gate_opened.connect(func(): exit_gate_opened_fired = true)
	
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
	
	# 5. Move Player to Mirror Inspection Area (X = 8.5m, Z = -10.0m)
	player.position = Vector3(8.5, 1.6, -10.0)
	for i in range(8):
		await physics_frame
	
	if not _check(mirror_inspected_fired, "mirror_examined signal did not fire"):
		return
	
	# 6. Move Player to Command Dais (Z = -18.0m, Y = 2.5m)
	player.position = Vector3(0.0, 2.5, -18.0)
	for i in range(8):
		await physics_frame
	
	var anchor_dais: Vector3 = room.get_safe_anchor()
	if not _check(is_equal_approx(anchor_dais.z, -18.0), "Safe anchor must advance to Command Dais"):
		return
	
	# 7. Terminal Interaction & Lockdown Override
	var interact_res: Dictionary = terminal.trigger_interaction(player)
	if not _check(interact_res.get("success", false) == true, "Terminal interaction failed"):
		return
	if not _check(override_initiated_fired and security_cleared_fired and exit_gate_opened_fired, "Required override signals did not fire"):
		return
	
	# Wait for gate tween (~0.8s)
	var wait_gate := 0
	while not gate_shape.disabled and wait_gate < 70:
		await physics_frame
		wait_gate += 1
	
	if not _check(gate_shape.disabled == true, "Exit blast gate collision must be disabled when open"):
		return
	room.set_presentation_language("en")
	if not _check(room.get_node("Telemetry/Readout1").text=="ACCESS / UNLOCKED", "Actual override must update telemetry instead of retaining LOCKED"):
		return
	room.set_presentation_language("ar")
	if not _check(room.get_node("Telemetry/Readout1").text.contains("مفتوح"), "Arabic telemetry must follow the same real state"):
		return
	
	# 8. Move Player to Exit Gantry (Z = -33.0m, Y = 0.1m)
	player.position = Vector3(0.0, 0.1, -33.0)
	for i in range(5):
		await physics_frame
	
	var anchor_exit: Vector3 = room.get_safe_anchor()
	if not _check(is_equal_approx(anchor_exit.z, -33.0), "Safe anchor must advance to Exit anchor"):
		return
	
	# 9. State Save & Restore Audit
	var state_dict: Dictionary = room.get_state()
	if not _check(state_dict.get("mirror_inspected", false) and state_dict.get("override_done", false), "State missing mirror or override"):
		return
	if not _check(state_dict.get("gate_open", false), "State missing gate_open"):
		return
	
	print("PASS mirror chamber state: 28x36m hull bounds, mirror trigger, override gate, bilingual real-state telemetry and restoration; reflection art requires rendered review")
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
