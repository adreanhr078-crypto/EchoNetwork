extends Node

func _ready() -> void:
	var scene_path := "res://scenes/main.tscn"
	if OS.has_feature("web"):
		scene_path = "res://scenes/opening_web_room.tscn"
	get_tree().call_deferred("change_scene_to_file", scene_path)
