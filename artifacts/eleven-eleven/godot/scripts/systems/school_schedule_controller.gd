class_name SchoolScheduleController
extends Node

## AAA Minato High School Academic Schedule Controller
## Coordinates 24h bell chimes, classroom periods, homeroom, lunch on the rooftop,
## and after-school club activities aligned with the GameClock.

signal period_changed(period_id: String, period_name: String, bell_chime: bool)
signal school_bell_rang()

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")

const PERIODS: Array = [
	{
		"id": "ARRIVAL",
		"name": "Morning Arrival & Geta-bako Locker Swaps // 登校",
		"start_hour": 8, "start_min": 0,
		"end_hour": 8, "end_min": 30,
		"location": "Entrance Foyer",
		"is_class": false
	},
	{
		"id": "PERIOD_1",
		"name": "Period 1: Modern History & Cataclysm // 現代史",
		"start_hour": 8, "start_min": 30,
		"end_hour": 9, "end_min": 30,
		"location": "Class 2-B",
		"is_class": true
	},
	{
		"id": "PERIOD_2",
		"name": "Period 2: Neural Science & Bio-Resonance // 神経科学",
		"start_hour": 9, "start_min": 40,
		"end_hour": 10, "end_min": 40,
		"location": "Science Lab",
		"is_class": true
	},
	{
		"id": "PERIOD_3",
		"name": "Period 3: Classical Literature // 古典文学",
		"start_hour": 10, "start_min": 50,
		"end_hour": 11, "end_min": 50,
		"location": "Class 2-B",
		"is_class": true
	},
	{
		"id": "PERIOD_4",
		"name": "Period 4: Physical Fitness // 体育",
		"start_hour": 12, "start_min": 0,
		"end_hour": 12, "end_min": 30,
		"location": "Gymnasium",
		"is_class": true
	},
	{
		"id": "LUNCH",
		"name": "Lunch Break & Rooftop Bento // 昼休み",
		"start_hour": 12, "start_min": 30,
		"end_hour": 13, "end_min": 30,
		"location": "School Rooftop / Cafeteria",
		"is_class": false
	},
	{
		"id": "PERIOD_5",
		"name": "Period 5: Dimensional Vectors // 数学演習",
		"start_hour": 13, "start_min": 30,
		"end_hour": 14, "end_min": 30,
		"location": "Class 2-B",
		"is_class": true
	},
	{
		"id": "HOMEROOM",
		"name": "Homeroom & Duty Cleaning // 終礼・清掃",
		"start_hour": 14, "start_min": 40,
		"end_hour": 15, "end_min": 30,
		"location": "Class 2-B",
		"is_class": false
	},
	{
		"id": "CLUBS",
		"name": "After-School Clubs & Hangouts // 部活動",
		"start_hour": 15, "start_min": 30,
		"end_hour": 18, "end_min": 0,
		"location": "Campus Grounds & Clubs",
		"is_class": false
	},
	{
		"id": "CURFEW",
		"name": "Campus Closed & Security Curfew // 門限",
		"start_hour": 18, "start_min": 0,
		"end_hour": 8, "end_min": 0,
		"location": "Gates Locked",
		"is_class": false
	}
]

var current_period_id: String = ""

func get_current_period(clock_hour: int, clock_minute: int) -> Dictionary:
	var total_cur_min: int = clock_hour * 60 + clock_minute

	for p in PERIODS:
		var start_min: int = p["start_hour"] * 60 + p["start_min"]
		var end_min: int = p["end_hour"] * 60 + p["end_min"]

		if start_min < end_min:
			if total_cur_min >= start_min and total_cur_min < end_min:
				return p
		else:
			# Night wrap-around (Curfew 18:00 to 08:00)
			if total_cur_min >= start_min or total_cur_min < end_min:
				return p

	return PERIODS[PERIODS.size() - 1]

func is_class_in_session(clock_hour: int, clock_minute: int) -> bool:
	var cur = get_current_period(clock_hour, clock_minute)
	return cur.get("is_class", false)

func trigger_school_bell() -> void:
	if is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_school_chime_bell()
		audio.play()
		audio.finished.connect(func(): audio.queue_free())
	emit_signal("school_bell_rang")

func update_schedule(clock_hour: int, clock_minute: int) -> Dictionary:
	var period = get_current_period(clock_hour, clock_minute)
	if period["id"] != current_period_id:
		current_period_id = period["id"]
		var is_bell: bool = period["id"] in ["PERIOD_1", "LUNCH", "HOMEROOM", "CLUBS"]
		if is_bell:
			trigger_school_bell()
		emit_signal("period_changed", period["id"], period["name"], is_bell)
	return period
