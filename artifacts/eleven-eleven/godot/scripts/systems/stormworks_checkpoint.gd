extends RefCounted

const Route = preload("res://scripts/systems/stormworks_route.gd")
const SCHEMA := "echo-stormworks-checkpoint-v2"

static func initial() -> Dictionary:
	return {"schema":SCHEMA,"layout_revision":Route.REVISION,"stage":0,"course_step":0}

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= low and value <= high

static func decode(value: Variant) -> Dictionary:
	if not value is Dictionary:return {}
	if value.get("schema") == "echo-maintenance-preview-v1":
		if not _integer(value.get("stage"),0,7):return {}
		var migrated := initial()
		# Preserve previously completed routes; intermediate anchors belong to
		# the rejected room and cannot award stages in this new layout.
		if int(value.stage) == 7:
			migrated.stage = 7
			migrated.course_step = 3
		return migrated
	if value.get("schema") != SCHEMA or value.get("layout_revision") != Route.REVISION:return {}
	if not _integer(value.get("stage"),0,7) or not _integer(value.get("course_step"),0,3):return {}
	var stage := int(value.stage)
	var step := int(value.course_step)
	if stage < 2 and step != 0:return {}
	if stage == 2 and step > 2:return {}
	if stage >= 3 and step != 3:return {}
	return {"schema":SCHEMA,"layout_revision":Route.REVISION,"stage":stage,"course_step":step}

static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:return {}
	return decode(parser.data)

static func load_checkpoint(path: String) -> Dictionary:
	var state := read(path)
	return read(path+".bak") if state.is_empty() else state

static func save_checkpoint(state: Dictionary, path: String) -> bool:
	var valid := decode(state)
	if valid.is_empty() or valid != state:return false
	var temporary := path+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if not file:return false
	file.store_string(JSON.stringify(valid));file.flush();file.close()
	if read(temporary) != valid:return false
	if not read(path).is_empty():
		if DirAccess.copy_absolute(path,path+".bak.tmp") != OK:return false
		if read(path+".bak.tmp").is_empty():return false
		if DirAccess.rename_absolute(path+".bak.tmp",path+".bak") != OK:return false
	return DirAccess.rename_absolute(temporary,path) == OK and read(path) == valid
