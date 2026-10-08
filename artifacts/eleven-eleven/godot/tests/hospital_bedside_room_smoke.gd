extends SceneTree

const ROOM_SCENE = preload("res://scenes/environment/hospital_bedside_room.tscn")
const PLAYER_SCENE = preload("res://scenes/player/echo_player.tscn")

var room: Node3D
var player: EchoPlayer

var bed_awakened_fired := false
var mark_revealed_fired := false
var chapter_completed_fired := false
var safe_anchor_updated_fired := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("--- Starting Room 12: Hospital Bedside Awakening Smoke Test ---")
	
	# 1. Instantiate Room Scene
	room = ROOM_SCENE.instantiate()
	if not _check(room != null, "Failed to instantiate hospital_bedside_room.tscn"):
		return
	root.add_child(room)
	
	for i in range(4):
		await process_frame
	
	# 2. Structural & Architectural Audit (Watertight Hull: 6.4m x 5.8m x 3.2m)
	var floor_body := room.get_node_or_null("Floor") as StaticBody3D
	var ceiling_body := room.get_node_or_null("Ceiling") as StaticBody3D
	var north_wall := room.get_node_or_null("NorthWall") as StaticBody3D
	var south_wall := room.get_node_or_null("SouthWallBelowWindow") as StaticBody3D
	var west_wall := room.get_node_or_null("WestWall") as StaticBody3D
	var east_wall := room.get_node_or_null("EastWall") as StaticBody3D
	var furniture := room.get_node_or_null("WardFurniture")
	var bed_body := furniture.get_node("Mattress").get_child(0) as StaticBody3D
	var cabinet_body := furniture.get_node("BedsideCabinet").get_child(0) as StaticBody3D
	var window_barrier := room.get_node_or_null("WindowGlassBarrier") as StaticBody3D
	var mirror_station := room.get_node_or_null("VanityMirrorStation") as StaticBody3D
	var clock_label := room.get_node_or_null("DigitalClock1111") as Label3D
	var exit_door := room.get_node_or_null("WardExitDoor") as StaticBody3D
	
	if not _check(floor_body and ceiling_body and north_wall and south_wall and west_wall and east_wall, "Missing hermetic hull envelope components"):
		return
	if not _check(bed_body and cabinet_body and window_barrier and mirror_station and exit_door, "Missing essential ward furniture components"):
		return
	if not _check(clock_label and clock_label.text == "11:11", "Digital clock 11:11 missing or incorrect time display"):
		return
	if not _check(furniture.has_node("MonitorGlass") and furniture.has_node("StaticMonitorTrace"), "Authored monitor screen and trace must be present"):
		return
	if not _check(room.has_node("SouthWallAboveWindow") and room.has_node("WardMirrorReflection"), "Window aperture and actual inspection reflection must be present"):
		return
	# Verify actual collision coverage through the daylight aperture, bedside
	# furniture and all six hull directions, rather than checking node names alone.
	await physics_frame
	var space := room.get_world_3d().direct_space_state
	for destination in [Vector3(8,1.85,0),Vector3(-8,1.85,0),Vector3(0,8,0),Vector3(0,-2,0),Vector3(0,1.85,8),Vector3(0,1.85,-8)]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(0,1.85,0),destination,1)
		if not _check(not space.intersect_ray(query).is_empty(), "Ward hull must block escape, including the window aperture"):
			return
	var bed_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-1,2,0),Vector3(-1,0.1,0),1))
	if not _check(bed_hit.get("collider")==bed_body, "Mattress needs real collision, not only a visual"):
		return
	
	# Verify room floor dimensions (6.4m x 5.8m)
	var floor_col: CollisionShape3D = floor_body.get_node("CollisionShape3D")
	var floor_box: BoxShape3D = floor_col.shape as BoxShape3D
	if not _check(is_equal_approx(floor_box.size.x, 6.4), "Room width must be 6.4m"):
		return
	if not _check(is_equal_approx(floor_box.size.z, 5.8), "Room length must be 5.8m"):
		return
	
	# Connect signals
	room.bed_awakened.connect(func(): bed_awakened_fired = true)
	room.ex011_mark_revealed.connect(func(): mark_revealed_fired = true)
	room.chapter_1_completed.connect(func(): chapter_completed_fired = true)
	room.safe_anchor_updated.connect(func(_a): safe_anchor_updated_fired = true)
	
	# 3. Spawn Player at Bedside Awakening Position (Vector3(-0.30, 0.1, 1.18))
	player = PLAYER_SCENE.instantiate()
	player.position = Vector3(-0.30, 0.1, 1.18)
	root.add_child(player)
	player.finish_opening_recovery()
	room.player = player
	
	for i in range(10):
		await physics_frame
	
	if not _check(player.is_on_floor(), "Player failed to ground on hospital ward floor"):
		return
	
	# 4. Check Initial Safe Anchor
	var anchor_bedside: Vector3 = room.get_safe_anchor()
	if not _check(is_equal_approx(anchor_bedside.x, -0.30) and is_equal_approx(anchor_bedside.z, 1.18), "Initial safe anchor must be bedside anchor (-0.30, 0.0, 1.18)"):
		return
	
	# 5. Trigger Bed Awakening Transition
	var wake_ok: bool = room.wake_up_from_bed()
	if not _check(wake_ok and bed_awakened_fired, "Bed awakening transition failed"):
		return
	
	# 6. Move Player to Vanity Mirror Station (Vector3(1.80, 0.1, -1.0))
	player.position = Vector3(1.80, 0.1, -1.0)
	for i in range(8):
		await physics_frame
	
	var anchor_mirror: Vector3 = room.get_safe_anchor()
	if not _check(is_equal_approx(anchor_mirror.x, 1.80) and is_equal_approx(anchor_mirror.z, -1.00), "Safe anchor must advance monotonically to Mirror Station"):
		return
	if not _check(safe_anchor_updated_fired, "safe_anchor_updated signal must fire when moving to mirror"):
		return
	
	# 7. Interact with Mirror Station to Reveal EX-011 Mark and Complete Chapter 1
	var mirror_res: Dictionary = mirror_station.trigger_interaction(player)
	if not _check(mirror_res.get("success", false) == true and mirror_res.get("label", "") == "EX-011", "Mirror interaction failed to reveal EX-011 mark"):
		return
	if not _check(mark_revealed_fired, "ex011_mark_revealed signal did not fire"):
		return
	if not _check(chapter_completed_fired, "chapter_1_completed signal did not fire"):
		return
	
	# 8. State Save & Restore Audit
	var state_dict: Dictionary = room.get_state()
	if not _check(state_dict.get("bed_awakened", false) and state_dict.get("mark_revealed", false), "State missing bed_awakened or mark_revealed"):
		return
	if not _check(state_dict.get("chapter_completed", false), "State missing chapter_completed"):
		return
	if not _check(state_dict.get("clock_time", "") == "11:11", "State missing clock_time 11:11"):
		return
	
	# Test restoration
	var restore_ok: bool = room.restore_state(state_dict)
	if not _check(restore_ok, "State restoration failed"):
		return
	
	print("PASS hospital bedside state and collision: sealed ward/window, mattress collider, explicit wake, mirror gate, mark and checkpoint. Skeletal bedside performance remains unverified.")
	
	# Cleanup without leaks
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
