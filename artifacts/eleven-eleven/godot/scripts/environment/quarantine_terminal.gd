extends StaticBody3D

## Quarantine Override Terminal for Room 8 (Decontamination & Quarantine Wing)
## Implements interactive interface for quarantine override and blast gate unlocking.

func trigger_interaction(_interactor: Node = null) -> Dictionary:
	var wing := get_parent()
	if wing and wing.has_method("execute_quarantine_override"):
		return wing.execute_quarantine_override()
	return {"success": false, "reason": "no_wing_parent"}
