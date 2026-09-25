class_name CompassRadarBar
extends Control

## AAA Horizontal Exploration Compass Radar Bar
## Genshin Impact / Skyrim-style panoramic navigation bar.
## Displays dynamic 360° heading tape (N, NE, E, SE, S, SW, W, NW) and tracked 3D world POI pins.

signal marker_added(id: String, label: String)
signal marker_removed(id: String)
signal marker_pinged(id: String, distance: float)

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")

const BAR_WIDTH: float = 460.0
const BAR_HEIGHT: float = 34.0
const FOV_ANGLE_RAD: float = deg_to_rad(110.0)

const CARDINALS: Array = [
	{"text": "N", "angle": 0.0, "major": true},
	{"text": "NE", "angle": PI * 0.25, "major": false},
	{"text": "E", "angle": PI * 0.5, "major": true},
	{"text": "SE", "angle": PI * 0.75, "major": false},
	{"text": "S", "angle": PI, "major": true},
	{"text": "SW", "angle": -PI * 0.75, "major": false},
	{"text": "W", "angle": -PI * 0.5, "major": true},
	{"text": "NW", "angle": -PI * 0.25, "major": false}
]

const TYPE_COLORS: Dictionary = {
	"QUEST": Color(1.0, 0.78, 0.12, 1.0),
	"CHEST": Color(0.18, 0.94, 1.0, 1.0),
	"SHOP": Color(0.2, 1.0, 0.5, 1.0),
	"SHRINE": Color(1.0, 0.2, 0.45, 1.0),
	"HOME": Color(0.65, 0.75, 1.0, 1.0),
	"LANDMARK": Color(0.9, 0.9, 0.95, 1.0)
}

var current_cam_yaw: float = 0.0
var current_player_pos: Vector3 = Vector3.ZERO
var tracked_markers: Dictionary = {}
var pinged_markers: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Registers a 3D world landmark, quest target, or chest
func add_marker(id: String, world_pos: Vector3, label: String, type: String = "QUEST", custom_color: Color = Color.TRANSPARENT) -> void:
	var col = custom_color if custom_color != Color.TRANSPARENT else TYPE_COLORS.get(type, Color.CYAN)
	tracked_markers[id] = {
		"id": id,
		"pos": world_pos,
		"label": label,
		"type": type,
		"color": col
	}
	emit_signal("marker_added", id, label)
	queue_redraw()

func remove_marker(id: String) -> void:
	if tracked_markers.has(id):
		tracked_markers.erase(id)
		pinged_markers.erase(id)
		emit_signal("marker_removed", id)
		queue_redraw()

func clear_markers() -> void:
	tracked_markers.clear()
	pinged_markers.clear()
	queue_redraw()

func get_marker_count() -> int:
	return tracked_markers.size()

## Updates camera orientation and player position, triggering redraw
func update_compass(cam_yaw: float, player_pos: Vector3) -> void:
	current_cam_yaw = cam_yaw
	current_player_pos = player_pos

	# Check proximity pings (< 6.0m)
	for id in tracked_markers.keys():
		var m = tracked_markers[id]
		var dist = (m["pos"] - player_pos).length()
		if dist <= 6.0 and not pinged_markers.get(id, false):
			pinged_markers[id] = true
			emit_signal("marker_pinged", id, dist)
			if is_inside_tree():
				var audio = AudioStreamPlayer.new()
				add_child(audio)
				audio.stream = ProceduralCinematicAudio.create_compass_ping_sfx()
				audio.play()
				audio.finished.connect(func(): audio.queue_free())
		elif dist > 8.0:
			pinged_markers[id] = false

	queue_redraw()

func _draw() -> void:
	var center_x: float = size.x * 0.5
	var center_y: float = size.y * 0.5
	var half_w: float = size.x * 0.5

	# Background Frosted Panel
	draw_rect(Rect2(0, 0, size.x, size.y), Color(0.012, 0.022, 0.04, 0.82), true, -1.0)
	draw_line(Vector2(0, size.y), Vector2(size.x, size.y), Color(0.0, 0.94, 1.0, 0.45), 1.5)
	draw_line(Vector2(center_x, 0), Vector2(center_x, 8), Color(0.0, 0.94, 1.0, 0.95), 2.0)

	var default_font := ThemeDB.fallback_font

	# Draw Cardinal Directions along horizontal angle
	for card in CARDINALS:
		var diff = wrapf(card["angle"] - current_cam_yaw, -PI, PI)
		if absf(diff) <= (FOV_ANGLE_RAD * 0.5):
			var x_pos = center_x + (diff / (FOV_ANGLE_RAD * 0.5)) * half_w * 0.92
			var alpha: float = 1.0 - pow(absf(diff) / (FOV_ANGLE_RAD * 0.5), 2.0)
			var col = Color(0.0, 0.94, 1.0, alpha) if card["major"] else Color(0.7, 0.78, 0.85, alpha * 0.7)
			var font_size = 14 if card["major"] else 11
			draw_string(default_font, Vector2(x_pos - 6, center_y + 4), card["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, col)
			draw_line(Vector2(x_pos, size.y - 6), Vector2(x_pos, size.y - 2), col, 1.0)

	# Draw Tracked Markers
	for id in tracked_markers.keys():
		var m = tracked_markers[id]
		var diff_pos = m["pos"] - current_player_pos
		var dist = diff_pos.length()
		var target_angle = atan2(diff_pos.x, -diff_pos.z)
		var diff_angle = wrapf(target_angle - current_cam_yaw, -PI, PI)

		if absf(diff_angle) <= (FOV_ANGLE_RAD * 0.5):
			var x_pos = center_x + (diff_angle / (FOV_ANGLE_RAD * 0.5)) * half_w * 0.92
			var alpha: float = clampf(1.0 - absf(diff_angle) / (FOV_ANGLE_RAD * 0.5), 0.2, 1.0)
			var col: Color = m["color"]
			col.a = alpha

			# Marker Diamond Pin
			var pin_pts = PackedVector2Array([
				Vector2(x_pos, center_y - 6),
				Vector2(x_pos + 5, center_y),
				Vector2(x_pos, center_y + 6),
				Vector2(x_pos - 5, center_y)
			])
			draw_colored_polygon(pin_pts, col)

			# Distance text beneath pin
			var dist_text = str(int(dist)) + "m"
			draw_string(default_font, Vector2(x_pos - 12, size.y - 2), dist_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(0.9, 0.95, 1.0, alpha * 0.85))
