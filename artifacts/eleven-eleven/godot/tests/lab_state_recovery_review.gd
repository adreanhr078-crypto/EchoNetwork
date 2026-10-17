extends SceneTree

## Real laboratory transitions and save rollback. No account rewards or authored
## motion are changed by this fixture; graphical performance is a separate gate.
const LAB = preload("res://scenes/environment/dr_kinja_lab_room.tscn")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func frames(count: int) -> void:
	for i in count: await process_frame

func fresh() -> Node3D:
	var room: Node3D = LAB.instantiate()
	root.add_child(room)
	room.set_physics_process(false)
	room.campaign_decisions = true
	room.audio_muted = true
	return room

func prepare_breach(room: Node3D) -> void:
	room.reduced_motion = true
	check(room.initiate_memory_confrontation().success,"Confrontation refused fresh fixture")
	check(room.accept_zero_contract().success,"Explicit pact refused after manifestation")
	check(room.complete_revenge(),"Existing revenge transition refused")
	room.reduced_motion = false
	check(room.confirm_escape_wish("ESCAPE_SYSTEM_AT_ANY_COST"),"Explicit wish refused")

func dispose(room: Node3D) -> void:
	paused = false
	room.queue_free()
	await frames(3)

func _run() -> void:
	var room := fresh()
	var initial: Dictionary = room.get_state()
	check(not room._stasis_digits.visible and room._zero_light.light_energy==0.0 and room._stasis_light.light_energy==0.0,"Lab entry exposed a later Zero/stasis reveal")
	room.initiate_memory_confrontation()
	check(not room.get_state().confrontation_done,"Unfinished drowning became a durable completed memory")
	await create_timer(.12).timeout
	room.restore_state(initial)
	await create_timer(1.3).timeout
	check(room.state==room.RoomState.ENTRY_SURGICAL and not room.confrontation_done,"Old drowning callback manifested Zero after rollback")
	check(is_equal_approx(room._shizuka_pod.position.y,1.3) and is_equal_approx(room._yuki_pod.position.y,1.3),"Rollback left memory pods submerged")
	await dispose(room)

	room = fresh()
	var forged: Dictionary = room.get_state()
	forged.state = room.RoomState.BREACH_READY
	forged.breach_open = true
	forged.breach_pos_y = 5.2
	forged.breach_col_disabled = true
	room.restore_state(forged)
	await frames(3)
	check(not room.breach_open and not room._breach_shape.disabled and is_equal_approx(room._breach_portal.position.y,1.4),"Unconfirmed saved wish opened the physical laboratory exit")
	check(not room.contract_done and room.state==room.RoomState.ENTRY_SURGICAL,"Unconfirmed restored state exposed a later story phase")
	await dispose(room)

	room = fresh()
	initial = room.get_state()
	prepare_breach(room)
	await create_timer(.12).timeout
	room.restore_state(initial)
	await create_timer(.9).timeout
	check(not room._breach_shape.disabled and is_equal_approx(room._breach_portal.position.y,1.4),"Stale breach tween reopened a newer closed checkpoint")
	check(is_equal_approx(room._stasis_light.light_energy,0.0) and is_equal_approx(room._zero_light.light_energy,0.0) and not room._stasis_digits.visible,"Rollback retained a future stasis/Zero light or clock state")
	await dispose(room)

	for paused_case in [false,true]:
		room = fresh()
		prepare_breach(room)
		await create_timer(.12).timeout
		paused = paused_case
		room.reduced_motion = true
		await frames(3)
		check(is_equal_approx(room._breach_portal.position.y,5.2) and room._breach_shape.disabled,"Live Reduced Motion left breach incomplete; paused="+str(paused_case))
		await dispose(room)

	room = fresh()
	prepare_breach(room)
	await create_timer(.12).timeout
	var mid: Dictionary = room.get_state()
	check(room._stasis_digits.visible and room._stasis_light.light_energy==5.0,"Explicit escape wish did not reveal the stasis clock/light")
	var signals := [0,0]
	room.zero_contract_accepted.connect(func(): signals[0]+=1)
	room.exit_breach_opened.connect(func(): signals[1]+=1)
	room.restore_state(mid)
	check(is_equal_approx(room._breach_portal.position.y,mid.breach_pos_y) and not room._breach_shape.disabled,"Restoring mid-breach lost its saved closed collision/pose")
	await create_timer(.9).timeout
	check(is_equal_approx(room._breach_portal.position.y,5.2) and room._breach_shape.disabled,"Mid-breach restore failed to finish")
	check(signals==[0,0],"Restore replayed pact/exit progression signals")
	check(room.get_state().keys()==mid.keys(),"Recovery changed the existing durable room keys")
	# An older open collider must become solid during a newly started opening,
	# even when the restore and new explicit decisions share a frame.
	room.restore_state(initial)
	prepare_breach(room)
	await create_timer(.12).timeout
	check(not room._breach_shape.disabled and room._breach_portal.position.y<5.2,"Restore/new-opening race exposed a moving portal")
	await dispose(room)

	for paused_case in [false,true]:
		room = fresh()
		var manifested := [0]
		room.zero_manifested.connect(func(): manifested[0]+=1)
		room.initiate_memory_confrontation()
		room.initiate_memory_confrontation()
		await create_timer(.12).timeout
		paused = paused_case
		room.reduced_motion = true
		await frames(3)
		check(room.confrontation_done and room.state==room.RoomState.ZERO_MANIFESTED and manifested==[1],"Live RM failed to settle drowning exactly once; paused="+str(paused_case))
		await dispose(room)
	# Argon review: run the room's real physics with a grounded-position subject.
	room = fresh()
	room.reduced_motion = true
	room.initiate_memory_confrontation()
	var manifested_save:Dictionary=room.get_state()
	manifested_save.current_anchor=room.SAFE_ANCHOR_ENTRY
	room.restore_state(manifested_save)
	var subject:=Node3D.new()
	room.add_child(subject)
	subject.position=Vector3(0,0,-7)
	room.player=subject
	room.set_physics_process(true)
	for i in 3: await physics_frame
	check(room.state==room.RoomState.ZERO_MANIFESTED and room.request_contract_decision().get("success",false),"Live physics overwrote restored manifestation and blocked the explicit pact")
	await dispose(room)

	room = fresh()
	var bad_anchor:Dictionary=room.get_state()
	bad_anchor.current_anchor=room.SAFE_ANCHOR_CONTRACT
	room.restore_state(bad_anchor)
	check(room.current_anchor==room.SAFE_ANCHOR_ENTRY,"Unfinished memory accepted a future contract respawn anchor")
	bad_anchor.current_anchor=Vector3(NAN,0,0)
	room.restore_state(bad_anchor)
	check(room.current_anchor==room.SAFE_ANCHOR_ENTRY,"Invalid respawn vector survived restore")
	bad_anchor.current_anchor=room.SAFE_ANCHOR_THEATER
	room.restore_state(bad_anchor)
	check(room.state==room.RoomState.THEATER_CONFRONTATION,"Restored theater anchor lost its pre-memory stage")
	await dispose(room)

	room = fresh()
	initial=room.get_state()
	room.memory_confrontation_started.connect(func():room.restore_state(initial))
	room.initiate_memory_confrontation()
	await create_timer(1.3).timeout
	check(not room.confrontation_done and is_equal_approx(room._yuki_pod.position.y,1.3) and is_equal_approx(room._shizuka_pod.position.y,1.3),"Synchronous start-listener rollback was overwritten by drowning motion")
	await dispose(room)

	room = fresh()
	initial=room.get_state()
	var obsolete_manifestations:=[0]
	room.memory_drowning_completed.connect(func():room.restore_state(initial))
	room.zero_manifested.connect(func():obsolete_manifestations[0]+=1)
	room.reduced_motion=true
	room.initiate_memory_confrontation()
	check(obsolete_manifestations[0]==0 and not room.confrontation_done and is_equal_approx(room._zero_light.light_energy,0.0),"Synchronous completion-listener rollback still emitted Zero or overwrote restored light")
	await dispose(room)
	print("Laboratory recovery review failures=",failures,"; unfinished memory, stale callbacks, explicit decisions, paused live RM, live physics, anchors, synchronous rollback and silent mid-breach continuation")
	quit(1 if failures else 0)
