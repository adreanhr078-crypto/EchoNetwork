extends Node

@export var disable_ik: bool = false
var _elapsed: float = 0.0
var _phase: int = 0
var _walk_reported: bool = false
var _run_reported: bool = false
var _ik_disabled: bool = false
var _player: CharacterBody3D

func _ready() -> void:
	_player = get_parent().get_node("EchoPlayer") as CharacterBody3D

func _process(delta: float) -> void:
	_elapsed += delta
	if disable_ik and not _ik_disabled and _elapsed >= 5.8:
		_ik_disabled = true
		var skeleton := _player.find_child("Skeleton3D", true, false) as Skeleton3D
		var modifier := skeleton.get_node_or_null("FootGroundingModifier")
		if modifier:
			modifier.set("active", false)
	if _elapsed >= 6.0 and _phase == 0:
		_phase = 1
		_player.call("set_mobile_input_vector", Vector2(0.0, -1.0))
	if _elapsed >= 8.5 and not _walk_reported:
		_walk_reported = true
		_report_grounding()
	if _elapsed >= 8.8 and _phase == 1:
		_phase = 2
		Input.action_press("sprint")
	if _elapsed >= 10.5 and not _run_reported:
		_run_reported = true
		_report_grounding()
	if _elapsed >= 10.8 and _phase == 2:
		_phase = 3
		Input.action_release("sprint")
		_player.call("set_mobile_input_vector", Vector2.ZERO)
		_report_grounding()
	if _elapsed >= 12.0:
		get_tree().quit()

func _report_grounding() -> void:
	var skeleton := _player.find_child("Skeleton3D", true, false) as Skeleton3D
	var modifier := skeleton.get_node_or_null("FootGroundingModifier")
	print("FOOT_IK_REPORT anim=", _player.get("current_anim"), " floor=", _player.is_on_floor(), " pos=", _player.global_position)
	if modifier:
		for field in ["_left", "_right"]:
			var chain = modifier.get(field)
			var toe_pose: Transform3D = skeleton.get_bone_global_pose(chain.toe)
			var toe_world := skeleton.global_transform * toe_pose.origin
			print("FOOT_IK_CONTACT ", field, " planted=", chain.planted, " toe=", toe_world, " target=", chain.target_world, " error=", toe_world.distance_to(chain.target_world))
	else:
		print("FOOT_IK_REPORT missing modifier")
