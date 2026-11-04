extends SceneTree

var failures := 0
var checks := 0
var world: Node3D

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
	print("PASS " if ok else "FAIL ", message)

func box(size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	body.position = at
	world.add_child(body)
	return body

func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	var wall := box(Vector3(4,10,1), Vector3(0,5,-1))
	var player = load("res://scenes/player/echo_player.tscn").instantiate()
	world.add_child(player)
	player.finish_opening_recovery()
	player.set_physics_process(false)
	player.set_gameplay_orbit(Vector3.ZERO)
	for i in 3: await physics_frame
	for hz in [30,60]:
		Engine.physics_ticks_per_second = hz
		var dt: float = 1.0 / hz
		player.surface_motor.reset(player)
		player.surface_motor.latch_cooldown = 0
		player.position = Vector3(0,.5,.1)
		player.velocity = Vector3(0,3,-2)
		check(not player.surface_motor.tick(player,dt,Vector2.UP,false,false), "untagged wall rejects forward catch at " + str(hz))
		wall.add_to_group("climbable")
		player.velocity = Vector3(0,3,-2)
		check(not player.surface_motor.tick(player,dt,Vector2.UP,false,false), "ascending jump keeps its authored arc at " + str(hz))
		player.velocity = Vector3(0,3,0)
		check(not player.surface_motor.tick(player,dt,Vector2.UP,false,false), "no magnetic ascending catch without approach at " + str(hz))
		player.velocity = Vector3(0,-.1,-2)
		check(player.surface_motor.tick(player,dt,Vector2.UP,false,false) and player.traversal.is_climbing(), "jump approach plus forward attaches without second jump at " + str(hz))
		var start: Vector3 = player.position
		player.surface_motor.tick(player,dt,Vector2.UP,false,false)
		check(player.velocity.y > 0 and player.velocity.y < .5, "climb accelerates smoothly at " + str(hz))
		for i in hz:
			await physics_frame
			player.surface_motor.tick(player,dt,Vector2.UP,false,false)
		check(player.position.y > start.y + .5 and player.velocity.y <= 1.01, "holding forward climbs upward with bounded speed at " + str(hz))
		player.surface_motor.tick(player,dt,Vector2.ZERO,false,false)
		check(player.velocity.y > 0 and player.velocity.y < 1.0, "releasing forward brakes gradually at " + str(hz))
		player.surface_motor.tick(player,dt,Vector2.UP,false,true)
		check(not player.traversal.is_climbing() and player.surface_motor.latch_cooldown > .39, "drop releases contact and prevents immediate relatch at " + str(hz))
		wall.remove_from_group("climbable")
	world.queue_free()
	for i in 3: await process_frame
	print("CLIMB_FORWARD_REVIEW checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
