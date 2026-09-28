class_name SaveManager
extends RefCounted

const DEFAULT_SAVE_PATH := "user://minato_phase2_save.json"
const OPENING_SAVE_PATH := "user://system_opening_v1.json"
const OPENING_SCHEMA := "echo-opening-local-v1"

# Native solo-story state only. Never contains account rewards or server receipts.
static func validate_opening_checkpoint(raw: Variant) -> Dictionary:
	if not raw is Dictionary or raw.get("schema") != OPENING_SCHEMA:
		return {}
	var milestones: Variant = raw.get("milestones")
	var terminal: Variant = raw.get("terminal")
	if not milestones is Dictionary or not terminal is Dictionary:
		return {}
	var clean := {"schema": OPENING_SCHEMA, "milestones": {}, "terminal": {}}
	for key in ["wake", "clock", "photo", "memory", "terminal", "conduit", "ending"]:
		if not milestones.get(key) is bool:
			return {}
		clean.milestones[key] = milestones[key]
	var state: Dictionary = clean.milestones
	if (state.clock and not state.wake) or (state.photo and not state.clock) or (state.memory and not state.photo):
		return {}
	if ((state.terminal or state.conduit) and not state.memory) or (state.ending and not (state.terminal and state.conduit)):
		return {}
	for key in ["frequency", "phase", "harmonic"]:
		var value: Variant = terminal.get(key)
		if not (value is float or value is int) or not is_finite(float(value)):
			return {}
		var minimum := 50.0 if key == "frequency" else (1.0 if key == "harmonic" else 0.0)
		var maximum := 150.0 if key == "frequency" else (10.0 if key == "harmonic" else 180.0)
		if float(value) < minimum or float(value) > maximum:
			return {}
		clean.terminal[key] = float(value)
	return clean

static func save_opening_checkpoint(data: Dictionary, path: String = OPENING_SAVE_PATH) -> bool:
	var clean := validate_opening_checkpoint(data)
	if clean.is_empty():
		return false
	var temporary := path + ".tmp"
	if not save_to_file(clean, temporary):
		return false
	# A corrupt primary must not replace the last valid recovery checkpoint.
	if FileAccess.file_exists(path) and not validate_opening_checkpoint(load_from_file(path)).is_empty():
		if DirAccess.copy_absolute(path, path + ".bak") != OK:
			return false
	return DirAccess.rename_absolute(temporary, path) == OK

static func load_opening_checkpoint(path: String = OPENING_SAVE_PATH) -> Dictionary:
	var primary := validate_opening_checkpoint(load_from_file(path))
	if not primary.is_empty():
		return primary
	return validate_opening_checkpoint(load_from_file(path + ".bak"))

static func create_save_dictionary(player: Node = null, clock: RefCounted = null, household_mgr: RefCounted = null, npcs: Array = []) -> Dictionary:
	var save_dict = {
		"version": 2,
		"timestamp": Time.get_unix_time_from_system() if OS.has_feature("editor") or true else 0,
		"wallet": {},
		"inventory": {},
		"needs": {},
		"clock": {},
		"households": {},
		"npcs": {}
	}

	if player:
		if "wallet" in player and player.wallet != null and player.wallet.has_method("serialize"):
			save_dict["wallet"] = player.wallet.serialize()
		if "inventory" in player and player.inventory != null and player.inventory.has_method("serialize"):
			save_dict["inventory"] = player.inventory.serialize()
		if "needs" in player and player.needs != null and player.needs.has_method("serialize"):
			save_dict["needs"] = player.needs.serialize()

	if clock and clock.has_method("serialize"):
		save_dict["clock"] = clock.serialize()

	if household_mgr and household_mgr.has_method("serialize"):
		save_dict["households"] = household_mgr.serialize().get("households", {})

	for npc in npcs:
		if npc and "npc_id" in npc:
			save_dict["npcs"][npc.npc_id] = {
				"talk_count": npc.get("talk_count") if "talk_count" in npc else 0,
				"familiarity_tier": int(npc.get("familiarity_tier")) if "familiarity_tier" in npc else 0
			}

	return save_dict

static func apply_save_dictionary(save_dict: Dictionary, player: Node = null, clock: RefCounted = null, household_mgr: RefCounted = null, npcs: Array = []) -> bool:
	if save_dict.is_empty():
		return false

	if player:
		if "wallet" in player and player.wallet != null and player.wallet.has_method("deserialize"):
			player.wallet.deserialize(save_dict.get("wallet", {}))
		if "inventory" in player and player.inventory != null and player.inventory.has_method("deserialize"):
			player.inventory.deserialize(save_dict.get("inventory", {}))
		if "needs" in player and player.needs != null and player.needs.has_method("deserialize"):
			player.needs.deserialize(save_dict.get("needs", {}))

	if clock and clock.has_method("deserialize"):
		clock.deserialize(save_dict.get("clock", {}))

	if household_mgr and household_mgr.has_method("deserialize"):
		household_mgr.deserialize({"households": save_dict.get("households", {})})

	var npc_dict = save_dict.get("npcs", {})
	for npc in npcs:
		if npc and "npc_id" in npc and npc_dict.has(npc.npc_id):
			var data = npc_dict[npc.npc_id]
			if "talk_count" in npc:
				npc.talk_count = int(data.get("talk_count", 0))
			if "familiarity_tier" in npc:
				npc.familiarity_tier = int(data.get("familiarity_tier", 0))

	return true

static func save_to_file(data: Dictionary, path: String = DEFAULT_SAVE_PATH) -> bool:
	var json_str = JSON.stringify(data, "\t")
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(json_str)
	file.close()
	return true

static func load_from_file(path: String = DEFAULT_SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var err = json.parse(text)
	if err == OK and json.data is Dictionary:
		return json.data
	return {}
