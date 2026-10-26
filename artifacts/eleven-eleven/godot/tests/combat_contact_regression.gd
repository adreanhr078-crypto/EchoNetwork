extends SceneTree
class Target extends StaticBody3D:
	var hits := 0
	func _ready() -> void: add_to_group("damageable")
	func take_damage(_amount: int) -> void: hits+=1
class TargetPart extends Node3D:
	var hits := 0
	func _ready() -> void: add_to_group("damageable")
	func take_damage(_amount: int) -> void: hits+=1
var player: EchoPlayer
func _initialize() -> void: _run.call_deferred()
func _steps(count: int) -> void:
	for i in count: await physics_frame
func _settle_attack() -> void:
	for i in 240:
		await physics_frame
		if player._attack_recovery<=0.0 and not player.is_attacking:return
	_check(false,"Native attack failed to leave recovery within its bounded physics window")
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
	var forward: Vector3 = (player.visual_root.global_basis * player.model_local_forward).normalized()
	var wall_size := Vector3(4, 3, .2) if absf(forward.z) > .5 else Vector3(.2, 3, 4)
	var front := _body(player.global_position+forward*1.8,Vector3(0.4,1.8,0.4),true) as Target
	var rear := _body(player.global_position-forward*1.8,Vector3(0.4,1.8,0.4),true) as Target
	player.perform_attack()
	var sequence := player._attack_sequence
	for i in 15: player.perform_attack()
	if not _check(front.hits==0 and rear.hits==0 and player._attack_sequence==sequence,"Attack spam bypassed windup or recovery"): return
	await _settle_attack()
	if not _check(front.hits==1 and rear.hits==0,"Melee must hit once in front, never behind"): return
	front.queue_free()
	rear.queue_free()
	await _steps(5)
	player.visual_root.rotation.y=0
	var blocked := _body(player.global_position+forward*1.9,Vector3(0.4,1.8,0.4),true) as Target
	var wall := _body(player.global_position+forward*.9,wall_size)
	player.perform_attack()
	await _settle_attack()
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
	blocked.queue_free()
	await _steps(4)
	player.global_position = Vector3(0, .1, 10)
	player.velocity = Vector3.ZERO
	player.visual_root.rotation.y = 0
	player.set_combat_available(true)
	await _steps(8)
	var start := player.global_position
	var charged_wall := _body(start + forward*1.1, wall_size)
	var covered := _body(start + forward*3, Vector3(.4, 1.8, .4), true) as Target
	var behind := _body(start - forward, Vector3(.4, 1.8, .4), true) as Target
	await _steps(3)
	player.execute_iai_slash(1.0)
	var stopped := player.global_position
	player.execute_iai_slash(1.0)
	if not _check((stopped-start).dot(forward) < 1.0 and player.global_position.is_equal_approx(stopped), "Charged draw crossed cover or repeated during recovery"): return
	await _steps(100)
	if not _check(covered.hits == 0 and behind.hits == 0, "Charged draw or its wave damaged through cover or behind Echo"): return
	charged_wall.queue_free()
	behind.queue_free()
	await _steps(4)
	player.global_position = start
	player.velocity = Vector3.ZERO
	player.visual_root.rotation.y = 0
	player.execute_iai_slash(1.0)
	await _steps(100)
	if not _check(covered.hits == 1, "Charged body contact and visual wave did not produce exactly one hit"): return
	covered.queue_free()
	await _steps(4)
	var low_size := wall_size
	low_size.y = .55
	for angle in [0.0, PI/4.0]:
		player.global_position=Vector3(10 if angle==0.0 else 20,.1,10)
		player.velocity=Vector3.ZERO
		player.visual_root.rotation.y=0
		var cover_start:=player.global_position
		var low_wall:=_body(cover_start+forward*1.1,low_size)
		low_wall.rotation.y=angle
		var low_target:=_body(cover_start+forward*1.65,Vector3(.35,1.8,.35),true) as Target
		await _steps(3)
		player.execute_iai_slash(1.0)
		var travelled:float=(player.global_position-cover_start).dot(forward)
		await _steps(100)
		if not _check(travelled<1.0 and low_target.hits==0,"Charged draw extended through low/diagonal cover: angle="+str(angle)+" travelled="+str(travelled)+" hits="+str(low_target.hits)):return
		low_wall.queue_free();low_target.queue_free()
		await _steps(4)
	player.global_position=Vector3(30,.1,10)
	player.velocity=Vector3.ZERO
	player.visual_root.rotation.y=0
	var target_body:=_body(player.global_position+forward*2,Vector3(.4,1.8,.4))
	var target_part:=TargetPart.new()
	target_body.add_child(target_part)
	await _steps(3)
	player.execute_iai_slash(1.0)
	await _steps(100)
	if not _check(target_part.hits==1,"Collider parent blocked its own damageable child or duplicated damage"):return
	target_body.queue_free()
	print("PASS actual melee: windup, one contact, recovery, facing cone, solid cover, dodge cancel, revoked authority")
	print("PASS charged draw: swept capsule, cover, rear exclusion, recovery and one contact without duplicate wave damage")
	print("PASS charged contact: low cover, diagonal cover and damageable child under its body collider")
	player.queue_free()
	await _steps(3)
	quit()
