extends RefCounted
## Narrow phase for a qualified native cut. The player owns unlock and damage.
## Current blade and five between-tick sweep rays cover its normalized length;
## body-to-target visibility still rejects cover penetrated by animated limbs.
var _previous: Array[Vector3] = []
var _sequence := -1
var _landed := false

func clear() -> void:
	_previous.clear()
	_sequence = -1
	_landed = false

func sample(actor, clip: Animation, sequence: int) -> Dictionary:
	if sequence != _sequence:
		clear()
		_sequence = sequence
	if _landed or not actor.is_inside_tree() or actor.get_tree().paused: return {}
	var socket: BoneAttachment3D = actor._hand_weapon_socket
	if not is_instance_valid(socket): return {}
	var skeleton := socket.get_parent() as Skeleton3D
	var blade := actor.find_child("KatanaBlade",true,false) as Node3D
	if not skeleton or not blade: return {}
	var hand := skeleton.find_bone(socket.bone_name)
	if hand < 0: return {}
	# BoneAttachment's rendered transform can follow mixer_applied later in the
	# same tick. Evaluate the current hand pose directly,without changing keys.
	var transform: Transform3D = skeleton.global_transform*skeleton.get_bone_global_pose(hand)*blade.transform
	var segment: Array[Vector3] = [transform.origin,transform*Vector3(0,1.1,0)]
	var previous: Array[Vector3] = _previous.duplicate()
	_previous = segment
	var time: float = actor.animation_player.current_animation_position
	if time < float(clip.get_meta("melee_window_open_seconds",0.0)) or time > float(clip.get_meta("melee_window_close_seconds",0.0)): return {}
	var rays: Array = [[segment[0],segment[1]]]
	if previous.size() == 2:
		for index in 5:
			var fraction := float(index)/4.0
			rays.append([previous[0].lerp(previous[1],fraction),segment[0].lerp(segment[1],fraction)])
	var forward: Vector3 = (actor.visual_root.global_basis*actor.model_local_forward).normalized()
	var best: Dictionary = {}
	var nearest := INF
	for endpoints in rays:
		if endpoints[0].distance_squared_to(endpoints[1]) < 0.00000001: continue
		var query := PhysicsRayQueryParameters3D.create(endpoints[0],endpoints[1])
		query.exclude = [actor.get_rid()]
		var hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): continue
		var target := hit.collider as Node3D
		while target and target != actor and not target.has_method("take_damage"):
			target = target.get_parent() as Node3D
		if not target or target == actor: continue
		var offset: Vector3 = target.global_position-actor.global_position
		if absf(offset.y) > 1.3: continue
		offset.y = 0
		var distance := offset.length()
		if distance > 2.4 or distance >= nearest or (distance > .05 and forward.dot(offset/distance) < .35): continue
		var sight := PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP,target.global_position+Vector3.UP)
		sight.exclude = [actor.get_rid()]
		var cover: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(sight)
		if not cover.is_empty() and cover.collider != target and not target.is_ancestor_of(cover.collider): continue
		best = {"target":target,"position":hit.position,"source_seconds":time}
		nearest = distance
	if not best.is_empty(): _landed = true
	return best
