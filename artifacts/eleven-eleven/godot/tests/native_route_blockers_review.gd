extends "res://tests/room_route_input_review.gd"

## Actual authored room collision and the active avatar's public input. Each
## case has one fixture spawn; traversal never assigns its position again.
const CampaignController=preload("res://scripts/systems/native_campaign_controller.gd")
var observations: Dictionary={}
var sources: Dictionary={}
const FILES: Array[String]=[
	"res://scripts/environment/mirror_chamber_room.gd",
	"res://scripts/environment/memory_archive_wing.gd",
	"res://scripts/environment/security_checkpoint_room.gd",
	"res://scripts/systems/native_campaign_controller.gd",
	"res://scripts/systems/native_campaign_checkpoint.gd",
	"res://scripts/player/surface_traversal_motor.gd",
	"res://scripts/player/echo_player.gd",
	"res://scenes/player/echo_player.tscn",
	"res://assets/characters/echo_opening_uniform_v13.glb",
	"res://tests/room_route_input_review.gd",
	"res://tests/native_route_blockers_review.gd"
]

func _run() -> void:
	root.unfocusable=true
	for path in FILES: sources[path]=FileAccess.get_sha256(path)
	var args:=OS.get_cmdline_user_args()
	var selected:=args[0] if not args.is_empty() else "all"
	if selected in ["all","mirror"] and not await _mirror_order(): return
	if selected in ["all","archive"] and not await _archive_climb(): return
	if selected in ["all","security"] and not await _security_restore(): return
	for path in sources:
		if not _check(sources[path]==FileAccess.get_sha256(path),"Route probe dependency changed during execution: "+path): return
	var folder:=ProjectSettings.globalize_path("res://../audits/evidence/room-color-cinematics-20261007/native-route-blockers-20261009/")
	DirAccess.make_dir_recursive_absolute(folder)
	var report:=FileAccess.open(folder+selected+".json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"status":"ACTUAL_PUBLIC_INPUT_REACHABILITY_PASS_VISUAL_AND_DEVICE_REVIEW_REQUIRED","engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"observations":observations,"source_fingerprint":sources},"\t"))
	report.close()
	print("PASS actual authored room input blockers: ",JSON.stringify(observations))
	quit(0)

func _spawn_case(scene: String, start: Vector3) -> void:
	room=load("res://scenes/environment/"+scene+".tscn").instantiate()
	room.position=Vector3(23,6,-48)
	room.reduced_motion=true
	if "audio_muted" in room: room.audio_muted=true
	root.add_child(room)
	if room.has_method("set_audio_muted"): room.set_audio_muted(true)
	player=load("res://scenes/player/echo_player.tscn").instantiate()
	player.position=room.to_global(start)
	root.add_child(player)
	player.finish_opening_recovery()
	player.set_gameplay_orbit(Vector3.ZERO)
	room.player=player
	for frame in 20: await physics_frame

func _dispose_case() -> void:
	player.set_mobile_input_vector(Vector2.ZERO,false)
	room.player=null
	player.queue_free()
	room.queue_free()
	for frame in 8: await process_frame
	await create_timer(0.12).timeout

