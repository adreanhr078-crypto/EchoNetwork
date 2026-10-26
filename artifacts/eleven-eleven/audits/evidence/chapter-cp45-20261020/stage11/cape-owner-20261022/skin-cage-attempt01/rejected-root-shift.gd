extends SkeletonModifier3D

## Explicit V31 garment driver: five verified Hips-owned chains, never hands.
## Owner authorized a dedicated coat repair on 2026-10-20. Source/rest/skin
## and every body animation track remain untouched; this is a post-mixer pose.
const Profile = preload("res://scripts/player/echo_rig_profile.gd")
var body: CharacterBody3D
var configured := false
var _chains: Array[PackedInt32Array] = []
var _angles := PackedFloat32Array()
var _speeds := PackedFloat32Array()
var _last_position := Vector3.ZERO
var _clock := 0.0
var _legs: Array[PackedInt32Array] = []
var collision_corrections := 0
var callback_count := 0
var last_delta := 0.0
var last_reset_reason := ""
var _support_rotations: Array[Quaternion] = []
var support_pose_evaluations := 0
var _skin_probes: Array = []
var _last_safe_pose: Array[Transform3D] = []
var skin_projection_count := 0
var maximum_root_shift := 0.0
const SKIN_CAGE := "res://assets/characters/echo_v31_cape_skin_cage.json"

func configure(owner_body: CharacterBody3D) -> bool:
	var skeleton := get_skeleton()
	if not skeleton or Profile.identify(skeleton).get("id") != Profile.V31_ID: return false
	body=owner_body
	_chains.clear()
	_legs.clear()
	_support_rotations.clear()
	for column in 5:
		_chains.append(PackedInt32Array([skeleton.find_bone("Cape_%d_0"%column),skeleton.find_bone("Cape_%d_1"%column),skeleton.find_bone("Cape_%d_2"%column)]))
	for side in ["Left","Right"]:
		_legs.append(PackedInt32Array([skeleton.find_bone(side+"UpLeg"),skeleton.find_bone(side+"Leg"),skeleton.find_bone(side+"Foot")]))
	for chain in _chains:
		for bone in chain: _support_rotations.append(skeleton.get_bone_pose_rotation(bone))
	_angles.resize(15)
	_speeds.resize(15)
	_last_position=body.global_position
	if not _configure_skin_cage(skeleton): return false
	configured=true
	return true

func reset_motion() -> void:
	_angles.fill(0.0)
	_speeds.fill(0.0)
	_clock=0.0
	if is_instance_valid(body): _last_position=body.global_position

