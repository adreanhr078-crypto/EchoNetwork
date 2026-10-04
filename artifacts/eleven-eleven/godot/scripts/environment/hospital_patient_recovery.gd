extends Node3D

## Scoped, isolated bedside pose review. Original mesh/rest/keys stay unchanged.
## No route caller may begin before explicit pact, wish and completed transfer.
signal recovery_changed(stage: String)
signal bedside_control_ready

enum Stage { WAITING, RECLINED, AWAKE, SEATED, INSPECTED, CONTROL }
var stage := Stage.WAITING
var actor: Node3D
var skeleton: Skeleton3D
var animation: AnimationPlayer
var _phase := 0.0
var _pose_time := 0.0
var _snapshot := {}
var _rotations: Array[Quaternion] = []
var _ward: Node3D
var _breath_base := Quaternion.IDENTITY

func bind_existing_actor(model: Node3D, ward: Node3D) -> bool:
	if stage != Stage.WAITING or not model: return false
	actor = model
	_ward = ward
	skeleton = actor.find_child("Skeleton3D", true, false)
	animation = actor.find_child("AnimationPlayer", true, false)
	return skeleton != null and animation != null

func begin_recovery(proof: Dictionary) -> bool:
	if stage != Stage.WAITING or not skeleton: return false
	for key in ["pact_confirmed", "revenge_completed", "wish_confirmed", "transfer_completed"]:
		if typeof(proof.get(key)) != TYPE_BOOL or proof[key] != true: return false
	if proof.get("stage", "") != "hospital_bedside": return false
	_snapshot = {"transform": actor.transform, "clip": animation.current_animation, "position": animation.current_animation_position if not animation.current_animation.is_empty() else 0.0, "playing": animation.is_playing()}
	_rotations.clear()
	for bone in skeleton.get_bone_count(): _rotations.append(skeleton.get_bone_pose_rotation(bone))
	animation.stop()
	skeleton.reset_bone_poses()
	stage = Stage.RECLINED
	_pose_time = 0.0
	_pose_reclined()
	recovery_changed.emit("reclined")
	return true

func request_action(action: String) -> bool:
	# Every recovery action is intentional. Presentation timers never consent,
	# inspect the mark or release bedside control on the player's behalf.
	match stage:
		Stage.RECLINED:
			if action != "wake": return false
			stage = Stage.AWAKE
			recovery_changed.emit("awake")
		Stage.AWAKE:
			if action != "sit": return false
			stage = Stage.SEATED
			_pose_seated()
			recovery_changed.emit("seated")
		Stage.SEATED:
			if action != "inspect_mark": return false
			stage = Stage.INSPECTED
			recovery_changed.emit("inspected")
		Stage.INSPECTED:
			if action != "stand": return false
			stage = Stage.CONTROL
			_pose_standing()
			recovery_changed.emit("control")
			bedside_control_ready.emit()
		_: return false
	return true

func _process(delta: float) -> void:
	if not skeleton or stage == Stage.WAITING or stage == Stage.CONTROL: return
	_pose_time += delta
	# Small chest motion in the isolated pose, no source-key editing/retargeting.
	var bone := skeleton.find_bone("tripo__Spine_1")
	skeleton.set_bone_pose_rotation(bone, _breath_base * Quaternion(Vector3.FORWARD, sin(_pose_time * 1.5) * 0.008))

func _pose_reclined() -> void:
	skeleton.reset_bone_poses()
	actor.rotation = Vector3(0, 0, PI / 2.0)
	actor.position = Vector3(0.905, 0.79, 0)
	# Articulate both arms toward the body instead of rotating a standing rest
	# mannequin. Anatomical side follows measured Z; named sides are reversed.
	_aim("bone_6", "tripo__0_Right_Limb_0", Vector3(0.06, -1, -0.12))
	_aim("tripo__Spine_3", "tripo__Spine_4", Vector3(0.05, -1, 0.12))
	_aim("tripo__0_Right_Limb_0", "tripo__0_Right_Limb_1", Vector3(0.16, -1, 0.13))
	_aim("tripo__Spine_4", "tripo__0_Left_Limb_0", Vector3(0.16, -1, -0.13))
	_aim("tripo__0_Right_Limb_1", "tripo__0_Right_Limb_2", Vector3(0.08, -1, 0.25))
	_aim("tripo__0_Left_Limb_0", "tripo__0_Left_Limb_1", Vector3(0.08, -1, -0.25))
	# Relax the head into its cushion and ankles toward supported neutral heels.
	_set_global_rotation("tripo__Head_0", Vector3.FORWARD, 0.48)
	_set_global_rotation("tripo__1_Left_Limb_0", Vector3.FORWARD, -0.11)
	_set_global_rotation("tripo__1_Right_Limb_0", Vector3.FORWARD, -0.11)
	_set_global_rotation("tripo__1_Left_Limb_2", Vector3.FORWARD, -0.28)
	_set_global_rotation("tripo__1_Right_Limb_2", Vector3.FORWARD, -0.28)
	skeleton.force_update_all_bone_transforms()
	# Ground torso support using actual weighted skin; the ward pillow/cover
	# remain authored surfaces and their independent gaps are measured in tests.
	var lowest := INF
	for point in skin_points():
		if point.x > -0.45 and point.x < 0.45 and absf(point.z) < 0.42: lowest = minf(lowest, point.y)
	actor.position.y += 0.70 - lowest
	_breath_base = skeleton.get_bone_pose_rotation(skeleton.find_bone("tripo__Spine_1"))

