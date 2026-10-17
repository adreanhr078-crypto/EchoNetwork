extends Node3D

## Optional source-authored record. Never unlocks a gate or grants a reward.
var room: Node3D
var tank_index := 0

func on_interacted(actor: Node3D, _verb: int) -> Dictionary:
	if not is_instance_valid(room) or actor!=room.player or not is_instance_valid(actor):
		return {"accepted":false,"reason":"inactive_room"}
	if actor.control_locked or actor.global_position.distance_to(global_position)>2.4:
		return {"accepted":false,"reason":"out_of_reach"}
	var record: Dictionary = room.inspect_tank(tank_index)
	if record.get("accepted",false): room.specimen_record_requested.emit(tank_index)
	return record
