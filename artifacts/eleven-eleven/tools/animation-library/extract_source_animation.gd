extends SceneTree

## Run only in an isolated, key-preserving imported-motion project.
## This tool annotates derived playback facts; every imported key is compared
## again after saving. It never replaces a player or grants gameplay state.
func _initialize() -> void: _run.call_deferred()
func fail(message:String) -> void:
	push_error(message)
	quit(2)
func _run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=3: fail("Expected scene, measured facts and new output library");return
	var output:=ProjectSettings.globalize_path(args[2]).simplify_path().replace("\\","/")
	if output.contains("/golden/") or output.contains("/single-walk-20260930/") or not output.ends_with(".res") or FileAccess.file_exists(output):
		fail("Output must be a new, unprotected derived library");return
	var facts:Variant=JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	if not facts is Dictionary or facts.get("native_fps")!=30 or facts.get("source_glb_sha256")!=FileAccess.get_sha256(args[0]):
		fail("Native source identity/timing facts do not match imported GLB");return
	var packed:=load(args[0]) as PackedScene
	if not packed: fail("Verified scene cannot load");return
	var scene:=packed.instantiate()
	root.add_child(scene)
	var player:=scene.find_child("AnimationPlayer",true,false) as AnimationPlayer
	var action:String=facts.get("action","")
	if not player or not player.has_animation(action): fail("Exact imported action unavailable");return
	var source:Animation=player.get_animation(action)
	var derived:Animation=source.duplicate()
	derived.set_meta("source_ground_speed_mps",facts.get("source_ground_speed_mps",0.0))
	derived.set_meta("source_foot_contacts",facts.get("source_foot_contacts",{}))
	derived.set_meta("source_take_id",facts.get("take_id",""))
	derived.set_meta("source_native_fps",30)
	derived.set_meta("source_native_samples",facts.get("native_samples",0))
	derived.set_meta("source_blend_sha256",facts.get("blend_sha256",""))
	var library:=AnimationLibrary.new()
	library.add_animation(action,derived)
	if ResourceSaver.save(library,output)!=OK: fail("Derived library save failed");return
	var saved:=ResourceLoader.load(output,"AnimationLibrary",ResourceLoader.CACHE_MODE_IGNORE) as AnimationLibrary
	if not saved or not saved.has_animation(action): fail("Saved standalone library cannot reload");return
	var replay:Animation=saved.get_animation(action)
	if source.get_track_count()!=replay.get_track_count() or source.length!=replay.length: fail("Source track count or duration changed");return
	var keys:=0
	for track in source.get_track_count():
		if source.track_get_path(track)!=replay.track_get_path(track) or source.track_get_type(track)!=replay.track_get_type(track) or source.track_get_key_count(track)!=replay.track_get_key_count(track):
			fail("Saved source track identity changed");return
		for key in source.track_get_key_count(track):
			if source.track_get_key_time(track,key)!=replay.track_get_key_time(track,key) or source.track_get_key_value(track,key)!=replay.track_get_key_value(track,key):
				fail("Saved imported source key changed");return
			keys+=1
	var report:Dictionary={"status":"PASS","keys_compared_exactly":keys,"tracks":source.get_track_count(),"duration":source.length,"output":output,"library_sha256":FileAccess.get_sha256(output),"source_glb_sha256":facts.source_glb_sha256,"native_fps":30,"source_take_id":facts.take_id,"source_keys_modified":false,"scope":"Standalone animation plus playback/contact metadata; no runtime replacement"}
	var file:=FileAccess.open(output+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("STANDALONE_SOURCE_ANIMATION ",JSON.stringify(report))
	scene.queue_free()
	await process_frame
	quit(0)
