extends Node3D

## Existing proximity/keyboard/touch contract; physical interaction only.
func can_interact(interactor: Node3D) -> bool:
	return get_parent().can_release_service(interactor)

func on_interacted(interactor: Node3D, _verb: int) -> Dictionary:
	return get_parent().request_service_release(interactor)