func _process_modification_with_delta(delta: float) -> void:
	callback_count+=1
	last_delta=delta
	if not configured or not is_instance_valid(body): return
	if get_tree().paused:
		if _last_safe_pose.size() == 15:
			for column in 5:
				for row in 3: get_skeleton().set_bone_pose(_chains[column][row], _last_safe_pose[column*3+row])
		return
	var support_motor: Object = body.get("surface_motor")
	var has_support_pose: bool = support_motor and (support_motor.get("hanging") == true or support_motor.get("_mantle_visual_active") == true)
	if has_support_pose and not body.control_locked and not body.opening_recovery_active and not body._camera_suspended:
		reset_motion()
		last_reset_reason = "static_support_clearance"
		_apply_support_pose()
		_apply_skin_clearance()
		return
	# SkeletonModifier3D may evaluate at zero delta during initialization or
	# an immediate pose refresh. That is not a teleport or a spring reset.
	if delta<=0.0:
		_apply_skin_clearance()
		return
	var suspended: bool = body.get("reduced_motion")==true or body.get("control_locked")==true or body.get("opening_recovery_active")==true or body.get("_camera_suspended")==true or body.get("is_dodging")==true
	var motor: Object=body.get("surface_motor")
	if motor and (motor.get("hanging")==true or motor.get("_mantle_visual_active")==true): suspended=true
	if suspended or delta>0.5 or body.global_position.distance_to(_last_position)>2.0:
		last_reset_reason="ownership_or_accessibility" if suspended else "hitch_or_teleport"
		reset_motion()
		_apply_skin_clearance()
		return
	last_reset_reason=""
	_last_position=body.global_position
	_clock+=delta
	var skeleton:=get_skeleton()
	var local_velocity: Vector3 = skeleton.global_basis.orthonormalized().inverse()*body.velocity
	# Rear of this inspected garment is local -Z. Backward motion never drives
	# cloth through the knees; inertia relaxes toward gravity instead.
	var speed := clampf(local_velocity.z,0.0,10.0)
	var hyper:=get_node_or_null("/root/HyperAnimeWorldManager")
	var wind_clock:float=float(hyper.get("visual_time")) if hyper else _clock
	var gust:=sin(wind_clock*0.37)*0.6
	var hips:=skeleton.get_bone_global_pose(skeleton.find_bone("Hips"))
	var hip_basis:=hips.basis.orthonormalized()
	# The inspected roots run from -X to +X. Read each animated foot in hip
	# space rather than guessing which imported Left/Right name is positive X.
	var rear_steps:=PackedFloat32Array()
	var foot_sides:=PackedFloat32Array()
	for leg in _legs:
		var foot:=hip_basis.inverse()*(skeleton.get_bone_global_pose(leg[2]).origin-hips.origin)
		var leg_length:=skeleton.get_bone_rest(leg[1]).origin.length()+skeleton.get_bone_rest(leg[2]).origin.length()
		rear_steps.append(clampf(-foot.z/maxf(leg_length,0.01),0.0,1.0))
		foot_sides.append(signf(foot.x))
	for column in 5:
		var side:float=float(column-2)/2.0
		var local_step:=0.0
		for leg_index in _legs.size():
			local_step+=rear_steps[leg_index]*lerpf(0.25,1.0,(side*foot_sides[leg_index]+1.0)*0.5)
		for row in 3:
			var slot:=column*3+row
			# A rear leg excites its own panel most; the opposite panel receives a
			# quarter of that impulse. Softer distal links retain follow-through.
			var air:float=(1.2+speed*1.15)*(0.36+row*0.20)*(1.0+row*0.175)
			var step:float=local_step*(1.2+row*0.9)
			var target:=deg_to_rad(air+step+gust*sin(_clock*1.6+column*0.5))
			# Exact critically damped spring toward this frame's target. Stable at
			# different frame rates, with no Euler integration or energy growth.
			var omega:=13.0-row*2.3
			var offset:=float(_angles[slot])-target
			var term:=float(_speeds[slot])+omega*offset
			var decay:=exp(-omega*delta)
			_angles[slot]=clampf(target+(offset+term*delta)*decay,0.0,deg_to_rad(12.0))
			_speeds[slot]=(float(_speeds[slot])-omega*term*delta)*decay
			var bone:int=_chains[column][row]
			var current:=skeleton.get_bone_global_pose(bone)
			var parent:=skeleton.get_bone_parent(bone)
			var parent_basis:=skeleton.get_bone_global_pose(parent).basis.orthonormalized()
			var axis:=parent_basis.inverse()*(hip_basis*Vector3.RIGHT)
			var source_rotation:=skeleton.get_bone_pose_rotation(bone)
			skeleton.set_bone_pose_rotation(bone,(Quaternion(axis.normalized(),_angles[slot])*source_rotation).normalized())
			# A bounded capsule response keeps the cloth joint tip outside the
			# measured animated thighs/shins without moving any limb or anchor.
			current=skeleton.get_bone_global_pose(bone)
			var tip:Vector3
			if row<2: tip=skeleton.get_bone_global_pose(_chains[column][row+1]).origin
			else:
				tip = _support_tip(skeleton, column, row)
			var corrected:=tip
			for leg in _legs:
				for segment in 2:
					var a:=skeleton.get_bone_global_pose(leg[segment]).origin
					var b:=skeleton.get_bone_global_pose(leg[segment+1]).origin
					var near:=Geometry3D.get_closest_point_to_segment(corrected,a,b)
					var separation:=corrected-near
					var radius:float=a.distance_to(b)*0.26
					if separation.length()<radius:
						var outward:=separation.normalized() if separation.length()>0.0001 else hip_basis*Vector3.FORWARD
						corrected=near+outward*radius
			if not corrected.is_equal_approx(tip):
				var from:Vector3=(tip-current.origin).normalized()
				var to:Vector3=(corrected-current.origin).normalized()
				var correction:=Quaternion(from,to)
				if correction.get_angle()>deg_to_rad(18.0): correction=Quaternion.IDENTITY.slerp(correction,deg_to_rad(18.0)/correction.get_angle())
				var local_correction:=parent_basis.get_rotation_quaternion().inverse()*correction*parent_basis.get_rotation_quaternion()
				skeleton.set_bone_pose_rotation(bone,(local_correction*skeleton.get_bone_pose_rotation(bone)).normalized())
				collision_corrections+=1
	_apply_skin_clearance()

