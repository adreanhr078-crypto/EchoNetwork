extends RefCounted

## Local traversal progress only. No rewards, powers or account state.
const LEGACY_SCHEMA := "echo-native-journey-v1"
const SCHEMA := "echo-native-journey-v2"
const PATH := "user://native_journey_v1.json"
const EVENTS := ["opening_completed", "maintenance_completed", "security_entered", "security_completed"]
const SECURITY_INITIAL := {"gate_open": false, "service_trace": false, "scanner_trace": false}

static func validate(raw: Variant) -> Dictionary:
	if not raw is Dictionary: return {}
	var legacy: bool = raw.get("schema") == LEGACY_SCHEMA
	if raw.size() != (2 if legacy else 3) or (not legacy and raw.get("schema") != SCHEMA): return {}
	var completed: Variant = raw.get("completed")
	if not completed is Array or completed.size() > (3 if legacy else EVENTS.size()): return {}
	for index in range(completed.size()):
		if not completed[index] is String or completed[index] != EVENTS[index]: return {}
	var security: Variant = SECURITY_INITIAL.duplicate() if legacy else raw.get("security")
	if not security is Dictionary or security.size() != SECURITY_INITIAL.size(): return {}
	for key in SECURITY_INITIAL:
		if not security.get(key) is bool: return {}
	if completed.size() < 3 and security != SECURITY_INITIAL: return {}
	if completed.size() >= 4 and not security.gate_open: return {}
	return {"schema": SCHEMA, "completed": completed.duplicate(), "security":security.duplicate()}

static func initial() -> Dictionary:
	return {"schema": SCHEMA, "completed": [], "security": SECURITY_INITIAL.duplicate()}

static func advance(raw: Dictionary, event: String) -> Dictionary:
	var clean := validate(raw)
	if clean.is_empty(): return {}
	var count: int = clean.completed.size()
	if event in clean.completed: return clean
	if count >= EVENTS.size() or event != EVENTS[count]: return {}
	clean.completed.append(event)
	return validate(clean)

static func with_security(raw: Dictionary, state: Dictionary) -> Dictionary:
	var clean := validate(raw)
	if clean.is_empty() or clean.completed.size() < 3: return {}
	# Discoveries and opened passages cannot be revoked by retry/stale signals.
	for key in SECURITY_INITIAL:
		if clean.security[key] and not state.get(key, false): return {}
	clean.security = state.duplicate()
	return validate(clean)

static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return {}
	return validate(parser.data)

static func load_checkpoint(path: String = PATH) -> Dictionary:
	var clean := read(path)
	return read(path + ".bak") if clean.is_empty() else clean

static func save_checkpoint(raw: Dictionary, path: String = PATH) -> bool:
	var clean := validate(raw)
	if clean.is_empty(): return false
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