func _pose_seated() -> void:
	skeleton.reset_bone_poses()
	actor.rotation = Vector3(0, -PI / 2.0, 0)
	actor.position = Vector3(-0.15, -0.055, 0.47)
	_aim("tripo__1_Left_Limb_0", "tripo__1_Left_Limb_1", Vector3(1, -0.06, 0.04))
	_aim("tripo__1_Right_Limb_0", "tripo__1_Right_Limb_1", Vector3(1, -0.06, -0.04))
	_aim("tripo__1_Left_Limb_1", "tripo__1_Left_Limb_2", Vector3(0.04, -1, 0))
	_aim("tripo__1_Right_Limb_1", "tripo__1_Right_Limb_2", Vector3(0.04, -1, 0))
	_aim("bone_6", "tripo__0_Right_Limb_0", Vector3(0.05, -1, -0.15))
	_aim("tripo__Spine_3", "tripo__Spine_4", Vector3(0.05, -1, 0.15))
	skeleton.force_update_all_bone_transforms()

	_breath_base = skeleton.get_bone_pose_rotation(skeleton.find_bone("tripo__Spine_1"))

func _pose_standing() -> void:
	skeleton.reset_bone_poses()
	actor.rotation = Vector3.ZERO
	actor.position = Vector3(-0.25, 0, 1.20)
	var bottom := INF
	for point in skin_points(): bottom = minf(bottom, point.y)
	actor.position.y -= bottom
	if _snapshot.playing and animation.has_animation(_snapshot.clip):
		animation.play(_snapshot.clip)

func restore_scope() -> void:
	if not is_instance_valid(actor) or _snapshot.is_empty(): return
	actor.transform = _snapshot.transform
	for bone in _rotations.size(): skeleton.set_bone_pose_rotation(bone, _rotations[bone])
	if animation.has_animation(_snapshot.clip):
		animation.play(_snapshot.clip)
		animation.seek(_snapshot.position, true)
		if not _snapshot.playing: animation.pause()
	_snapshot.clear()
	stage = Stage.WAITING

func _aim(parent_name: String, child_name: String, direction: Vector3) -> void:
	var parent := skeleton.find_bone(parent_name)
	var child := skeleton.find_bone(child_name)
	skeleton.force_update_all_bone_transforms()
	var parent_pose := skeleton.get_bone_global_pose(parent)
	var original := skeleton.get_bone_global_pose(child).origin - parent_pose.origin
	var desired := Basis(Quaternion(original.normalized(), direction.normalized())) * parent_pose.basis
	var ancestor := skeleton.get_bone_parent(parent)
	var ancestor_basis := skeleton.get_bone_global_pose(ancestor).basis if ancestor >= 0 else Basis.IDENTITY
	var local := ancestor_basis.inverse() * desired
	skeleton.set_bone_pose_rotation(parent, local.get_rotation_quaternion())

func _set_global_rotation(name: String, axis: Vector3, angle: float) -> void:
	var bone := skeleton.find_bone(name)
	skeleton.force_update_all_bone_transforms()
	var parent := skeleton.get_bone_parent(bone)
	var desired := Basis(axis, angle) * skeleton.get_bone_global_pose(bone).basis
	var local := skeleton.get_bone_global_pose(parent).basis.inverse() * desired
	skeleton.set_bone_pose_rotation(bone, local.get_rotation_quaternion())

func skin_points() -> PackedVector3Array:
	skeleton.force_update_all_bone_transforms()
	var points := PackedVector3Array()
	for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		if not mesh.mesh or not mesh.skin: continue
		var matrices: Array[Transform3D] = []
		for bind in mesh.skin.get_bind_count():
			var bone := mesh.skin.get_bind_bone(bind)
			if bone < 0: bone = skeleton.find_bone(mesh.skin.get_bind_name(bind))
			matrices.append(skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind))
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var count := bones.size() / vertices.size()
			for vertex in vertices.size():
				var point := Vector3.ZERO
				for influence in count:
					var index := vertex * count + influence
					point += matrices[bones[index]] * vertices[vertex] * weights[index]
				points.append(skeleton.to_global(point))
	return points
