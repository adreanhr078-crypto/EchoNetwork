extends "res://tests/combat_contact_regression.gd"
## Public attack input and native blade sweeps on the actual optional avatar.
var count := 0
var failures: Array[String] = []
var evidence := ""
var contacts: Array = []
var hz := 60
var attack_signals := 0
class TimedTarget extends StaticBody3D:
	var hits := 0
	func _ready() -> void: add_to_group("damageable")
	func take_damage(_amount: int) -> void: hits += 1

func _steps(ticks: int) -> void:
	for tick in maxi(1,int(ceil(float(ticks)*hz/60.0))): await physics_frame

func ensure(ok: bool,label: String) -> bool:
	count += 1
	print("PASS " if ok else "FAIL ",label)
	if not ok:
		failures.append(label)
		finish()
	return ok

func finish() -> void:
	var file := FileAccess.open(evidence.path_join("review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":count,"failures":failures,"physics_hz":hz,"contacts":contacts,"scope":"Actual School65 source/native blade sweeps,public input and cancellation. Fixture combat grant is not a story unlock;visual art/performance/wholechapter are separate."},"\t"))
	if not failures.is_empty(): quit(1)

func tap() -> void:
	Input.action_press("attack_light")
	await _steps(2)
	Input.action_release("attack_light")
	await _steps(1)

func target_at(distance: float) -> TimedTarget:
	var target := TimedTarget.new()
	target.position = player.global_position+Vector3.BACK*distance
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.4,1.8,.4)
	shape.shape = box
	shape.position.y = .9
	target.add_child(shape)
	root.add_child(target)
	return target

