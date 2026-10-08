extends SceneTree
const Save=preload("res://scripts/systems/native_campaign_checkpoint.gd")
var path:String="user://campaign_checkpoint_review_%d.json" % OS.get_process_id()

func _initialize() -> void:
	var first:=Save.initial()
	assert(Save.validate(first)==first)
	for malformed in [null,[],{"schema":"wrong","completed":[],"flags":{}},{"schema":Save.SCHEMA,"completed":["archive"],"flags":{}},{"schema":Save.SCHEMA,"completed":[],"flags":{"lab":{"wish_done":true}}},{"schema":Save.SCHEMA,"completed":[],"flags":{"specimen":{"terminal_read":1}}}]:
		assert(Save.validate(malformed).is_empty(),"Invalid checkpoint must be rejected")
	assert(Save.save_checkpoint(first,path))
	first.flags.specimen={"terminal_read":true}
	var complete:=Save.advance(first,"specimen")
	assert(not complete.is_empty() and Save.save_checkpoint(complete,path))
	assert(Save.load_checkpoint(path)==complete)
	assert(not Save.save_checkpoint(Save.initial(),path),"Autosave must not erase accepted progress")
	var corrupt:=FileAccess.open(path,FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	assert(Save.load_checkpoint(path)==Save.initial(),"Corrupt primary must recover the last verified backup")
	assert(Save.save_checkpoint(complete,path))
	var archive:=complete.duplicate(true)
	archive.flags.archive={"shard_shizuka":true}
	assert(Save.save_checkpoint(archive,path))
	assert(not Save.save_checkpoint(complete,path),"A collected shard cannot regress before the archive is complete")
	var forged:=archive.duplicate(true)
	forged.flags.archive.archive_decoded=true
	assert(Save.validate(forged).is_empty(),"Archive decoding requires all three actual fragments")
	assert(not Save.save_checkpoint(forged,path) and Save.load_checkpoint(path)==archive,"Rejected data must preserve the committed save")
	assert(not Save.save_checkpoint(archive,path+"/missing.json"),"Failed storage must be reported")
	forged=archive.duplicate(true)
	forged.completed.append("reactor")
	assert(Save.validate(forged).is_empty(),"Traversal order cannot skip archive")
	var huge:=FileAccess.open(path+".oversize",FileAccess.WRITE)
	huge.store_string(" ".repeat(Save.MAX_BYTES+1))
	huge.close()
	assert(Save.read(path+".oversize").is_empty(),"Unbounded local data must not be parsed")
	for suffix in ["",".bak",".tmp",".bak.tmp",".oversize"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	print("PASS campaign checkpoint: strict types/order, no phase skipping, monotonic flags, corrupt backup recovery, rejected writes preserve committed state, bounded input")
	quit()