func _mirror_order() -> bool:
	review_kind="mirror-order"
	await _spawn_case("mirror_chamber_room",Vector3(0,0.1,-2))
	# The route outside the east mirror's trigger reaches the same real dais.
	for point in [Vector3(11,0,-2),Vector3(11,0,-14),Vector3(8,0,-14),Vector3(8,0,-16.6),Vector3(3.5,2.4,-16.6),Vector3(1.5,2.4,-18)]:
		if not await _walk(point): return false
	if not _check(not room.mirror_inspected,"Bypass fixture accidentally entered the actual mirror trigger"): return false
	if not _use("MasterSecurityTerminal"): return false
	for frame in 6: await physics_frame
	if not _check(room.override_done and not room.gate_open and not room._gate_shape.disabled,"Override-only terminal opened an exit the durable route cannot accept"): return false
	if not _check(room._telemetry.get_node("Readout1").text.contains("مقفل"),"Telemetry advertised a locked physical gate as open"): return false
	# Exercise the real cold room adapter with the same incomplete two flags.
	var controller:=CampaignController.new()
	for index in 4: controller.rooms.append(Node3D.new())
	controller.rooms.append(room)
	controller.progress.flags["mirror"]={"override_done":true,"mirror_inspected":false}
	controller._restore_room(4)
	for frame in 4: await physics_frame
	if not _check(not room.gate_open and not room.mirror_inspected and not room._gate_shape.disabled,"Restore adapter bypassed the physical mirror prerequisite"): return false
	for index in 4: controller.rooms[index].free()
	controller.free()
	# Return via the same stairs and physically inspect; no flag is assigned.
	for point in [Vector3(3.5,2.4,-16.6),Vector3(8,0,-16.6),Vector3(8,0,-14),Vector3(7.2,0,-14),Vector3(7.2,0,-10)]:
		if not await _walk(point): return false
	for frame in 5: await physics_frame
	if not _check(room.mirror_inspected and room.override_done and room.gate_open and room._gate_shape.disabled,"Physical mirror inspection did not release the already-authorized override"): return false
	if not _check(not player.combat_available and not player.contract_with_zero_sealed,"Human mirror route granted an early pact or weapon"): return false
	observations.mirror={"actual_terminal_before_inspection":true,"gate_stays_closed":true,"cold_adapter_stays_closed":true,"physical_inspection_then_opens":true,"no_early_power":true}
	await _dispose_case()
	return true

func _archive_climb() -> bool:
	review_kind="archive-climb"
	await _spawn_case("memory_archive_wing",Vector3(-4.0,0.1,-6.5))
	var tower:=room.get_node("NorthRack_6") as StaticBody3D
	if not _check(tower.is_in_group("climbable"),"Actual archive tower collider is not recognized by the surface motor"): return false
	for rung in 10:
		if not _check(not room.get_node("NorthRack_6_Rung_%d" % rung) is PhysicsBody3D,"Decorative rung interrupts continuous hand/capsule wall support"): return false
	player.set_gameplay_orbit(Vector3(0,PI/2,0))
	for frame in 8: await physics_frame
	var initial_height:=player.global_position.y
	player.set_mobile_input_vector(Vector2(0,-1),true)
	var latched:=false
	for frame in 140:
		await physics_frame
		latched=latched or player.traversal.is_climbing()
		if player.global_position.y-initial_height>1.3: break
	if not _check(latched and player.traversal.is_climbing() and player.global_position.y-initial_height>1.1,"Actual forward public input did not climb across the archive's rung heights"): return false
	player.set_mobile_input_vector(Vector2.ZERO,true)
	var held:=player.global_position
	for frame in 10: await physics_frame
	if not _check(player.traversal.is_climbing() and player.global_position.distance_to(held)<0.08,"Neutral archive climb drifted or dropped at a decorative rung seam"): return false
	# Roll is the public Drop action while on an authored climbable surface.
	player.request_dodge()
	for frame in 3: await physics_frame
	if not _check(not player.traversal.is_climbing() and player.surface_motor.latch_cooldown>0.3,"Public Drop did not release the archive wall with its existing lockout"): return false
	observations.archive={"continuous_tagged_rack_collider":true,"public_input_latched":true,"climb_height":held.y-initial_height,"neutral_holds":true,"public_drop_lockout":true,"animation_quality":"UNVERIFIED"}
	await _dispose_case()
	return true

func _security_restore() -> bool:
	review_kind="security-exit-restore"
	await _spawn_case("security_checkpoint_room",Vector3(0,0.1,-17.4))
	var counters: Dictionary={"retry":0,"passage":0,"peak_warning":0.0}
	room.retry_requested.connect(func(_anchor: Vector3) -> void: counters.retry+=1)
	room.passage_ready.connect(func() -> void: counters.passage+=1)
	room.restore_state({"gate_open":true,"scanner_trace":true,"service_trace":false})
	for frame in 180:
		await physics_frame
		counters.peak_warning=maxf(counters.peak_warning,room.warning)
	if not _check(counters.retry==0 and counters.passage==1 and room._passage_reported and player.is_on_floor(),"Completed security exit restore retried or repeated its grounded passage"): return false
	observations.security={"actual_exit_anchor":room.to_local(player.global_position),"retry_count":counters.retry,"passage_count":counters.passage,"peak_warning":counters.peak_warning,"reported_retry_allegation":"NOT_REPRODUCED"}
	await _dispose_case()
	return true
