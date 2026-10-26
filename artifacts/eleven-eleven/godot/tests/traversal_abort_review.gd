extends SceneTree

var world: Node3D
var actor: EchoPlayer
var completions: Array = []

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	var wall := _wall()
	actor = load("res://scenes/player/echo_player.tscn").instantiate()
	actor.position = Vector3(0, 1.9, 0.025)
	world.add_child(actor)
	actor.finish_opening_recovery()
	actor.surface_traversal_enabled = true
	actor.set_physics_process(false)
	actor.surface_motor.mantle_completed.connect(func(): completions.append(true))
	await _steps(3)
	actor.velocity = Vector3.DOWN
	if not _check(actor.surface_motor.tick(actor, 1.0 / 60, Vector2(0,-1), false, false) and actor.surface_motor.hanging, "real airborne catch failed"): return
	actor.set_physics_process(true)
	await _steps(4)
	var position_before := actor.global_position
	var stamina_before := actor.stamina
	var clock_before := actor.animation_player.current_animation_position
	paused = true
	for i in 8: await process_frame
	if not _check(actor.global_position == position_before and actor.stamina == stamina_before and actor.animation_player.current_animation_position == clock_before, "pause advanced hanging body/contact/clock"): return
	paused = false
	await _steps(3)
	if not _check(actor.surface_motor.hanging and actor.global_position.distance_to(position_before) < .002, "resume detached or moved the hanging body"): return
	# A newly loaded wall at the same position is a different support. It must
	# not inherit a stale hand anchor from a scene that has been unloaded.
	actor.set_physics_process(false)
	wall.free()
	_wall()
	await _steps(3)
	actor.surface_motor.tick(actor, 1.0 / 60, Vector2.ZERO, false, false)
	if not _check(not actor.surface_motor.hanging and not actor.traversal.is_climbing() and actor.velocity.y < 0 and completions.is_empty(), "unloaded support silently transferred the hand anchor to new geometry"): return
	if not _check(not actor.contract_with_zero_sealed and not actor.combat_available and not actor.shadow_step_unlocked, "traversal abort granted a story state"): return
	print("PASS hanging abort: pause/resume clocks, unloaded/replaced support releases into gravity, no mantle completion or early powers")
	world.queue_free()
	await _steps(3)
	quit(0)

func _wall() -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.position = Vector3(0, 1.7, -1.4)
	wall.add_to_group("climbable")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2,3.4,2)
	collision.shape = shape
	wall.add_child(collision)
	world.add_child(wall)
	return wall

func _steps(count: int) -> void:
	for i in count: await physics_frame

func _check(ok: bool, detail: String) -> bool:
	if ok: return true
	paused = false
	push_error(detail)
	world.queue_free()
	quit(1)
	return false
