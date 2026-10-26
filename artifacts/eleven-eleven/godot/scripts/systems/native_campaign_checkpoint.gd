extends RefCounted

## Strict local story checkpoint. Never used for account rewards or purchases.
const SCHEMA := "echo-sector11-campaign-v1"
const PATH := "user://sector11_campaign_v1.json"
const MAX_BYTES := 32768
const EVENTS := ["specimen","archive","reactor","decon","mirror","lab","hospital"]
const FLAGS := {
	"specimen":["terminal_read"],
	"archive":["shard_shizuka","shard_yuki","shard_sector11","archive_decoded"],
	"reactor":["breaker_a_done","breaker_b_done"],
	"decon":["override_done"],
	"mirror":["mirror_inspected","override_done"],
	"lab":["confrontation_done","contract_done","revenge_done","wish_done"],
	"hospital":["bed_awakened","mark_revealed"]
}
static func initial() -> Dictionary:
	return {"schema":SCHEMA,"completed":[],"flags":{}}
static func validate(raw: Variant) -> Dictionary:
	if not raw is Dictionary or raw.get("schema")!=SCHEMA: return {}
	if raw.size()!=3 and not (raw.size()==4 and raw.has("presentation")): return {}
	var completed: Variant=raw.get("completed")
	var flags: Variant=raw.get("flags")
	if not completed is Array or completed.size()>EVENTS.size() or not flags is Dictionary: return {}
	for index in completed.size():
		if completed[index]!=EVENTS[index]: return {}
	for room in flags:
		var index: int=EVENTS.find(room)
		if index<0 or index>completed.size() or not flags[room] is Dictionary: return {}
		for key in flags[room]:
			if key not in FLAGS[room] or not flags[room][key] is bool: return {}
		if room=="archive" and flags[room].get("archive_decoded",false):
			for shard in ["shard_shizuka","shard_yuki","shard_sector11"]:
				if not flags[room].get(shard,false): return {}
		if room=="lab":
			var last := true
			for key in FLAGS.lab:
				var value: bool=flags.lab.get(key,false)
				if value and not last: return {}
				last=value
		if room=="hospital" and flags[room].get("mark_revealed",false) and not flags[room].get("bed_awakened",false): return {}
	for room in completed:
		for key in FLAGS[room]:
			if not flags.get(room,{}).get(key,false): return {}
	if raw.has("presentation") and not valid_presentation(raw.presentation, completed, flags): return {}
	return raw.duplicate(true)

static func valid_presentation(value: Variant, completed: Array, flags: Dictionary) -> bool:
	# Optional, non-authoritative resume cursor. Old v1 saves remain valid.
	if not value is Dictionary or completed.size()!=5: return false
	if value.size() != 2 and not (value.size() == 3 and value.has("encounter")): return false
	if value.get("beat") not in ["pact","accepted","revenge","wish"]: return false
	var elapsed: Variant = value.get("elapsed")
	if not (elapsed is float or elapsed is int) or not is_finite(float(elapsed)) or elapsed<0 or elapsed>90: return false
	var lab: Dictionary = flags.get("lab",{})
	if not lab.get("confrontation_done",false) or lab.get("wish_done",false): return false
	if value.has("encounter"):
		if value.beat not in ["pact", "accepted"] or not valid_encounter_cursor(value.encounter, lab.get("contract_done", false)): return false
	match value.beat:
		"pact": return not lab.get("contract_done",false)
		"accepted","revenge": return lab.get("contract_done",false) and not lab.get("revenge_done",false)
		"wish": return lab.get("revenge_done",false)
	return false

static func valid_encounter_cursor(value: Variant, accepted: bool) -> bool:
	if not value is Dictionary or (value.size() != 4 and not (value.size() == 5 and value.has("answer"))): return false
	if not _whole(value.get("step"), 0, 8) or not _whole(value.get("questions"), 0, 7): return false
	if not value.get("deferred") is bool: return false
	var look: Variant = value.get("look")
	if not look is Array or look.size() != 2: return false
	for index in 2:
		if not (look[index] is int or look[index] is float) or not is_finite(float(look[index])): return false
		if absf(float(look[index])) > (.5 if index == 0 else .3): return false
	var step := int(value.step)
	var questions := int(value.questions)
	if accepted != (step >= 6): return false
	if step < 4 and questions != 0: return false
	if step >= 5 and questions != 7: return false
	if value.has("answer"):
		if not _whole(value.answer, -1, 2): return false
		var answer := int(value.answer)
		if answer >= 0 and (step != 4 or not (questions & (1 << answer))): return false
	return not value.deferred or (step == 5 and not accepted)

static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum and float(value) == floorf(float(value))
static func advance(raw: Dictionary, room: String) -> Dictionary:
	var clean:=validate(raw)
	if clean.is_empty(): return {}
	if clean.completed.size()>=EVENTS.size() or room!=EVENTS[clean.completed.size()]: return {}
	clean.completed.append(room)
	return validate(clean)
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file:=FileAccess.open(path,FileAccess.READ)
	if not file: return {}
	var length:=file.get_length()
	file.close()
	if length>MAX_BYTES: return {}
	var parser:=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK: return {}
	return validate(parser.data)
static func preserves_progress(previous:Dictionary, next:Dictionary) -> bool:
	if next.completed.size()<previous.completed.size(): return false
	for room in previous.flags:
		for key in previous.flags[room]:
			if previous.flags[room][key] and not next.flags.get(room,{}).get(key,false): return false
	return true
static func load_checkpoint(path: String=PATH) -> Dictionary:
	var clean:=read(path)
	return read(path+".bak") if clean.is_empty() else clean
static func save_checkpoint(raw: Dictionary, path: String = PATH) -> bool:
	var clean := validate(raw)
	if clean.is_empty(): return false
	var previous:=load_checkpoint(path)
	if not previous.is_empty() and not preserves_progress(previous,clean): return false
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if not file: return false
	file.store_string(JSON.stringify(clean))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or read(temporary).is_empty():
		DirAccess.remove_absolute(temporary)
		return false
	if not read(path).is_empty():
		var backup_temporary := path + ".bak.tmp"
		if DirAccess.copy_absolute(path, backup_temporary) != OK or read(backup_temporary).is_empty() or DirAccess.rename_absolute(backup_temporary, path + ".bak") != OK:
			if FileAccess.file_exists(backup_temporary): DirAccess.remove_absolute(backup_temporary)
			DirAccess.remove_absolute(temporary)
			return false
	var result := DirAccess.rename_absolute(temporary, path)
	if result != OK: DirAccess.remove_absolute(temporary)
	return result == OK
