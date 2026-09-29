extends Node3D

## Existing proximity/keyboard/touch contract; physical interaction only.
func on_interacted(interactor: Node3D, _verb: int) -> Dictionary:
	return get_parent().request_service_release(interactor)