func restore_pose(origin: Vector3) -> void:
	player.set_mobile_input_vector(Vector2.ZERO)
	player.velocity = Vector3.ZERO
	player.global_position = origin
	player.visual_root.rotation.y = 0
	player._cancel_attack()
	player.locomotion_controller.cancel_root_motion()
	player.set_combat_available(true)
	await _steps(8)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	evidence = args[0]
	if args.size()>1: hz = int(args[1])
	Engine.physics_ticks_per_second = hz
	DirAccess.make_dir_recursive_absolute(evidence)
	_body(Vector3(-20,-.2,-20),Vector3(80,.2,80))
	player = load("res://scenes/player/echo_player.tscn").instantiate()
	player.avatar_scene_override = load("res://scenes/characters/echo_school_candidate.tscn")
	root.add_child(player)
	player.finish_opening_recovery()
	player.attack_hit.connect(func(_damage:int,_critical:bool):attack_signals+=1)
	player.melee_contact_confirmed.connect(func(target:Node3D,position:Vector3,damage:int,seconds:float):contacts.append({"target":str(target.get_instance_id()),"point":[position.x,position.y,position.z],"damage":damage,"source_seconds":seconds,"sequence":player._attack_sequence}))
	await _steps(20)
	var before := player._attack_sequence
	await tap()
	if not ensure(not player.combat_available and player._attack_sequence==before,"Public attack cannot bypass the story combat unlock"): return
	player.set_combat_available(true)
	player.visual_root.rotation.y = 0
	var source: Animation = player.animation_player.get_animation("MELEE_HORIZONTAL")
	if not ensure(source.get_meta("source_native_samples",0)==73 and source.get_meta("source_native_fps",0)==30,"Qualified73native samples retain original30Hz identity"): return
	var origin := player.global_position
	var target := target_at(1.8)
	await _steps(3)
	await tap()
	if not ensure(player.animation_player.current_animation=="MELEE_HORIZONTAL" and is_equal_approx(player.animation_player.speed_scale,1.0),"Public tap selects the qualified source at original speed"): return
	var sequence := player._attack_sequence
	for attempt in 8: player.perform_attack()
	await _steps(40)
	if not ensure(target.hits==0 and player._attack_sequence==sequence,"Windup and spam produce no early contact or restarted attack"): return
	await _settle_attack()
	if not ensure(target.hits==1 and contacts.size()==1,"Physical blade sweep lands exactly once at1.8m"): return
	if not ensure(float(contacts[0].source_seconds)>=.8 and float(contacts[0].source_seconds)<=1.1,"Damage is inside the actual native cut window"): return
	if not ensure(player.global_position.distance_to(origin)<.015 and not player.locomotion_controller.root_motion_active,"Planted source does not inherit a generic combo lunge"): return
	target.queue_free();await _steps(4)
	await restore_pose(origin)
	var distant := target_at(2.3)
	await _steps(3)
	var combo := attack_signals
	await tap();await _settle_attack()
	if not ensure(distant.hits==0 and attack_signals==combo and contacts.size()==1,"Whiff at2.3m produces no damage,confirmed contact or combo credit"): return
	distant.queue_free();await _steps(4)
	await restore_pose(origin)
	var covered := target_at(1.8)
	var wall := _body(origin+Vector3.BACK*.9,Vector3(4,3,.2))
	await _steps(3)
	await tap();await _settle_attack()
	if not ensure(covered.hits==0,"A solid wall rejects blade and body-to-target contact"): return
	wall.queue_free();await _steps(4)
	await tap();await _steps(10);player.request_dodge();await _steps(110)
	if not ensure(covered.hits==0 and not player._grounded_melee_active,"Dodge cancels the native sweep and all deferred damage"): return
	await restore_pose(origin)
	await tap();await _steps(10);player.request_jump();await _steps(110)
	if not ensure(covered.hits==0 and not player._grounded_melee_active,"Public jump cancels the native sweep"): return
	await restore_pose(origin)
	await tap();await _steps(5)
	var recovery := player._attack_recovery
	var phase := player.animation_player.current_animation_position
	paused = true
	await create_timer(.2,true,false,true).timeout
	if not ensure(covered.hits==0 and is_equal_approx(recovery,player._attack_recovery) and is_equal_approx(phase,player.animation_player.current_animation_position),"Pause freezes the authored cut,recovery and damage window"): return
	paused = false
	await _settle_attack()
	if not ensure(covered.hits==1,"Resume preserves one physical contact"): return
	await restore_pose(origin)
	await tap();await _steps(5)
	paused = true
	player.set_combat_available(false)
	await create_timer(.15,true,false,true).timeout
	paused = false
	await _steps(160)
	if not ensure(covered.hits==1,"Combat revocation while paused removes stale physical contact"): return
	await restore_pose(origin)
	await tap();await _steps(5)
	player.control_locked = true
	await _steps(160)
	if not ensure(covered.hits==1 and not player.is_attacking,"A cinematic control lock cancels the authored damage window"): return
	player.control_locked = false
	await restore_pose(origin)
	# Holding/releasing before the pact retains an ordinary planted attack.
	var pre_pact := player.global_position
	player.execute_iai_slash(1.0)
	if not ensure(not player._native_melee_powered and player.global_position.distance_to(pre_pact)<.015,"Charged release cannot grant an unearned dash or powered cut"): return
	await _settle_attack()
	await restore_pose(origin)
	covered.queue_free();await _steps(4)
	player.awaken_zero_pact(0.0)
	var charged := target_at(3.5)
	await _steps(3)
	Input.action_press("attack_light")
	await _steps(35)
	print("CHARGE_HOLD ",JSON.stringify({"ratio":player.iai_charge,"charging":player.is_charging_iai,"floor":player.is_on_floor(),"recovery":player._attack_recovery,"input":Input.is_action_pressed("attack_light")}))
	Input.action_release("attack_light")
	await _steps(2)
	print("CHARGE_RELEASE ",JSON.stringify({"powered":player._native_melee_powered,"clip":player.animation_player.current_animation,"hits":charged.hits,"floor":player.is_on_floor(),"position":str(player.global_position),"source_time":player.animation_player.current_animation_position}))
	var charged_sequence := player._attack_sequence
	if not ensure(player._native_melee_powered and charged.hits==0 and player.animation_player.current_animation=="MELEE_HORIZONTAL","Earned public charged release approaches without release-time damage"):return
	if not ensure(player.global_position.distance_to(charged.global_position)>1.5,"Collision sweep leaves room for the actual authored blade arc"):return
	for i in 4:player.execute_iai_slash(1.0)
	if not ensure(player._attack_sequence==charged_sequence,"Charged spam cannot restart or repeat the approach"):return
	await _settle_attack()
	if not ensure(charged.hits==1 and contacts.back().damage==180 and float(contacts.back().source_seconds)>=.8,"Earned powered damage occurs once through the native cut window"):return
	charged.queue_free();await _steps(4)
	await restore_pose(origin)
	var blocked_power := target_at(3.5)
	var powered_wall := _body(origin+Vector3.BACK*.9,Vector3(4,3,.2))
	await _steps(3)
	player.execute_iai_slash(1.0)
	await _settle_attack()
	if not ensure(blocked_power.hits==0 and player.global_position.distance_to(origin)<.9,"Powered approach and native stroke cannot cross solid cover"):return
	powered_wall.queue_free();blocked_power.queue_free();await _steps(4)
	await restore_pose(origin)
	await tap();await _steps(5)
	player.queue_free()
	await _steps(160)
	if not ensure(not is_instance_valid(player),"Scene unload leaves no active blade owner"): return
	finish()
	print("SCHOOL_NATIVE_MELEE_INPUT ",count," checks at",hz,"Hz")
	quit(0)
