extends SceneTree

const Slot=preload("res://scripts/cinematics/zero_generated_model_slot.gd")
const ASSET="res://assets/characters/zero_manifestation_idle_v1.glb"
const SOURCE="res://../art/production/tripo-20261007/zero-humanoid-idle-v4/tripo-out/zero-humanoid-idle-v4-20261008-r-d77f057b/model.glb"

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	assert(FileAccess.get_sha256(ASSET)==FileAccess.get_sha256(SOURCE),"Runtime copy must preserve every original source byte")
	var config:=ConfigFile.new()
	assert(config.load(ASSET+".import")==OK)
	assert(config.get_value("params","animation/remove_immutable_tracks")==false)
	assert(config.get_value("params","animation/trimming")==false)
	var slot:=Slot.new()
	root.add_child(slot)
	assert(slot.load_profile("res://assets/characters/zero_manifestation_profile_v1.json"))
	assert(slot.body_animation_kind=="imported_native_clip" and slot.body_animation_verified)
	assert(slot.skeleton.get_bone_count()==41 and slot._eye_materials.size()==2)
	var imported: Animation=slot.source_player.get_animation("idle")
	var document:=GLTFDocument.new()
	var state:=GLTFState.new()
	assert(document.append_from_file(ProjectSettings.globalize_path(SOURCE),state)==OK)
	var source:=document.generate_scene(state,30.0,false,false)
	var source_player:=source.find_child("AnimationPlayer",true,false) as AnimationPlayer
	assert(source_player)
	var original:=source_player.get_animation("idle")
	assert(imported.get_track_count()==123 and imported.get_track_count()==original.get_track_count())
	assert(absf(imported.length-original.length)<0.000001)
	var keys:=0
	var worst:=0.0
	for track in original.get_track_count():
		assert(imported.track_get_type(track)==original.track_get_type(track))
		assert(imported.track_get_path(track)==original.track_get_path(track))
		assert(imported.track_get_key_count(track)==original.track_get_key_count(track))
		for key in original.track_get_key_count(track):
			keys+=1
			assert(absf(imported.track_get_key_time(track,key)-original.track_get_key_time(track,key))<0.000001)
			var actual=imported.track_get_key_value(track,key)
			var expected=original.track_get_key_value(track,key)
			var difference:=0.0
			if actual is Quaternion:
				# acos(dot(q,q)) can report an angle for identical quantized
				# quaternions. Compare stored components up to the equivalent sign.
				difference=minf((actual-expected).length(),(actual+expected).length())
			elif actual is Vector3: difference=actual.distance_to(expected)
			else: assert(actual==expected)
			worst=maxf(worst,difference)
	print("ZERO_IMPORT_KEY_COMPARE worst_component_or_vector_difference=",worst," keys=",keys)
	assert(worst<0.00001,"Asset-local importer must match the unoptimized source reconstruction")
	slot.tick(0,false,"manifested",0)
	for i in 3: await process_frame
	assert(slot.source_player.is_playing())
	slot.tick(0,true,"manifested",0)
	var frozen: Array[Transform3D]=[]
	for bone in slot.skeleton.get_bone_count(): frozen.append(slot.skeleton.get_bone_pose(bone))
	for i in 8: await process_frame
	for bone in slot.skeleton.get_bone_count(): assert(frozen[bone]==slot.skeleton.get_bone_pose(bone))
	var report:={"status":"CONNECTED_ASSET_IMPORT_FIDELITY_PASS_VISUAL_GATE_OPEN","source_sha256":FileAccess.get_sha256(SOURCE),"native_tracks":123,"native_keys":keys,"native_duration":imported.length,"max_key_difference":worst,"actual_skeleton_to_world":var_to_str(slot.skeleton.global_transform),"actual_skeleton_to_world_scale":var_to_str(slot.skeleton.global_basis.get_scale()),"native_reduced_pause_exact":true,"source_bytes_unchanged":true,"native_material_presentation":slot._material_presentation,"actor_source_fingers":false}
	var out:=ProjectSettings.globalize_path("res://../audits/evidence/room-color-cinematics-20261007/zero-native-idle-v4/connected-asset-fidelity.json")
	var file:=FileAccess.open(out,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	source.free()
	slot.queue_free()
	for i in 4: await process_frame
	print("PASS exact runtime Zero source copy:41bones/123tracks/",keys,"keys, complete native timing, source-key reconstruction fidelity, boundeyes, true native ReducedMotion pause")
	quit(0)
