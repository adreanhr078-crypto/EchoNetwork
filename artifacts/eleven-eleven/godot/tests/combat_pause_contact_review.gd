extends "res://tests/combat_contact_regression.gd"

## Exercise the actual player's delayed contact while the world is paused.
func _run() -> void:
	_body(Vector3(-20,-0.2,-20),Vector3(80,0.2,80))
	player=load("res://scenes/player/echo_player.tscn").instantiate()
	root.add_child(player)
	player.finish_opening_recovery()
	player.set_combat_available(true)
	await _steps(20)
	player.visual_root.rotation.y=0
	var forward: Vector3=(player.visual_root.global_basis*player.model_local_forward).normalized()
	var target=_body(player.global_position+forward*1.8,Vector3(.4,1.8,.4),true)
	player.perform_attack()
	await _steps(3)
	var recovery: float=player._attack_recovery
	var sequence: int=player._attack_sequence
	paused=true
	await create_timer(1.3,true,false,true).timeout
	if not _check(target.hits==0,"Paused windup inflicted melee damage while the animation and recovery were frozen"):return
	if not _check(is_equal_approx(player._attack_recovery,recovery) and player._attack_sequence==sequence,"Pause advanced the attack's physics clock"):return
	paused=false
	await _settle_attack()
	if not _check(target.hits==1,"Resuming the paused windup lost or duplicated its one contact"):return
	var previous_sequence:int=player._attack_sequence
	player.perform_attack()
	if not _check(player._attack_sequence==previous_sequence+1,"Paused revocation fixture did not start its second real attack"):return
	await _steps(3)
	paused=true
	player.set_combat_available(false)
	await create_timer(1.3,true,false,true).timeout
	paused=false
	await _steps(100)
	if not _check(target.hits==1,"Combat revocation during pause left a stale contact after resume"):return
	player.queue_free()
	target.queue_free()
	await _steps(3)
	print("PASS actual melee pause: frozen windup, frozen recovery, one resumed contact, paused revocation invalidates deferred contact")
	quit(0)
