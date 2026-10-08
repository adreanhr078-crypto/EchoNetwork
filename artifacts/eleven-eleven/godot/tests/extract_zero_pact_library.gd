extends SceneTree

## Extract an exact native AnimationLibrary from the read-only agree source.
## Geometry/textures/source keys are never edited or copied into the library.
const SOURCE="res://../art/production/tripo-20261007/zero-acting-v1/tripo-out/zero-acting-v1-20261008-retarget-81c938de/model.glb"
const LIBRARY="res://assets/animations/zero/zero_pact_agree_v1.res"

func _initialize() -> void:
	var source_hash:=FileAccess.get_sha256(SOURCE)
	var document:=GLTFDocument.new()
	var state:=GLTFState.new()
	assert(document.append_from_file(ProjectSettings.globalize_path(SOURCE),state)==OK)
	var model:=document.generate_scene(state,30.0,false,false)
	var player:=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	assert(player and player.has_animation("agree"))
	var animation:=player.get_animation("agree")
	assert(animation.get_track_count()==123 and absf(animation.length-4.03333330154419)<0.000001)
	var original_keys: Array=[]
	for track in animation.get_track_count():
		var keys: Array=[]
		for key in animation.track_get_key_count(track): keys.append([animation.track_get_key_time(track,key),animation.track_get_key_value(track,key)])
		original_keys.append(keys)
	var library:=AnimationLibrary.new()
	assert(library.add_animation("agree",animation)==OK)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/animations/zero"))
	assert(ResourceSaver.save(library,LIBRARY)==OK)
	var saved:=ResourceLoader.load(LIBRARY,"AnimationLibrary",ResourceLoader.CACHE_MODE_IGNORE) as AnimationLibrary
	assert(saved and saved.has_animation("agree"))
	var restored:=saved.get_animation("agree")
	assert(restored.length==animation.length and restored.get_track_count()==animation.get_track_count())
	var key_count:=0
	var worst:=0.0
	var worst_time:=0.0
	for track in restored.get_track_count():
		assert(restored.track_get_type(track)==animation.track_get_type(track) and restored.track_get_path(track)==animation.track_get_path(track))
		assert(restored.track_get_key_count(track)==original_keys[track].size())
		for key in restored.track_get_key_count(track):
			key_count+=1
			worst_time=maxf(worst_time,absf(restored.track_get_key_time(track,key)-float(original_keys[track][key][0])))
			var actual=restored.track_get_key_value(track,key)
			var expected=original_keys[track][key][1]
			var difference:=0.0
			if actual is Quaternion: difference=minf((actual-expected).length(),(actual+expected).length())
			elif actual is Vector3: difference=actual.distance_to(expected)
			else: assert(actual==expected)
			if difference>worst:
				worst=difference
				print("ZERO_LIBRARY_ROUNDTRIP track=",track," key=",key," type=",restored.track_get_type(track)," difference=",difference," actual=",actual," expected=",expected)
	assert(worst<0.000001,"Saved native resource must retain source keys within single precision serialization")
	assert(worst_time<0.000001,"Saved native timestamps must retain source timing within single precision serialization")
	assert(FileAccess.get_sha256(SOURCE)==source_hash)
	print("PASS extracted native agree library:",key_count,"keys/123tracks/",animation.length,"s; native binary roundtrip componentdifference=",worst," timestampdifference=",worst_time,"s; original source untouched")
	model.free()
	quit(0)
