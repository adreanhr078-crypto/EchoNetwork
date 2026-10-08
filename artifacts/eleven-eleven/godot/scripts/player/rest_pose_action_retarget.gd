extends RefCounted

## Current Echo rig only. Sources/rest meshes/Golden files are never rewritten.
## Foreign translations and absolute local quaternions cannot be copied into
## a different hierarchy. Solve shared anatomical poses in skeleton space.
static func adapt(source: Animation, source_rig: Skeleton3D, target: Skeleton3D, mapping: Dictionary, prefix: String) -> Animation:
	if not source or not source_rig or not target: return null
	var s_to_t := {}
	var t_to_s := {}
	var rotation_tracks := {}
	var position_tracks := {}
	for name in mapping:
		var si := source_rig.find_bone(name)
		var ti := target.find_bone(mapping[name])
		if si<0 or ti<0: return null
		s_to_t[si]=ti
		t_to_s[ti]=si
	for track in source.get_track_count():
		var bone := String(source.track_get_path(track)).get_slice(":",1)
		var si := source_rig.find_bone(bone)
		if si<0: continue
		if source.track_get_type(track)==Animation.TYPE_ROTATION_3D: rotation_tracks[si]=track
		if source.track_get_type(track)==Animation.TYPE_POSITION_3D: position_tracks[si]=track
	var s_hip := source_rig.find_bone("mixamorig_Hips")
	var t_root := target.find_bone("tripo__Root")
	var s_left := source_rig.get_bone_global_rest(source_rig.find_bone("mixamorig_LeftUpLeg")).origin
	var s_right := source_rig.get_bone_global_rest(source_rig.find_bone("mixamorig_RightUpLeg")).origin
	var t_left := target.get_bone_global_rest(mapping_index(source_rig,target,mapping,"mixamorig_LeftUpLeg")).origin
	var t_right := target.get_bone_global_rest(mapping_index(source_rig,target,mapping,"mixamorig_RightUpLeg")).origin
	var source_side := (s_left-s_right).normalized()
	var target_side := (t_left-t_right).normalized()
	var s_axes := Basis(source_side,Vector3.UP,source_side.cross(Vector3.UP)).orthonormalized()
	var t_axes := Basis(target_side,Vector3.UP,target_side.cross(Vector3.UP)).orthonormalized()
	var align := t_axes*s_axes.inverse()
	var offsets := {}
	for ti in t_to_s:
		var si: int = t_to_s[ti]
		var s_rest := source_rig.get_bone_global_rest(si)
		var t_rest := target.get_bone_global_rest(ti)
		var virtual_basis := t_rest.basis.orthonormalized()
		# Normalize A-rest limb directions into the source T-rest in memory.
		# Applying only a rest delta would fold Echo's relaxed arms into his body.
		if ti != t_root:
			for child in target.get_bone_children(ti):
				if not t_to_s.has(child): continue
				var source_child: int = t_to_s[child]
				var from := (target.get_bone_global_rest(child).origin-t_rest.origin).normalized()
				var to := (align*(source_rig.get_bone_global_rest(source_child).origin-s_rest.origin)).normalized()
				virtual_basis=Basis(Quaternion(from,to))*virtual_basis
				break
		offsets[ti]=s_rest.basis.orthonormalized().inverse()*align.inverse()*virtual_basis
	var hip_rest := (t_left+t_right)*0.5
	var root_rest := target.get_bone_global_rest(t_root)
	var hip_from_root := root_rest.affine_inverse()*hip_rest
	var source_foot := source_rig.get_bone_global_rest(source_rig.find_bone("mixamorig_LeftToeBase")).origin
	var target_foot := target.get_bone_global_rest(mapping_index(source_rig,target,mapping,"mixamorig_LeftToeBase")).origin
	var ratio := (hip_rest.y-target_foot.y)/(source_rig.get_bone_global_rest(s_hip).origin.y-source_foot.y)
	var result := Animation.new()
	result.length = source.length
	result.loop_mode = Animation.LOOP_NONE
	var output := {}
	for ti in t_to_s:
		var track := result.add_track(Animation.TYPE_ROTATION_3D)
		result.track_set_path(track,NodePath(prefix+":"+target.get_bone_name(ti)))
		output[ti]=track
	var root_position := result.add_track(Animation.TYPE_POSITION_3D)
	result.track_set_path(root_position,NodePath(prefix+":tripo__Root"))
	var samples := int(ceil(source.length*60))
	for frame in samples+1:
		var time := minf(source.length,frame/60.0)
		var s_poses: Array[Transform3D] = []
		for si in source_rig.get_bone_count():
			var local := source_rig.get_bone_rest(si)
			if rotation_tracks.has(si): local.basis=Basis(source.rotation_track_interpolate(rotation_tracks[si],time))
			if si==s_hip and position_tracks.has(si): local.origin=source.position_track_interpolate(position_tracks[si],time)
			var parent := source_rig.get_bone_parent(si)
			s_poses.append(s_poses[parent]*local if parent>=0 else local)
		var t_poses: Array[Transform3D] = []
		for ti in target.get_bone_count():
			var parent := target.get_bone_parent(ti)
			var local := target.get_bone_rest(ti)
			if t_to_s.has(ti):
				var si: int = t_to_s[ti]
				var desired: Basis = (align*s_poses[si].basis.orthonormalized()*offsets[ti]).orthonormalized()
				local.basis=(t_poses[parent].basis.inverse()*desired if parent>=0 else desired).orthonormalized()
				result.rotation_track_insert_key(output[ti],time,local.basis.get_rotation_quaternion().normalized())
				if ti == t_root:
					# Hips are halfway up Echo's root hierarchy. Preserve that pivot
					# while only the capsule owns horizontal travel.
					var hip_y := (s_poses[s_hip].origin.y-source_rig.get_bone_global_rest(s_hip).origin.y)*ratio
					local.origin=hip_rest+Vector3(0,hip_y,0)-desired*hip_from_root
					result.position_track_insert_key(root_position,time,local.origin)
			t_poses.append(t_poses[parent]*local if parent>=0 else local)
	return result

static func mapping_index(_source: Skeleton3D, target: Skeleton3D, mapping: Dictionary, name: String) -> int:
	return target.find_bone(mapping[name])
