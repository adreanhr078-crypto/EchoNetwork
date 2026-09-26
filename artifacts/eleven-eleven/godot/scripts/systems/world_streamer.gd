class_name WorldStreamer
extends Node

## AAA World Streaming System — Preloads hospital interior + Minato-Kasumi street.
## Handles seamless portal-based zone transitions with acoustic handoff to SpatialVoiceManager.
## Mimics Genshin Impact-style load-on-approach with smooth crossfade.

signal zone_transition_started(from_zone: String, to_zone: String)
signal zone_transition_completed(new_zone: String)
signal zone_preload_completed(zone_id: String)
signal zone_preload_failed(zone_id: String, scene_path: String)

enum Zone {
	SECTOR11_SYSTEM,
	HOSPITAL_INTERIOR,
	MINATO_KASUMI_STREET
}

const ZONE_CONFIG: Dictionary = {
	Zone.SECTOR11_SYSTEM: {
		"display_name": "Sector 11 // Simulated Facility",
		"acoustic_zone": 0,
		"spawn_offset": Vector3(0, 0, 4)
	},
	Zone.HOSPITAL_INTERIOR: {
		"scene_path": "res://scenes/environment/hospital_interior.tscn",
		"display_name": "Decompression Ward — 解凍病棟",
		"acoustic_zone": 1,  # AcousticZone.HOSPITAL_CORRIDOR
		"portal_trigger_pos": Vector3(15, 0, -45),
		"portal_trigger_radius": 2.0,
		"spawn_offset": Vector3(15, 0, -48)
	},
	Zone.MINATO_KASUMI_STREET: {
		"scene_path": "res://scenes/environment/minato_kasumi_alleyway.tscn",
		"display_name": "湊霞通り — Minato-Kasumi",
		"acoustic_zone": 2,  # AcousticZone.COASTAL_OUTDOOR
		"portal_trigger_pos": Vector3(15, 0, -61),
		"portal_trigger_radius": 2.0,
		"spawn_offset": Vector3(15, 0, -58)
	}
}

var _preloaded_scenes: Dictionary = {}  # Zone -> PackedScene
var _existing_zone_nodes: Dictionary = {}  # Zone -> scene node already present in the parent
var _active_zone: Zone = Zone.SECTOR11_SYSTEM
var _active_zone_node: Node = null
var _is_transitioning: bool = false
var _transition_fade_node: CanvasLayer = null

var player_ref: Node3D = null
var voice_manager_ref: Node = null
var weather_system_ref: Node = null

func _ready() -> void:
	# Preload both scenes immediately at startup
	_start_preload(Zone.HOSPITAL_INTERIOR)
	_start_preload(Zone.MINATO_KASUMI_STREET)

func _start_preload(zone: Zone) -> void:
	var config = ZONE_CONFIG[zone]
	var path: String = config["scene_path"]
	if not ResourceLoader.exists(path):
		push_warning("WorldStreamer cannot preload missing scene: " + path)
		emit_signal("zone_preload_failed", str(zone), path)
		return
	var request_error: Error = ResourceLoader.load_threaded_request(path)
	if request_error != OK:
		push_warning("WorldStreamer preload request failed: " + path)
		emit_signal("zone_preload_failed", str(zone), path)
		return
	_preloaded_scenes[zone] = null  # Mark as pending
	_poll_preload(zone)

func _poll_preload(zone: Zone) -> void:
	var config = ZONE_CONFIG[zone]
	var path: String = config["scene_path"]
	var status = ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_preloaded_scenes[zone] = ResourceLoader.load_threaded_get(path)
		emit_signal("zone_preload_completed", str(zone))
	elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		# Retry next frame
		var timer = get_tree().create_timer(0.1) if is_inside_tree() else null
		if timer:
			timer.timeout.connect(func(): _poll_preload(zone))
	else:
		push_warning("WorldStreamer scene load failed: " + path)
		emit_signal("zone_preload_failed", str(zone), path)

func _physics_process(_delta: float) -> void:
	if _is_transitioning or not player_ref:
		return
	_check_portal_triggers()

func _check_portal_triggers() -> void:
	var player_pos: Vector3 = player_ref.global_position if player_ref.is_inside_tree() else player_ref.position
	# Only connect reality-world portals after the story has reached the hospital.
	if _active_zone == Zone.HOSPITAL_INTERIOR:
		var portal_pos = ZONE_CONFIG[Zone.MINATO_KASUMI_STREET]["portal_trigger_pos"]
		if player_pos.distance_to(portal_pos) <= ZONE_CONFIG[Zone.MINATO_KASUMI_STREET]["portal_trigger_radius"]:
			_begin_transition(Zone.HOSPITAL_INTERIOR, Zone.MINATO_KASUMI_STREET)
	elif _active_zone == Zone.MINATO_KASUMI_STREET:
		var portal_pos = ZONE_CONFIG[Zone.HOSPITAL_INTERIOR]["portal_trigger_pos"]
		if player_pos.distance_to(portal_pos) <= ZONE_CONFIG[Zone.HOSPITAL_INTERIOR]["portal_trigger_radius"]:
			_begin_transition(Zone.MINATO_KASUMI_STREET, Zone.HOSPITAL_INTERIOR)

func _begin_transition(from_zone: Zone, to_zone: Zone) -> void:
	if _is_transitioning:
		return
	var has_scene: bool = _preloaded_scenes.get(to_zone) is PackedScene
	var existing: Node = _existing_zone_nodes.get(to_zone) as Node
	if not has_scene and not (existing and is_instance_valid(existing)):
		return
	_is_transitioning = true

	var from_name: String = ZONE_CONFIG[from_zone]["display_name"]
	var to_name: String = ZONE_CONFIG[to_zone]["display_name"]
	emit_signal("zone_transition_started", from_name, to_name)

	# Fade to black (cinematic)
	_do_fade_to_black(0.5, func(): _swap_zone(from_zone, to_zone))

