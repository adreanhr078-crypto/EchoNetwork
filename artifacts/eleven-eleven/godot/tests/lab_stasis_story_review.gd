extends "res://tests/post_contract_journey_review.gd"

## The normal public revenge/wish/breach journey owns every state transition.
## Inspect its actually earned wish checkpoint, without invoking the event.
func _snapshot_profile(label: String) -> bool:
	if not super._snapshot_profile(label):
		return false
	if label != "wish":
		return true
	var architecture: Node = room.find_child("ClinicalLabArchitecture", true, false)
	if not _check(room.wish_done and room._stasis_digits.visible and room._stasis_digits.text == "11:11",
		"Actual wish lost the original story-owned 11:11 digits"):
		return false
	if not _check(bool(architecture.stasis_display_material.get_shader_parameter("stasis_active")),
		"Actual earned wish did not update the clinical display finish"):
		return false
	# The parent reaches this after fifteen real physics frames. Preserve the
	# latest presented public-camera frame without taking camera/input ownership.
	root.get_texture().get_image().save_png(folder + "earned-stasis-gameplay.png")
	return true
