extends SceneTree
## Real-clock overlapping hit/dodge leases through the existing world manager.
class Actor extends Node:
	var combat_available := true
	var reduced_motion := false
	var control_locked := false
var checks := 0
var failures: Array[String] = []
var world: Node
var actor: Actor
var folder := ""
var waits: Array = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
	print("PASS " if ok else "FAIL ",label," actual_scale=",Engine.time_scale)
func real_wait(seconds: float) -> void:
	var start := Time.get_ticks_usec()
	# A timer created in the initial deferred frame consumed that frame's old
	# accumulated delta (70ms request returned in0.267ms). Measure the same
	# monotonic real clock as the lease,then allow the manager's process tick.
	while Time.get_ticks_usec()-start < int(seconds*1000000.0): await process_frame
	await process_frame
	waits.append({"requested_seconds":seconds,"elapsed_real_seconds":float(Time.get_ticks_usec()-start)/1000000.0,"scale_after":Engine.time_scale})
func frames() -> void:
	await process_frame
	await process_frame
func request(kind: String,factor: float,seconds: float) -> bool:
	return world.request_combat_time_effect(actor,kind,factor,seconds)
func run() -> void:
	folder=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(folder)
	world=get_root().get_node("HyperAnimeWorldManager")
	actor=Actor.new();root.add_child(actor)
	Engine.time_scale=.8
	check(request("hit_stop",.12,.04),"Hit stop acquires a bounded existing-world lease")
	check(request("perfect_dodge",.2,.18) and is_equal_approx(Engine.time_scale,.096),"Overlapping dodge never compounds or overwrites hit stop")
	await real_wait(.07)
	check(is_equal_approx(Engine.time_scale,.16),"Hit expiry reveals the still-active dodge over the original0.8base")
	await real_wait(.15)
	check(is_equal_approx(Engine.time_scale,.8),"Last effect restores the original nondefault time scale")
	request("perfect_dodge",.2,.04)
	await real_wait(.015)
	request("hit_stop",.12,.09)
	await real_wait(.05)
	check(is_equal_approx(Engine.time_scale,.096),"Dodge expiry cannot prematurely release a newer hit stop")
	await real_wait(.08)
	check(is_equal_approx(Engine.time_scale,.8),"Reverse overlap restores its original base")
	request("hit_stop",.12,.12)
	paused=true;await frames()
	check(is_equal_approx(Engine.time_scale,.8),"Pause releases combat time in the next process frame")
	check(not request("hit_stop",.12,.12),"Paused world rejects a new time lease")
	paused=false
	request("hit_stop",.12,.12)
	actor.reduced_motion=true;await frames()
	check(is_equal_approx(Engine.time_scale,.8),"Actor Reduced Motion clears its active time effect")
	actor.reduced_motion=false
	request("hit_stop",.12,.12)
	world.set_reduced_motion(true)
	check(is_equal_approx(Engine.time_scale,.8),"Live world Reduced Motion releases time synchronously")
	world.set_reduced_motion(false)
	request("hit_stop",.12,.12)
	actor.control_locked=true;await frames()
	check(is_equal_approx(Engine.time_scale,.8),"Cinematic control ownership releases combat time")
	actor.control_locked=false
	request("hit_stop",.12,.12)
	actor.combat_available=false;await frames()
	check(is_equal_approx(Engine.time_scale,.8),"Combat revocation releases its lease")
	actor.combat_available=true
	request("hit_stop",.12,.12)
	Engine.time_scale=.6;await frames();await real_wait(.15)
	check(is_equal_approx(Engine.time_scale,.6),"An external time owner is preserved without a stale restoration")
	Engine.time_scale=.8
	request("hit_stop",.12,.12)
	actor.queue_free();await frames()
	check(is_equal_approx(Engine.time_scale,.8),"Actor unload leaves no time-scale leak")
	actor=Actor.new();root.add_child(actor)
	check(not request("unknown",.12,.1) and not request("hit_stop",NAN,.1),"Unknown and nonfinite requests are refused")
	actor.queue_free();Engine.time_scale=1.0
	var file:=FileAccess.open(folder.path_join("review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"waits":waits,"scope":"Actual world-manager real-clock lease ownership and cancellation;no gameplay grant or visual acceptance."},"\t"))
	quit(0 if failures.is_empty() else 1)
