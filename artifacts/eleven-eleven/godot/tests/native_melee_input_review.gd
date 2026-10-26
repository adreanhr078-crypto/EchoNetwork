extends "res://tests/combat_contact_regression.gd"

class TimedTarget extends StaticBody3D:
	var source_player:EchoPlayer
	var hits:=0
	var contact_times:Array[float]=[]
	func _ready() -> void:add_to_group("damageable")
	func take_damage(_amount:int) -> void:
		hits+=1
		contact_times.append(source_player.animation_player.current_animation_position)

func _run() -> void:
	_body(Vector3(-20,-.2,-20),Vector3(80,.2,80))
	player=load("res://scenes/player/echo_player.tscn").instantiate()
	root.add_child(player)
	player.finish_opening_recovery()
	await _steps(20)
	var initial_sequence:int=player._attack_sequence
	player.perform_attack()
	if not _check(player._attack_sequence==initial_sequence,"Native source bypassed the existing combat unlock"):return
	player.set_combat_available(true)
	player.visual_root.rotation.y=0
	var forward:Vector3=(player.visual_root.global_basis*player.model_local_forward).normalized()
	var target:=TimedTarget.new()
	target.source_player=player
	target.position=player.global_position+forward*1.8
	var collider:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(.4,1.8,.4)
	collider.shape=box
	collider.position.y=.9
	target.add_child(collider)
	root.add_child(target)
	await _steps(3)
	var start:=player.global_position
	player.perform_attack()
	if not _check(player.animation_player.current_animation=="MELEE_HORIZONTAL" and is_equal_approx(player.animation_player.speed_scale,1.0),"Actual attack did not select the qualified clip at its original rate"):return
	if not _check(not player.locomotion_controller.root_motion_active,"Planted native motion inherited an unrelated combo lunge"):return
	player.set_mobile_input_vector(Vector2(0,1))
	await _steps(45)
	if not _check(target.hits==0 and Vector2(player.global_position.x-start.x,player.global_position.z-start.z).length()<.015,"Native windup hit early or slid its capsule under planted feet"):return
	var blade:Node3D=player.find_child("KatanaBlade",true,false)
	var physical_contacts:Array[float]=[]
	for tick in 26:
		await physics_frame
		var ray:=PhysicsRayQueryParameters3D.create(blade.global_position,blade.to_global(Vector3(0,1.1,0)))
		ray.exclude=[player.get_rid()]
		var hit:=player.get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.get("collider")==target:physical_contacts.append(player.animation_player.current_animation_position)
	print("NATIVE_SWEEP_CONTACT ",JSON.stringify({"blade_contacts":physical_contacts,"damage_times":target.contact_times}))
	if not _check(target.hits==1 and absf(target.contact_times[0]-28.0/30.0)<.035,"Damage did not coincide with the measured native frame28 contact"):return
	if not _check(not physical_contacts.is_empty() and absf(target.contact_times[0]-physical_contacts[0])<.035,"Native damage missed its actual blade/target intersection window"):return
	await _steps(18)
	if not _check(not player.is_attacking and not player._grounded_melee_active and player.global_position.distance_to(start)>.03,"Public movement failed to cancel recovery after the native cut"):return
	player.set_mobile_input_vector(Vector2.ZERO)
	await _steps(80)
	player.perform_attack()
	if not _check(player.is_attacking and player.animation_player.current_animation_position<.04,"Repeated source attack resumed its old playback cursor"):return
	await _steps(10)
	player.request_dodge()
	await _steps(100)
	if not _check(target.hits==1 and not player._grounded_melee_active,"Dodge left a native deferred contact or planted state active"):return
	player.global_position=start
	player.velocity=Vector3.ZERO
	player.visual_root.rotation.y=0
	await _steps(5)
	player.perform_attack()
	await _steps(5)
	Input.action_press("jump")
	await _steps(2)
	Input.action_release("jump")
	await _steps(100)
	if not _check(target.hits==1 and not player._grounded_melee_active,"Public jump left the interrupted native contact active"):return
	player.queue_free();target.queue_free()
	await _steps(3)
	print("PASS native actual input: unlock, original rate, planted windup, spatially measured frame28 contact, movement exit, fresh playback, dodge and jump cancel")
	quit(0)
