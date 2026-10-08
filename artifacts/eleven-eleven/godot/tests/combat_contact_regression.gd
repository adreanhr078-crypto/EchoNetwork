extends SceneTree
class Target extends StaticBody3D:
	var hits := 0
	func _ready() -> void: add_to_group("damageable")
	func take_damage(_amount: int) -> void: hits+=1
var player: EchoPlayer
func _initialize() -> void: _run.call_deferred()
func _steps(count: int) -> void:
	for i in count: await physics_frame
func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
func _body(position: Vector3, size: Vector3, target := false) -> StaticBody3D:
	var body := Target.new() if target else StaticBody3D.new()
	body.position=position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=size
	collision.shape=shape
	collision.position.y=size.y*0.5
	body.add_child(collision)
	root.add_child(body)
	return body
func _run() -> void:
	_body(Vector3(-20,-0.2,-20),Vector3(80,0.2,80))
	player=load("res://scenes/player/echo_player.tscn").instantiate()
	root.add_child(player)
	player.finish_opening_recovery()
	player.set_combat_available(true)
	await _steps(20)
	player.visual_root.rotation.y=0
	var front := _body(player.global_position+Vector3(1.8,0,0),Vector3(0.4,1.8,0.4),true) as Target
	var rear := _body(player.global_position+Vector3(-1.8,0,0),Vector3(0.4,1.8,0.4),true) as Target
	player.perform_attack()
	var sequence := player._attack_sequence
	for i in 15: player.perform_attack()
	if not _check(front.hits==0 and rear.hits==0 and player._attack_sequence==sequence,"Attack spam bypassed windup or recovery"): return
	await _steps(100)
	if not _check(front.hits==1 and rear.hits==0,"Melee must hit once in front, never behind"): return
	front.queue_free()
	rear.queue_free()
	await _steps(5)
	player.visual_root.rotation.y=0
	var blocked := _body(player.global_position+Vector3(1.9,0,0),Vector3(0.4,1.8,0.4),true) as Target
	var wall := _body(player.global_position+Vector3(0.9,0,0),Vector3(0.2,3.0,4.0))
	player.perform_attack()
	await _steps(100)
	if not _check(blocked.hits==0,"Melee hit through a solid wall"): return
	wall.queue_free()
	await _steps(5)
	player.perform_attack()
	player.request_dodge()
	await _steps(100)
	if not _check(blocked.hits==0,"Canceled melee still damaged target during the roll"): return
	player.perform_attack()
	player.set_combat_available(false)
	await _steps(100)
	if not _check(blocked.hits==0,"Revoked combat still dealt damage"): return
	print("PASS actual melee: windup, one contact, recovery, facing cone, solid cover, dodge cancel, revoked authority")
	player.queue_free()
	blocked.queue_free()
	await _steps(3)
	quit()
