extends StaticBody3D

## Master Security Override Terminal for Room 9 (The Mirror Chamber & Surveillance Hub)
## Implements interactive interface for lockdown override and North Blast Gate unlocking.

func trigger_interaction(_interactor: Node = null) -> Dictionary:
	var room := get_parent()
	if room and room.has_method("execute_lockdown_override"):
		return room.execute_lockdown_override()
	return {"success": false, "reason": "no_room_parent"}
