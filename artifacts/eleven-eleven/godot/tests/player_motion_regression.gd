extends SceneTree

## Actual input and collision, never a simulation of controller formulas.
var player: EchoPlayer
var max_rate := 0.0
var saw_run := false
var saw_skid := false
var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var floor_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	col.shape.size = Vector3(100, 0.2, 100)
	floor_body.position.y = -0.1
	floor_body.add_child(col)
	root.add_child(floor_body)
	player = load("res://scenes/player/echo_player.tscn").instantiate()
	root.add_child(player)
	player.finish_opening_recovery()
	player.set_combat_available(false)
	for i in range(15): await physics_frame
	await _drive(Vector2(0, -0.45), 60)
	_check(player.current_anim.to_lower().contains("walk"), "Partial stick must walk")
	await _drive(Vector2(0, -1), 90)
	_check(saw_run, "Full stick must run")
	_check(absf(Vector2(player.velocity.x,player.velocity.z).length() - player.SPRINT_SPEED) < 0.05, "Run must settle at calibrated speed")
	await _drive(Vector2(1, 0), 30)
	await _drive(Vector2.ZERO, 45)
	_check(saw_skid, "Releasing run must exercise actual skid recovery")
	_check(max_rate <= 2.05, "Cadence exceeds twice authored speed: %f" % max_rate)
	_check(player.current_anim.to_lower().contains("idle"), "Stop must return to idle")
	_check(Vector2(player.velocity.x,player.velocity.z).length() < 0.05, "Stop must remove drift")
	var impacts: Array = []
	player.hard_landing_executed.connect(func(speed: float): impacts.append(speed))
	player.global_position += Vector3.UP * 6.0
	player.velocity = Vector3.ZERO
	for i in range(120): await physics_frame
	_check(not impacts.is_empty(), "Physical heavy drop must trigger landing")
	_check(not player.is_dodging and player.is_on_floor(), "Standing landing must recover grounded without a roll")
	_check(not player._roll_recovery_active, "Standing landing cannot create roll momentum")
	var skel := player.find_child("Skeleton3D", true, false) as Skeleton3D
	_check(skel.find_child("FootGroundingModifier", false, false) != null, "Contact modifier must attach")
	_check(skel.find_child("HeadLookModifier", false, false) != null, "Gaze modifier must attach after animation")
	player.queue_free()
	floor_body.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS actual input: walk, run, turn, skid, ground height, bounded cadence, physical landing; max_rate=", max_rate)
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _drive(stick: Vector2, frames: int) -> void:
	player.set_mobile_input_vector(stick, not stick.is_zero_approx())
	for i in range(frames):
		await physics_frame
		saw_run = saw_run or player.current_anim.to_lower().contains("run")
		saw_skid = saw_skid or player.locomotion_controller.is_skidding
		max_rate = maxf(max_rate, player.animation_player.speed_scale)
		_check(absf(player.visual_root.position.y) < 0.001, "Locomotion must preserve grounding without bob/sink")
		if i>20 and Vector2(player.velocity.x,player.velocity.z).length()>0.4:
			var facing:=player.visual_root.global_basis.x
			facing.y=0.0
			var travel:=Vector3(player.velocity.x,0,player.velocity.z)
			_check(facing.normalized().dot(travel.normalized())>0.98,"Actual avatar front opposes settled movement")
		_check(absf(player.visual_root.rotation.x) <= 0.046, "Turn bank exceeds subtle lean on the forward axis")
		_check(player.velocity.is_finite(), "Velocity must remain finite")

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message): failures.append(message)