func _swap_zone(from_zone: Zone, to_zone: Zone) -> void:
	var parent = get_parent()

	# Remove old zone node if it was dynamically instantiated, or hide if pre-existing
	var old_existing: Node = _existing_zone_nodes.get(from_zone) as Node
	if old_existing and is_instance_valid(old_existing) and old_existing is Node3D:
		old_existing.visible = false
	elif _active_zone_node and is_instance_valid(_active_zone_node) and not _existing_zone_nodes.values().has(_active_zone_node):
		_active_zone_node.queue_free()
		_active_zone_node = null

	# Reuse a scene already present in the main level; never spawn a duplicate street.
	var existing: Node = _existing_zone_nodes.get(to_zone) as Node
	if existing and is_instance_valid(existing):
		_active_zone_node = existing
		if existing is Node3D:
			existing.visible = true
	else:
		var packed: PackedScene = _preloaded_scenes.get(to_zone)
		if packed:
			var new_node = packed.instantiate()
			new_node.name = ZONE_CONFIG[to_zone]["display_name"]
			if parent:
				parent.add_child(new_node)
			_active_zone_node = new_node

	# Teleport player to spawn offset
	if player_ref:
		var spawn: Vector3 = ZONE_CONFIG[to_zone]["spawn_offset"]
		if player_ref.is_inside_tree():
			player_ref.global_position = spawn
		else:
			player_ref.position = spawn

	# Update acoustic zone on voice manager
	if voice_manager_ref and voice_manager_ref.has_method("set_acoustic_zone"):
		voice_manager_ref.set_acoustic_zone(ZONE_CONFIG[to_zone]["acoustic_zone"])

	# Update weather activation
	if weather_system_ref and weather_system_ref.has_method("set_street_zone_active"):
		weather_system_ref.set_street_zone_active(to_zone == Zone.MINATO_KASUMI_STREET)

	_active_zone = to_zone

	# Fade back in
	_do_fade_from_black(0.6, func():
		_is_transitioning = false
		emit_signal("zone_transition_completed", ZONE_CONFIG[to_zone]["display_name"])
	)

func _do_fade_to_black(duration: float, on_complete: Callable) -> void:
	if not is_inside_tree():
		on_complete.call()
		return
	var canvas = CanvasLayer.new()
	canvas.name = "_StreamerFade"
	var rect = ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.anchors_preset = Control.PRESET_FULL_RECT
	canvas.add_child(rect)
	get_parent().add_child(canvas)
	_transition_fade_node = canvas

	var tween = get_tree().create_tween()
	tween.tween_property(rect, "color", Color(0, 0, 0, 1), duration)
	tween.tween_callback(on_complete)

func _do_fade_from_black(duration: float, on_complete: Callable) -> void:
	if not is_inside_tree() or not _transition_fade_node:
		on_complete.call()
		return
	var rect = _transition_fade_node.get_child(0)
	if not rect:
		on_complete.call()
		return
	var tween = get_tree().create_tween()
	tween.tween_property(rect, "color", Color(0, 0, 0, 0), duration)
	tween.tween_callback(func():
		if _transition_fade_node and is_instance_valid(_transition_fade_node):
			_transition_fade_node.queue_free()
		_transition_fade_node = null
		on_complete.call()
	)

# Public API
func get_active_zone() -> Zone:
	return _active_zone

func get_active_zone_name() -> String:
	return ZONE_CONFIG[_active_zone]["display_name"]

func is_transitioning() -> bool:
	return _is_transitioning

func is_preloaded(zone: Zone) -> bool:
	return _preloaded_scenes.has(zone) and _preloaded_scenes[zone] != null

func set_player(p: Node3D) -> void:
	player_ref = p

func set_voice_manager(vm: Node) -> void:
	voice_manager_ref = vm

func set_weather_system(ws: Node) -> void:
	weather_system_ref = ws

func set_existing_zone(zone: Zone, node: Node) -> void:
	if node:
		_existing_zone_nodes[zone] = node

func enter_story_zone(zone: Zone) -> bool:
	if not ZONE_CONFIG.has(zone):
		return false
	if zone != Zone.SECTOR11_SYSTEM:
		var existing: Node = _existing_zone_nodes.get(zone) as Node
		if not existing or not is_instance_valid(existing):
			var packed: PackedScene = _preloaded_scenes.get(zone) as PackedScene
			if not packed:
				return false
			var parent := get_parent()
			if not parent:
				return false
			var new_node := packed.instantiate()
			new_node.name = ZONE_CONFIG[zone]["display_name"]
			parent.add_child(new_node)
			_active_zone_node = new_node
		else:
			_active_zone_node = existing
	elif _active_zone_node and is_instance_valid(_active_zone_node) and not _existing_zone_nodes.values().has(_active_zone_node):
		_active_zone_node.queue_free()
		_active_zone_node = null

	_active_zone = zone
	if player_ref:
		player_ref.global_position = ZONE_CONFIG[zone]["spawn_offset"]
	if voice_manager_ref and voice_manager_ref.has_method("set_acoustic_zone"):
		voice_manager_ref.set_acoustic_zone(ZONE_CONFIG[zone]["acoustic_zone"])
	if weather_system_ref and weather_system_ref.has_method("set_street_zone_active"):
		weather_system_ref.set_street_zone_active(zone == Zone.MINATO_KASUMI_STREET)
	return true

func force_zone(zone: Zone) -> void:
	_active_zone = zone
