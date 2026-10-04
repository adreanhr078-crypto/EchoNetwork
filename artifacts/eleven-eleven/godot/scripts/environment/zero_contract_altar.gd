extends StaticBody3D

## Zero Contract Altar for Room 10/11 (Dr. Kinja's Lab & Zero Contract Chamber)
## Implements interactive interface for accepting Zero's shadow contract.

func trigger_interaction(_interactor: Node = null) -> Dictionary:
	var room := get_parent()
	if room and room.has_method("accept_zero_contract"):
		return room.accept_zero_contract()
	return {"success": false, "reason": "no_room_parent"}
