extends Node3D

@export var action := "divert"

func on_interacted(interactor: Node3D, _verb: int) -> Dictionary:
	return get_parent().request_station(action, interactor, self)
