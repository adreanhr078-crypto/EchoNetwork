class_name SaveManager
extends RefCounted

const DEFAULT_SAVE_PATH := "user://minato_phase2_save.json"

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