func _configure_skin_cage(skeleton: Skeleton3D) -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SKIN_CAGE))
	if not data is Dictionary or data.get("source_sha256", "") != FileAccess.get_sha256("res://assets/characters/echo_v31_adopted_high.glb"): return false
	if data.get("bone_names", []).size() != skeleton.get_bone_count(): return false
	for bone in skeleton.get_bone_count():
		if data.bone_names[bone] != skeleton.get_bone_name(bone): return false
	_skin_probes.clear()
	for sample in data.get("samples", []):
		var probe := {"bones":PackedInt32Array(),"points":PackedVector3Array(),"weights":PackedFloat32Array(),"roots":PackedFloat32Array(sample.roots)}
		for influence in sample.skin:
			probe.bones.append(int(influence.bone))
			probe.points.append(Vector3(influence.point[0],influence.point[1],influence.point[2]))
			probe.weights.append(float(influence.weight))
		_skin_probes.append(probe)
	return _skin_probes.size() >= 30 and _skin_probes.size() <= 135

func _apply_skin_clearance() -> void:
	# Joint tips miss a panel's waist/edges. Evaluate bounded points from the
	# actual immutable skin, then move only its five eligible garment roots.
	# The least-norm weight distribution preserves each chain's link lengths.
	var skeleton := get_skeleton()
	var roots := PackedVector3Array()
	for column in 5: roots.append(skeleton.get_bone_pose_position(_chains[column][0]))
	var parent := skeleton.get_bone_parent(_chains[0][0])
	var parent_inverse := skeleton.get_bone_global_pose(parent).basis.inverse()
	var root_spacing := skeleton.get_bone_global_rest(_chains[0][0]).origin.distance_to(skeleton.get_bone_global_rest(_chains[1][0]).origin)
	var limit := root_spacing * 0.5
	var capsules: Array = []
	for leg in _legs:
		for segment in 2:
			var start := skeleton.get_bone_global_pose(leg[segment]).origin
			var finish := skeleton.get_bone_global_pose(leg[segment+1]).origin
			capsules.append({"start":start,"finish":finish,"radius":start.distance_to(finish)*0.26+0.003})
	for iteration in 3:
		for probe in _skin_probes:
			var point := Vector3.ZERO
			for influence in probe.bones.size():
				point += (skeleton.get_bone_global_pose(probe.bones[influence]) * probe.points[influence]) * probe.weights[influence]
			var correction := Vector3.ZERO
			for capsule in capsules:
				var near := Geometry3D.get_closest_point_to_segment(point,capsule.start,capsule.finish)
				var vertical := point.y-near.y
				var squared: float = capsule.radius*capsule.radius-vertical*vertical
				if squared <= 0: continue
				var away := Vector3(point.x-near.x,0,point.z-near.z)
				var distance := away.length()
				var required := sqrt(squared)
				if distance >= required: continue
				if distance < 0.00001: away = Vector3.FORWARD
				var candidate := away.normalized()*(required-distance)
				if candidate.length_squared() > correction.length_squared(): correction = candidate
			if correction.length_squared() < 0.00000001: continue
			var denominator := 0.0
			for weight in probe.roots: denominator += weight*weight
			if denominator < 0.0001: continue
			for column in 5:
				if probe.roots[column] <= 0.0001: continue
				var bone: int = _chains[column][0]
				var next: Vector3 = skeleton.get_bone_pose_position(bone) + parent_inverse*correction*(probe.roots[column]/denominator)
				var shift: Vector3 = (next-roots[column]).limit_length(limit)
				skeleton.set_bone_pose_position(bone,roots[column]+shift)
				maximum_root_shift = maxf(maximum_root_shift,shift.length())
			skin_projection_count += 1
	_last_safe_pose.clear()
	for column in 5:
		for row in 3: _last_safe_pose.append(skeleton.get_bone_pose(_chains[column][row]))

func _support_tip(skeleton: Skeleton3D, column: int, row: int) -> Vector3:
	var origin := skeleton.get_bone_global_pose(_chains[column][row]).origin
	if row < 2: return skeleton.get_bone_global_pose(_chains[column][row + 1]).origin
	var bone: int = _chains[column][row]
	var rest := skeleton.get_bone_rest(bone)
	return origin + skeleton.get_bone_global_pose(bone).basis * (rest.basis.inverse() * rest.origin)

