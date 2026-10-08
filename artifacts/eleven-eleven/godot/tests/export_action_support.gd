extends SceneTree
var output: String=ProjectSettings.globalize_path("res://../audits/evidence/quality-repair-20261006/action-support/")
func _initialize() -> void: _run.call_deferred()
func matrix(t: Transform3D) -> Array:
	return [[t.basis.x.x,t.basis.y.x,t.basis.z.x,t.origin.x],[t.basis.x.y,t.basis.y.y,t.basis.z.y,t.origin.y],[t.basis.x.z,t.basis.y.z,t.basis.z.z,t.origin.z]]
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var p=load("res://scenes/player/echo_player.tscn").instantiate()
	root.add_child(p)
	for clip_name in ["DODGE_ROLL","HARD_LANDING","ATTACK_1","ATTACK_2","ATTACK_3","preset_biped_roll_001","preset_biped_hard_landing_001"]:
		if p.animation_player.get_animation_library("").has_animation(clip_name): p.animation_player.get_animation_library("").remove_animation(clip_name)
	preload("res://scripts/player/mixamo_animation_bridge.gd").inject_animations(p.animation_player,true)
	p.set_physics_process(false)
	p.set_process(false)
	var rig: Skeleton3D=p.find_child("Skeleton3D",true,false)
	var skin_mesh: MeshInstance3D
	for m in p.visual_root.find_children("*","MeshInstance3D",true,false):
		if m.skin and m.mesh: skin_mesh=m;break
	var vertices: Array=[]
	var weights: Array=[]
	var bones: Array=[]
	for surface in skin_mesh.mesh.get_surface_count():
		var a=skin_mesh.mesh.surface_get_arrays(surface)
		var count: int=a[Mesh.ARRAY_BONES].size()/a[Mesh.ARRAY_VERTEX].size()
		for i in a[Mesh.ARRAY_VERTEX].size():
			var v: Vector3=a[Mesh.ARRAY_VERTEX][i]
			vertices.append([v.x,v.y,v.z,1.0])
			weights.append(Array(a[Mesh.ARRAY_WEIGHTS].slice(i*count,(i+1)*count)))
			bones.append(Array(a[Mesh.ARRAY_BONES].slice(i*count,(i+1)*count)))
	var bind_ids: Array=[]
	var rest: Array=[]
	for bind in skin_mesh.skin.get_bind_count():
		var bone:=skin_mesh.skin.get_bind_bone(bind)
		if bone<0: bone=rig.find_bone(skin_mesh.skin.get_bind_name(bind))
		bind_ids.append(bone)
		rest.append(matrix(rig.get_bone_global_rest(bone)*skin_mesh.skin.get_bind_pose(bind)))
	var data: Dictionary={"vertices":vertices,"weights":weights,"bones":bones,"rest":rest,"bone_names":bind_ids.map(func(id: int): return rig.get_bone_name(id)),"clips":{}}
	for name in ["DODGE_ROLL","HARD_LANDING","ATTACK_1","ATTACK_2","ATTACK_3"]:
		var clip: Animation=p.animation_player.get_animation(name)
		var samples: Array=[]
		var track_map: Dictionary={}
		var root_track: int=-1
		for t in clip.get_track_count():
			var bone:=rig.find_bone(String(clip.track_get_path(t)).get_slice(":",1))
			if clip.track_get_type(t)==Animation.TYPE_ROTATION_3D: track_map[bone]=t
			if clip.track_get_type(t)==Animation.TYPE_POSITION_3D: root_track=t
		for key in clip.track_get_key_count(root_track):
			var time:=clip.track_get_key_time(root_track,key)
			var poses: Array[Transform3D]=[]
			for bone in rig.get_bone_count():
				var local:=rig.get_bone_rest(bone)
				if track_map.has(bone): local.basis=Basis(clip.rotation_track_interpolate(track_map[bone],time))
				if bone==0: local.origin=clip.position_track_interpolate(root_track,time)
				var parent:=rig.get_bone_parent(bone)
				poses.append(poses[parent]*local if parent>=0 else local)
			var matrices: Array=[]
			for bind in bind_ids.size(): matrices.append(matrix(poses[bind_ids[bind]]*skin_mesh.skin.get_bind_pose(bind)))
			samples.append({"time":time,"matrices":matrices})
		data.clips[name]=samples
	var file:=FileAccess.open(output+"samples.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	print("Exported real rig/rest/weighted-skin action samples")
	p.queue_free()
	await process_frame
	quit()
