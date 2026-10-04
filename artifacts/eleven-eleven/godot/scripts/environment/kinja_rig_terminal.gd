extends StaticBody3D

## Kinja Neural Rig Terminal for Room 10 (Dr. Kinja's Lab)
## Implements interactive interface for starting the memory drowning confrontation.

func trigger_interaction(_interactor: Node = null) -> Dictionary:
	var room := get_parent()
	if room and room.has_method("initiate_memory_confrontation"):
		return room.initiate_memory_confrontation()
	return {"success": false, "reason": "no_room_parent"}
