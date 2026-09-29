extends Node

func _ready() -> void:
	var scene_path := "res://scenes/opening_native_room.tscn"
	if OS.has_feature("web"):
		scene_path = "res://scenes/opening_web_room.tscn"
	elif "--maintenance-preview" in OS.get_cmdline_user_args():
		# Explicit review launch; default opening and Web boundaries stay bounded.
		scene_path = "res://scenes/system_journey_preview.tscn"
	get_tree().call_deferred("change_scene_to_file", scene_path)
