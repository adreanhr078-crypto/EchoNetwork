extends SceneTree

func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var curves: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../audits/evidence/quality-repair-20261006/action-support/curves.json"))
	var p=load("res://scenes/player/echo_player.tscn").instantiate()
	root.add_child(p)
	for clip_name in ["DODGE_ROLL","HARD_LANDING","ATTACK_1","ATTACK_2","ATTACK_3","preset_biped_roll_001","preset_biped_hard_landing_001"]:
		if p.animation_player.get_animation_library("").has_animation(clip_name): p.animation_player.get_animation_library("").remove_animation(clip_name)
	preload("res://scripts/player/mixamo_animation_bridge.gd").inject_animations(p.animation_player,true)
	p.set_physics_process(false)
	p.set_process(false)
	var rig: Skeleton3D=p.find_child("Skeleton3D",true,false)
	var signature: String=""
	for bone in rig.get_bone_count(): signature+=rig.get_bone_name(bone)+str(rig.get_bone_rest(bone))
	var library:=AnimationLibrary.new()
	library.set_meta("rig_signature",signature.sha256_text())
	library.set_meta("support_vertex_count",curves.vertex_count)
	library.set_meta("method","anatomical rest conversion + exact weighted-skin floor support; source/Golden untouched")
	for name in curves.curves:
		var clip: Animation=p.animation_player.get_animation(name).duplicate(true)
		var root_track: int=-1
		for t in clip.get_track_count():
			if clip.track_get_type(t)==Animation.TYPE_POSITION_3D and String(clip.track_get_path(t)).ends_with(":tripo__Root"): root_track=t
		if root_track<0:
			push_error("Missing action pelvis/root position")
			quit(1)
			return
		for key in clip.track_get_key_count(root_track):
			var support: Dictionary=curves.curves[name][key]
			if absf(clip.track_get_key_time(root_track,key)-support.time)>0.0001:
				push_error("Stale action support samples")
				quit(1)
				return
			clip.track_set_key_value(root_track,key,clip.track_get_key_value(root_track,key)+Vector3.UP*support.delta_y)
		library.add_animation(name,clip)
	var result:=ResourceSaver.save(library,"res://assets/animations/current_echo_actions_v1.res")
	print("Baked current rig actions: ",result)
	p.queue_free()
	await process_frame
	quit(0 if result==OK else 1)
