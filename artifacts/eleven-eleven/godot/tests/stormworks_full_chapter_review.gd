extends "res://tests/full_chapter_journey_review.gd"

## Fresh awakening through the existing chapter, including the new Room02 route.
## No opening fixture, actor teleport, synthesized traversal or completion receipt.
const Pilot = preload("res://tests/stormworks_course_pilot.gd")
const RoomSave = preload("res://scripts/systems/stormworks_checkpoint.gd")
var parkour: RefCounted

func _maintenance_route() -> bool:
	var director = main.get_node("SystemJourneyPreview")
	if not _check(is_instance_valid(director.room) and director.has_method("has_confirmed_room_checkpoint"),"New Room02 is not active in the production main scene"):return false
	room = director.room
	# Walk through the actual entrance aperture before the diagonal first grip.
	for point in [Vector3(0,.1,-2.8),Vector3(-1.15,.1,-3.4)]:
		if not await _walk(room.to_global(point)):return false
	parkour = Pilot.new()
	parkour.tree = self;parkour.world = main;parkour.room = room;parkour.player = player
	parkour.capture_directory = folder.path_join("stormworks")
	DirAccess.make_dir_recursive_absolute(parkour.capture_directory)
	await parkour._exercise_course()
	for row in parkour.report.checks:
		if not _check(row.get("pass",false),"Connected new Room02: "+row.check):return false
	await _frames(15)
	if not _check(director.stage == 5 and director.has_confirmed_room_checkpoint(),"Fresh parkour did not earn the confirmed service checkpoint"):return false
	var earned_dir := folder.path_join("earned/room02-stage5")
	DirAccess.make_dir_recursive_absolute(earned_dir)
	if not _check(DirAccess.copy_absolute(director.checkpoint_path,earned_dir.path_join("maintenance.json")) == OK,"Cannot preserve fresh earned Room02 checkpoint"):return false
	if not _check(await parkour._go_to(room.service_floor_anchor),"Fresh route did not reach pressure wheel"):return false
	if not _check(player.get_nearest_interactable() == room.service_interaction,"Real pressure wheel is not nearest"):return false
	if not _check(player.interact_with_nearest().get("data",{}).get("released",false),"Real service interaction rejected"):return false
	await _frames(225)
	if not _check(room.service_open and director.stage == 6 and director.has_confirmed_room_checkpoint() and not player.control_locked,"Pressure sequence/save/control return failed"):return false
	for point in [Vector3(0,5.6,-17.6),Vector3(0,5.6,-18.85),Vector3(0,5.6,-19.4)]:
		if not _check(await parkour._go_to(point),"Connected service exit blocked: "+str(point)):return false
	await _frames(12)
	if not _check(director.stage == 7 and RoomSave.read(director.checkpoint_path).get("stage") == 7 and main.get_node("NativeJourneyController").security_entered,"Actual Room02 exit did not save and hand off"):return false
	var record := FileAccess.open(folder.path_join("stormworks-connected.json"),FileAccess.WRITE)
	record.store_string(JSON.stringify({"scope":"Fresh actual-input opening-to-Room02 route;no relocation after spawn","checks":parkour.report.checks,"maintenance_sha256":FileAccess.get_sha256(director.checkpoint_path),"room_source_sha256":FileAccess.get_sha256("res://scripts/environment/maintenance_stormworks.gd"),"visual_sha256":FileAccess.get_sha256("res://assets/environments/maintenance_stormworks/stormworks_original_pbr_metric_v8.glb")},"\t"));record.close()
	await _capture("room02-new-completed")
	return true

func _security_route() -> bool:
	var controller = main.get_node("NativeJourneyController")
	var security = controller.security
	var offset: Vector3 = controller.downstream_offset
	if not await _walk(Vector3(-3.5,5.4,-33.8)+offset):return false
	if not _check(player.get_nearest_interactable() == security.get_node("DivertStation/InteractionArea"),"Diversion unreachable after new Room02"):return false
	player.interact_with_nearest()
	await _frames(4)
	if not _check(controller.progress.security.scanner_trace and not security.gate_open,"Diversion failed to persist independently"):return false
	for point in [Vector3(-3.5,5.4,-40.5),Vector3(-3.5,5.4,-46.8),Vector3(-1.3,5.4,-47.2)]:
		if not await _walk(point+offset):return false
	if not _check(player.get_nearest_interactable() == security.get_node("GateStation/InteractionArea"),"Manual security latch unreachable"):return false
	player.interact_with_nearest()
	await _frames(65)
	if not _check(security.gate_open and controller.progress.security.gate_open,"Manual latch/save failed"):return false
	for point in [Vector3(0,5.4,-47.4),Vector3(0,5.4,-49.45)]:
		if not await _walk(point+offset):return false
	await _frames(8)
	if not _check(controller.progress.completed.has("security_completed") and not player.combat_available,"Physical security exit missing or premature combat"):return false
	await _capture("room03-new-offset-completed")
	return true
