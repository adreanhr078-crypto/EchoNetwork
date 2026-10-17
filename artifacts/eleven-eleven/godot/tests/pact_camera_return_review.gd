extends SceneTree

class MainFixture extends Node:
	var player:EchoPlayer
	func _release_gameplay_modal_controls()->void:player.control_locked=false

const Presentation=preload("res://scripts/cinematics/pact_revenge_presentation.gd")
var failures:=0
func _initialize()->void:_run.call_deferred()
func check(ok:bool,message:String)->void:
	if not ok:
		failures+=1
		push_error(message)
func steps(count:int)->void:
	for i in count:
		await physics_frame
		await process_frame
func return_camera(player:EchoPlayer,main:Node)->Node3D:
	# Exercise the real immediate-return endpoint without building unrelated
	# laboratory art. The rendered connected review separately covers its wiring.
	var insert=Presentation.new()
	insert.main=main
	insert._previous=player.player_camera
	insert._kind="revenge"
	insert.active=true
	insert.finish(true)
	return insert

func _run()->void:
	var world:=Node3D.new()
	root.add_child(world)
	var main:=MainFixture.new()
	root.add_child(main)
	var player:EchoPlayer=load("res://scenes/player/echo_player.tscn").instantiate()
	player.position=Vector3(0,2,0)
	world.add_child(player)
	main.player=player
	player.finish_opening_recovery()
	player.set_physics_process(false)
	player.set_process(false)
	player.reduced_camera_motion=true
	player.set_gameplay_orbit(Vector3.ZERO)
	var actor:=StaticBody3D.new()
	actor.name="CloseKinjaCapsule"
	var shape:=CollisionShape3D.new()
	var capsule:=CapsuleShape3D.new()
	capsule.radius=.45
	capsule.height=1.9
	shape.shape=capsule
	actor.add_child(shape)
	actor.position=player.position+Vector3(0,.95,.85)
	world.add_child(actor)
	await steps(3)
	for i in 30:player._process(1.0/60.0)
	var blocked:float=player.camera_boom.spring_length
	check(blocked<.85,"Fixture did not reproduce the close-actor camera retraction")
	var mask:int=player.camera_boom.collision_mask
	var cull:int=player.player_camera.cull_mask
	var insert=return_camera(player,main)
	for i in 30:
		player._process(1.0/60.0)
		insert._process(1.0/60.0)
	check(player.camera_boom.spring_length>=.85,"Actual pact return left the camera inside the player silhouette")
	check(absf(player.camera_target_rotation.y)<=PI/2+.001 and is_zero_approx(player.camera_target_rotation.x),"Return discarded pitch or exceeded its bounded yaw correction")
	check(player.camera_boom.collision_mask==mask and player.player_camera.cull_mask==cull and actor.collision_layer==1,"Camera return weakened world collision or hid rendered geometry")
	check(is_zero_approx(insert._clearance_settle_remaining),"Camera correction outlived its bounded handoff window")
	insert.free()
	actor.queue_free()
	await steps(3)
	player.set_gameplay_orbit(Vector3(.12,.71,0))
	for i in 30:player._process(1.0/60.0)
	insert=return_camera(player,main)
	check(player.camera_target_rotation.is_equal_approx(Vector3(.12,.71,0)),"Unobstructed return changed the owner's live orbit")
	player.set_gameplay_orbit(Vector3(.12,-.6,0))
	insert._process(.016)
	check(player.camera_target_rotation.is_equal_approx(Vector3(.12,-.6,0)) and is_zero_approx(insert._clearance_settle_remaining),"Bounded return fought a deliberate camera look")
	insert.free()
	world.queue_free()
	main.queue_free()
	await steps(4)
	print("Pact camera return failures=",failures,"; reproduced close-actor retraction, real return endpoint, bounded yaw, preserved pitch/masks/geometry and unchanged clear orbit")
	quit(1 if failures else 0)
