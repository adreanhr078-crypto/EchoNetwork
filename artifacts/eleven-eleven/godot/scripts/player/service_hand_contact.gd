extends Node3D

## A bounded physical reach on Echo's own rig. Door authority stays in the room.
var actor: EchoPlayer
var room: Node3D
var active := false
var elapsed := 0.0
var contact_sample_count := 0
var max_contact_error := 0.0
var start_result := "not_started"
var _skeleton: Skeleton3D
var _solvers: Array[TwoBoneIK3D] = []
var _targets: Array[Node3D] = []
var _poles: Array[Node3D] = []
var _start: Vector3
var _anchor: Vector3
var _start_yaw := 0.0
var _wrist_indices: Array[int] = []
var _aligned := false

func begin(player: EchoPlayer, owner_room: Node3D) -> bool:
	actor = player
	room = owner_room
	_skeleton = actor.find_child("Skeleton3D",true,false) as Skeleton3D
	if not _skeleton or not actor.control_locked:
		start_result = "no_rig_or_unlocked"
		return false
	_start = actor.global_position
	_anchor = room.to_global(Vector3(1.25,5.4,-12.18))
	_anchor.y = _start.y
	if _anchor.distance_to(_start) > 0.9:
		start_result = "alignment_too_far"
		return false
	if actor.test_move(actor.global_transform,_anchor-_start):
		start_result = "alignment_blocked"
		return false
	_start_yaw = actor.visual_root.rotation.y
	actor.velocity = Vector3.ZERO
	var alignment_distance := _start.distance_to(_anchor)
	actor.play_anim("WALK" if alignment_distance > 0.08 else "IDLE",0.12)
	actor.animation_player.speed_scale = clampf(alignment_distance / (0.35 * 2.8),0.65,1.25) if alignment_distance > 0.08 else 1.0
	for bones in [["tripo__0_Right_Limb_0","tripo__0_Right_Limb_1","tripo__0_Right_Limb_2"],["tripo__Spine_4","tripo__0_Left_Limb_0","tripo__0_Left_Limb_1"]]:
		var root_index := _skeleton.find_bone(bones[0])
		var middle_index := _skeleton.find_bone(bones[1])
		var wrist_index := _skeleton.find_bone(bones[2])
		if root_index < 0 or middle_index < 0 or wrist_index < 0:
			stop()
			return false
		var target := Node3D.new()
		add_child(target)
		_targets.append(target)
		var pole := Node3D.new()
		add_child(pole)
		_poles.append(pole)
		var solver := TwoBoneIK3D.new()
		solver.name = "ServiceHandIK" + str(_solvers.size())
		solver.active = false
		solver.influence = 0.0
		_skeleton.add_child(solver)
		solver.setting_count = 1
		solver.set_root_bone(0,root_index)
		solver.set_middle_bone(0,middle_index)
		solver.set_end_bone(0,wrist_index)
		solver.set_target_node(0,solver.get_path_to(target))
		solver.set_pole_node(0,solver.get_path_to(pole))
		solver.set_pole_direction(0,SkeletonModifier3D.SECONDARY_DIRECTION_PLUS_X)
		solver.modification_processed.connect(_measure_contact.bind(_solvers.size()))
		_solvers.append(solver)
		_wrist_indices.append(wrist_index)
	active = true
	start_result = "started"
	return true

func _physics_process(delta: float) -> void:
	if not active: return
	if not is_instance_valid(actor) or not actor.control_locked or room._motion_reduced:
		stop()
		return
	elapsed += delta
	var align := smoothstep(0.0,0.35,elapsed)
	var next := _start.lerp(_anchor,align)
	if actor.move_and_collide(next-actor.global_position):
		start_result = "alignment_interrupted"
		stop()
		return
	actor.visual_root.rotation = Vector3(0,lerp_angle(_start_yaw,PI+actor.MODEL_FORWARD_YAW_OFFSET,align),0)
	if align >= 1.0 and not _aligned:
		_aligned = true
		actor.play_anim("IDLE",0.12)
		actor.animation_player.speed_scale = 1.0
	var weight := smoothstep(0.35,0.65,elapsed) * (1.0-smoothstep(1.25,1.55,elapsed))
	var angle: float = room._valve.rotation.z-room._closed_valve.z
	for index in range(_solvers.size()):
		# Original rig's named right arm lies on negative world X when facing the wheel.
		var phase := (2.1 if index == 0 else 0.65) + angle
		_targets[index].global_position = room.to_global(Vector3(1.25+cos(phase)*0.21,6.35+sin(phase)*0.21,-12.34))
		_poles[index].global_position = actor.global_position+Vector3(-0.65 if index == 0 else 0.65,1.0,0.22)
		_solvers[index].influence = weight
		_solvers[index].active = weight > 0.0001
	if elapsed >= 1.55: stop()

func _measure_contact(index: int) -> void:
	if not active or elapsed < 0.7 or elapsed > 1.2: return
	var wrist := _skeleton.to_global(_skeleton.get_bone_global_pose(_wrist_indices[index]).origin)
	contact_sample_count += 1
	max_contact_error = maxf(max_contact_error,wrist.distance_to(_targets[index].global_position))

func stop() -> void:
	if active and is_instance_valid(actor) and actor.control_locked:
		actor.play_anim("IDLE",0.12)
		actor.animation_player.speed_scale = 1.0
	active = false
	for solver in _solvers:
		if is_instance_valid(solver):
			solver.active = false
			solver.influence = 0.0
			solver.queue_free()
	_solvers.clear()
	for target in _targets+_poles:
		if is_instance_valid(target): target.queue_free()
	_targets.clear()
	_poles.clear()

func _exit_tree() -> void: stop()
