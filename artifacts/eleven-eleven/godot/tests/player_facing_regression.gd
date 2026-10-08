extends SceneTree

class StaggeredTarget extends Node3D:
	var is_staggered:=true
	var received_damage:=0
	func take_damage(amount:int,_position:Vector3) -> void: received_damage+=amount

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var player:EchoPlayer=load("res://scenes/player/echo_player.tscn").instantiate()
	root.add_child(player)
	player.finish_opening_recovery()
	player.set_physics_process(false)
	player.set_process(false)
	player.unlock_shadow_step()
	var target:=StaggeredTarget.new()
	root.add_child(target)
	var failures:Array[String]=[]
	for body_yaw in [0.0,0.7]:
		player.rotation.y=body_yaw
		for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
			player.position=Vector3.ZERO
			target.position=direction*3.0
			player.shadow_gauge=100.0
			if not player.perform_shadow_step(target): failures.append("Shadow step rejected")
			var toward:Vector3=(target.global_position-player.global_position).normalized()
			if player.visual_root.global_basis.x.normalized().dot(toward)<0.999:
				failures.append("Shadow step turns face away from target, body yaw="+str(body_yaw)+" direction="+str(direction))
			await create_timer(0.3,true,false,true).timeout
			player.position=Vector3.ZERO
			target.position=direction*3.0
			target.is_staggered=true
			var result:Dictionary=player.visceral_combat.execute_visceral_strike(player,target)
			if not result.get("success",false): failures.append("Execution rejected")
			toward=(target.global_position-player.global_position).normalized()
			if player.visual_root.global_basis.x.normalized().dot(toward)<0.999:
				failures.append("Execution turns face away from target")
			await create_timer(2.0,true,false,true).timeout
	if target.received_damage<=0: failures.append("Execution contact was never exercised")
	player.queue_free()
	target.queue_free()
	await create_timer(3.0,true,false,true).timeout
	await process_frame
	await physics_frame
	if failures.is_empty(): print("PASS actual shadow step and execution face target in four directions and rotated body; untouched +X avatar front")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

