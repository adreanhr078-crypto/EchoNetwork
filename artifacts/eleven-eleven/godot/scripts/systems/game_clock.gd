class_name GameClock
extends RefCounted

signal minute_ticked(hour: int, minute: int)
signal hour_ticked(hour: int)
signal day_ticked(day: int)

var day: int = 1
var hour: int = 17
var minute: int = 30
var second: float = 0.0
var time_scale: float = 60.0 # 1 real second = 60 game seconds = 1 game minute

func set_time(new_hour: int, new_minute: int, new_day: int = 1) -> void:
	var prev_hour = hour
	day = new_day
	hour = clampi(new_hour, 0, 23)
	minute = clampi(new_minute, 0, 59)
	second = 0.0
	emit_signal("minute_ticked", hour, minute)
	if hour != prev_hour:
		emit_signal("hour_ticked", hour)

func advance_time(delta_game_minutes: float) -> void:
	var total_sec = (hour * 3600) + (minute * 60) + second + (delta_game_minutes * 60.0)
	var prev_hour = hour
	var prev_day = day

	var total_days_offset = int(total_sec / 86400.0)
	day += total_days_offset
	total_sec = fmod(total_sec, 86400.0)
	if total_sec < 0.0:
		total_sec += 86400.0

	hour = int(total_sec / 3600.0)
	var rem_sec = fmod(total_sec, 3600.0)
	minute = int(rem_sec / 60.0)
	second = fmod(rem_sec, 60.0)

	emit_signal("minute_ticked", hour, minute)
	if hour != prev_hour:
		emit_signal("hour_ticked", hour)
	if day != prev_day:
		emit_signal("day_ticked", day)

func process_delta(real_delta: float) -> void:
	advance_time((real_delta * time_scale) / 60.0)

func get_formatted_time() -> String:
	return "%02d:%02d" % [hour, minute]

func get_total_minutes() -> int:
	return (day * 1440) + (hour * 60) + minute

func is_between_hours(open_hour: int, close_hour: int) -> bool:
	if open_hour == close_hour:
		return true # 24/7
	if open_hour < close_hour:
		return hour >= open_hour and hour < close_hour
	else:
		# Over midnight (e.g. 20:00 to 06:00)
		return hour >= open_hour or hour < close_hour

func serialize() -> Dictionary:
	return {
		"day": day,
		"hour": hour,
		"minute": minute,
		"second": second
	}

func deserialize(data: Dictionary) -> void:
	if data.has("day"):
		day = int(data["day"])
	if data.has("hour"):
		hour = int(data["hour"])
	if data.has("minute"):
		minute = int(data["minute"])
	if data.has("second"):
		second = float(data["second"])
