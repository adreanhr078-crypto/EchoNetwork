extends Node

const NATIVE_SCENE := "res://scenes/native_journey.tscn"

func _ready() -> void:
	# Official export templates intentionally ignore external --script/path
	# overrides. Review sessions use normal user arguments and packed resources.
	if not OS.has_feature("web") and "--review-cp24" in OS.get_cmdline_user_args():
		_launch_review.call_deferred()
		return
	var scene_path := NATIVE_SCENE
	if OS.has_feature("web"):
		scene_path = "res://scenes/opening_web_room.tscn"
	elif "--maintenance-preview" in OS.get_cmdline_user_args():
		# Explicit maintenance-only review preserves its existing boundary.
		scene_path = "res://scenes/system_journey_preview.tscn"
	get_tree().call_deferred("change_scene_to_file", scene_path)

func _launch_review() -> void:
	var smoke := "--review-smoke" in OS.get_cmdline_user_args()
	var save_root := "user://chapter_cp24_smoke_%d/" % OS.get_process_id() if smoke else "user://chapter_cp24_review/"
	DirAccess.make_dir_recursive_absolute(save_root)
	var main = load(NATIVE_SCENE).instantiate()
	main.native_checkpoint_path = save_root+"opening.json"
	main.native_preferences_path = save_root+"preferences.cfg"
	main.get_node("SystemJourneyPreview").checkpoint_path = save_root+"maintenance.json"
	main.get_node("NativeJourneyController").checkpoint_path = save_root+"route.json"
	main.get_node("NativeCampaignController").checkpoint_path = save_root+"campaign.json"
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	if smoke:
		var probe := preload("res://scripts/systems/native_review_probe.gd").new()
		probe.save_root = save_root
		main.add_child(probe)
	queue_free()