func _turn_support_segment(skeleton: Skeleton3D, bone: int, from: Vector3, to: Vector3, weight: float) -> void:
	if from.length_squared() < 0.00000001 or to.length_squared() < 0.00000001: return
	var correction := Quaternion(from.normalized(), to.normalized())
	correction = Quaternion.IDENTITY.slerp(correction, weight)
	var parent_basis := skeleton.get_bone_global_pose(skeleton.get_bone_parent(bone)).basis.orthonormalized().get_rotation_quaternion()
	var local_correction := parent_basis.inverse() * correction * parent_basis
	skeleton.set_bone_pose_rotation(bone, (local_correction * skeleton.get_bone_pose_rotation(bone)).normalized())

func _leg_clearance(skeleton: Skeleton3D, point: Vector3) -> float:
	var clearance := INF
	for leg in _legs:
		for segment in 2:
			var start := skeleton.get_bone_global_pose(leg[segment]).origin
			var finish := skeleton.get_bone_global_pose(leg[segment + 1]).origin
			var near := Geometry3D.get_closest_point_to_segment(point, start, finish)
			clearance = minf(clearance, point.distance_to(near) - start.distance_to(finish) * 0.26)
	return clearance

func _apply_support_pose() -> void:
	support_pose_evaluations += 1
	var skeleton := get_skeleton()
	var down := (skeleton.global_basis.inverse() * Vector3.DOWN).normalized()
	var hips := skeleton.get_bone_global_pose(skeleton.find_bone("Hips"))
	for column in 5:
		for row in 3: skeleton.set_bone_pose_rotation(_chains[column][row], _support_rotations[column * 3 + row])
	for column in 5:
		for row in 3:
			var bone: int = _chains[column][row]
			var origin := skeleton.get_bone_global_pose(bone).origin
			_turn_support_segment(skeleton, bone, _support_tip(skeleton, column, row) - origin, down, 1.0 / float(3 - row))
	for iteration in 3:
		for column in 5:
			var outward_world := skeleton.global_basis * (hips.basis.orthonormalized() * Vector3.FORWARD)
			outward_world.y = 0.0
			if outward_world.length_squared() < 0.0001: outward_world = body.visual_root.global_basis * Vector3.FORWARD
			var outward := (skeleton.global_basis.inverse() * outward_world).normalized()
			for row in 3:
				var bone: int = _chains[column][row]
				var origin := skeleton.get_bone_global_pose(bone).origin
				var tip := _support_tip(skeleton, column, row)
				var corrected := tip
				for leg in _legs:
					for segment in 2:
						var start := skeleton.get_bone_global_pose(leg[segment]).origin
						var finish := skeleton.get_bone_global_pose(leg[segment + 1]).origin
						var near := Geometry3D.get_closest_point_to_segment(corrected, start, finish)
						var separation := corrected - near
						var radius := start.distance_to(finish) * 0.26
						if separation.length() < radius:
							var direction := separation.normalized() if separation.dot(outward) > 0.0 else outward
							corrected = near + direction * radius
				var tip_world := skeleton.to_global(corrected)
				var origin_world := skeleton.to_global(origin)
				var ray_start := Vector3(tip_world.x, maxf(origin_world.y, tip_world.y) + 0.3, tip_world.z)
				var query := PhysicsRayQueryParameters3D.create(ray_start, tip_world - Vector3.UP, body.collision_mask, [body.get_rid()])
				var floor_hit := body.get_world_3d().direct_space_state.intersect_ray(query)
				if not floor_hit.is_empty() and floor_hit.normal.y > 0.8 and tip_world.y < floor_hit.position.y + 0.015:
					var length_world := origin_world.distance_to(tip_world)
					var vertical := clampf((floor_hit.position.y + 0.015 - origin_world.y) / maxf(length_world, 0.001), -1.0, 1.0)
					var horizontal := outward_world.normalized() * sqrt(maxf(0.0, 1.0 - vertical * vertical))
					corrected = skeleton.to_local(origin_world + (horizontal + Vector3.UP * vertical) * length_world)
				if not corrected.is_equal_approx(tip):
					var length := tip.distance_to(origin)
					var direction := (corrected - origin).normalized()
					if _leg_clearance(skeleton, origin + direction * length) < 0.0005 and _leg_clearance(skeleton, origin + outward * length) >= 0.0005:
						var lower := 0.0
						var upper := 1.0
						for search in 10:
							var middle := (lower + upper) * 0.5
							var candidate := direction.lerp(outward, middle).normalized()
							if _leg_clearance(skeleton, origin + candidate * length) >= 0.0005: upper = middle
							else: lower = middle
						direction = direction.lerp(outward, upper).normalized()
					corrected = origin + direction * length
					_turn_support_segment(skeleton, bone, tip - origin, corrected - origin, 1.0)
					collision_corrections += 1
