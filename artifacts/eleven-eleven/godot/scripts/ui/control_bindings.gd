extends RefCounted

const ACTIONS := ["move_forward", "move_backward", "move_left", "move_right", "jump", "sprint", "dodge", "interact", "attack_light", "companion_scan"]
const RESERVED := [KEY_ESCAPE, KEY_TAB, KEY_I, KEY_M, KEY_V, KEY_R, KEY_F8, KEY_F, KEY_K]

static func current() -> Dictionary:
	var result := {}
	for action in ACTIONS:
		if not InputMap.has_action(action): continue
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				result[action] = int(event.physical_keycode if event.physical_keycode else event.keycode)
				break
	return result

static func caption(action: String) -> String:
	var bindings := current()
	return OS.get_keycode_string(bindings[action]) if bindings.has(action) else "—"

static func apply(raw: Variant) -> bool:
	if not raw is Dictionary: return false
	var checked := {}
	var used: Array[int] = []
	for action in ACTIONS:
		var defaults: Dictionary = ProjectSettings.get_setting("input/" + action, {})
		var key := 0
		for event in defaults.get("events", []):
			if event is InputEventKey:
				key = int(event.physical_keycode if event.physical_keycode else event.keycode)
				break
		if raw.has(action):
			if not raw[action] is int or raw[action] <= 0 or raw[action] > KEY_SPECIAL + 1024: return false
			key = raw[action]
		# A default reserved key may be retained, never reassigned to an action.
		if raw.has(action) and key in RESERVED and key != _default_key(action): return false
		if key and key in used: return false
		if key: used.append(key)
		checked[action] = key
	for action in checked:
		if not InputMap.has_action(action): continue
		Input.action_release(action)
		for event in InputMap.action_get_events(action):
			if event is InputEventKey: InputMap.action_erase_event(action, event)
		if checked[action]:
			var event := InputEventKey.new()
			event.physical_keycode = checked[action]
			InputMap.action_add_event(action, event)
	return true

static func _default_key(action: String) -> int:
	var defaults: Dictionary = ProjectSettings.get_setting("input/" + action, {})
	for event in defaults.get("events", []):
		if event is InputEventKey: return int(event.physical_keycode if event.physical_keycode else event.keycode)
	return 0
