class_name WeatherSystem
extends Node

const GameClockScript = preload("res://scripts/systems/game_clock.gd")

## AAA Dynamic Weather System — Street-Only Procedural Rain, Fog & Ocean Ambience
## Subscribes to GameClock signals. Active only within the MinatoKasumiAlleyway zone.
## Designed to match Genshin Impact's cinematic environment quality.

signal weather_changed(state: int, intensity: float)
signal rain_started()
signal rain_stopped()

enum WeatherState {
	CLEAR,
	LIGHT_RAIN,
	HEAVY_RAIN,
	COASTAL_MIST
}

# Reference to WorldEnvironment for visual transitions
var _world_env: WorldEnvironment = null
# Clock reference (set by parent scene)
var game_clock: GameClockScript = null

var current_state: WeatherState = WeatherState.CLEAR
var rain_intensity: float = 0.0
var is_active_zone: bool = false  # Only apply weather in street zone

# Audio players for ambient loops
var _rain_player: AudioStreamPlayer = null
var _ocean_player: AudioStreamPlayer = null
var _audio_tween: Tween = null

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")

# Cinematic fog baseline (Minato-Kasumi night coastal atmosphere)
const FOG_DENSITY_CLEAR: float = 0.018
const FOG_DENSITY_RAIN: float = 0.055
const FOG_DENSITY_MIST: float = 0.082

const SKY_COLOR_CLEAR_NIGHT: Color = Color(0.005, 0.010, 0.022, 1.0)
const SKY_COLOR_RAIN: Color = Color(0.008, 0.012, 0.020, 1.0)
const SKY_COLOR_MIST: Color = Color(0.010, 0.016, 0.028, 1.0)

const AMBIENT_RAIN_NIGHT: Color = Color(0.035, 0.048, 0.072, 1.0)
const AMBIENT_CLEAR_NIGHT: Color = Color(0.050, 0.070, 0.110, 1.0)

func _ready() -> void:
	_world_env = get_tree().get_first_node_in_group("world_environment") if is_inside_tree() else null

	# Bootstrap ambient audio players
	_rain_player = AudioStreamPlayer.new()
	_rain_player.name = "RainAmbientPlayer"
	_rain_player.volume_db = -80.0  # Start silent
	_rain_player.bus = "Ambient"
	add_child(_rain_player)

	_ocean_player = AudioStreamPlayer.new()
	_ocean_player.name = "OceanAmbientPlayer"
	_ocean_player.volume_db = -80.0  # Start silent
	_ocean_player.bus = "Ambient"
	add_child(_ocean_player)

	# Generate and assign looping audio
	var rain_stream: AudioStreamWAV = ProceduralCinematicAudio.create_coastal_rain()
	if rain_stream:
		rain_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_rain_player.stream = rain_stream
		_rain_player.play()

	var ocean_stream: AudioStreamWAV = ProceduralCinematicAudio.create_ocean_waves()
	if ocean_stream:
		ocean_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_ocean_player.stream = ocean_stream
		_ocean_player.play()

func connect_to_clock(clock: GameClockScript) -> void:
	game_clock = clock
	if game_clock:
		game_clock.hour_ticked.connect(_on_hour_ticked)
		game_clock.minute_ticked.connect(_on_minute_ticked)

func set_street_zone_active(active: bool) -> void:
	is_active_zone = active
	if not active:
		_transition_to_state(WeatherState.CLEAR, 0.0, 3.0)

func _on_hour_ticked(hour: int) -> void:
	if not is_active_zone:
		return
	# Cinematic rain schedule: late night coastal drizzle 22:00-05:00
	# Heavy rain: 01:00-03:00
	match hour:
		22, 23:
			_transition_to_state(WeatherState.COASTAL_MIST, 0.4, 6.0)
		0, 1:
			_transition_to_state(WeatherState.LIGHT_RAIN, 0.6, 4.0)
		2, 3:
			_transition_to_state(WeatherState.HEAVY_RAIN, 1.0, 3.0)
		4, 5:
			_transition_to_state(WeatherState.LIGHT_RAIN, 0.5, 5.0)
		6, 7:
			_transition_to_state(WeatherState.COASTAL_MIST, 0.3, 8.0)
		8, 17, 18:
			_transition_to_state(WeatherState.CLEAR, 0.0, 10.0)
		_:
			_transition_to_state(WeatherState.CLEAR, 0.0, 12.0)

