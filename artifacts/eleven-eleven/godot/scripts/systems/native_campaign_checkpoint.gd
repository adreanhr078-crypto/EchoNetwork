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
	if not raw is Dictionary or raw.size()!=3 or raw.get("schema")!=SCHEMA: return {}
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
	return raw.duplicate(true)
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
