extends Node

const NATIVE_SCENE := "res://scenes/native_journey.tscn"

func _ready() -> void:
	var scene_path := NATIVE_SCENE
	if OS.has_feature("web"):
		scene_path = "res://scenes/opening_web_room.tscn"
	elif "--maintenance-preview" in OS.get_cmdline_user_args():
		# Explicit maintenance-only review preserves its existing boundary.
		scene_path = "res://scenes/system_journey_preview.tscn"
	get_tree().call_deferred("change_scene_to_file", scene_path)