func _on_minute_ticked(_hour: int, _minute: int) -> void:
	# Fine-grained ocean level update every game minute
	if is_active_zone:
		var ocean_vol: float = _get_target_ocean_volume()
		if _ocean_player and abs(_ocean_player.volume_db - ocean_vol) > 0.5:
			var tween = get_tree().create_tween() if is_inside_tree() else null
			if tween:
				tween.tween_property(_ocean_player, "volume_db", ocean_vol, 2.0)

func _get_target_ocean_volume() -> float:
	match current_state:
		WeatherState.HEAVY_RAIN:
			return -6.0
		WeatherState.LIGHT_RAIN:
			return -9.0
		WeatherState.COASTAL_MIST:
			return -12.0
		_:
			return -15.0

func _transition_to_state(new_state: WeatherState, intensity: float, duration: float) -> void:
	var prev_state = current_state
	current_state = new_state
	rain_intensity = intensity

	if is_inside_tree():
		var tween = get_tree().create_tween()
		tween.set_parallel(true)

		# Transition rain audio volume
		var rain_target_vol: float = _state_to_rain_volume(new_state, intensity)
		tween.tween_property(_rain_player, "volume_db", rain_target_vol, duration)

		# Transition fog density via WorldEnvironment
		if _world_env and _world_env.environment:
			var env = _world_env.environment
			var fog_target: float = _state_to_fog_density(new_state)
			tween.tween_property(env, "volumetric_fog_density", fog_target, duration)

			var sky_target: Color = _state_to_sky_color(new_state)
			tween.tween_property(env, "background_color", sky_target, duration)

			var ambient_target: Color = _state_to_ambient_color(new_state)
			tween.tween_property(env, "ambient_light_color", ambient_target, duration)

	# Emit signals for other systems to react
	emit_signal("weather_changed", new_state, intensity)
	if new_state != WeatherState.CLEAR and prev_state == WeatherState.CLEAR:
		emit_signal("rain_started")
	elif new_state == WeatherState.CLEAR and prev_state != WeatherState.CLEAR:
		emit_signal("rain_stopped")

func _state_to_rain_volume(state: WeatherState, intensity: float) -> float:
	match state:
		WeatherState.HEAVY_RAIN:
			return lerp(-4.0, 0.0, intensity)
		WeatherState.LIGHT_RAIN:
			return lerp(-14.0, -8.0, intensity)
		WeatherState.COASTAL_MIST:
			return -20.0
		_:
			return -80.0

func _state_to_fog_density(state: WeatherState) -> float:
	match state:
		WeatherState.HEAVY_RAIN:
			return FOG_DENSITY_RAIN
		WeatherState.COASTAL_MIST:
			return FOG_DENSITY_MIST
		WeatherState.LIGHT_RAIN:
			return lerp(FOG_DENSITY_CLEAR, FOG_DENSITY_RAIN, 0.5)
		_:
			return FOG_DENSITY_CLEAR

func _state_to_sky_color(state: WeatherState) -> Color:
	match state:
		WeatherState.HEAVY_RAIN, WeatherState.LIGHT_RAIN:
			return SKY_COLOR_RAIN
		WeatherState.COASTAL_MIST:
			return SKY_COLOR_MIST
		_:
			return SKY_COLOR_CLEAR_NIGHT

func _state_to_ambient_color(state: WeatherState) -> Color:
	if state == WeatherState.CLEAR:
		return AMBIENT_CLEAR_NIGHT
	return AMBIENT_RAIN_NIGHT

# Public API: force a specific weather (used by tests and cutscenes)
func force_weather(state: WeatherState, intensity: float) -> void:
	_transition_to_state(state, intensity, 0.5)

# Public API: check if currently raining
func is_raining() -> bool:
	return current_state == WeatherState.LIGHT_RAIN or current_state == WeatherState.HEAVY_RAIN

func get_weather_state() -> WeatherState:
	return current_state

func get_rain_intensity() -> float:
	return rain_intensity

func get_rain_player() -> AudioStreamPlayer:
	return _rain_player

func get_ocean_player() -> AudioStreamPlayer:
	return _ocean_player
