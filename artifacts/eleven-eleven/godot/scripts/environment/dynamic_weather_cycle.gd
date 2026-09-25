class_name DynamicWeatherCycle
extends Node

## 11.11 Dynamic Day/Night Cycle & Weather Engine (Genshin Impact Benchmark)
## Orchestrates time of day transitions (Dawn, Noon, Sunset, Night),
## dynamic anime sky gradient changes, celestial sun/moon positioning,
## atmospheric fog modulation, street light automation, and procedural coastal weather (Clear, Overcast, Rain).

enum TimeOfDay {
	DAWN,    # 05:00 - 07:59: Golden-pink dawn, dew mist, waking atmosphere
	NOON,    # 08:00 - 16:59: Brilliant azure sky, high-angle sunlight, maximum clarity
	SUNSET,  # 17:00 - 19:59: Vivid vermilion horizon, long twilight shadows, streetlights ignite
	NIGHT    # 20:00 - 04:59: Deep indigo void, twinkling starfield, cool silver moonlight
}

enum WeatherType {
	CLEAR,        # Crystal clear skies, crisp anime shadows
	OVERCAST,     # Heavy cloud canopy, diffused illumination, cool tones
	COASTAL_RAIN  # Steady coastal rain shower, wet specular reflections, audio ambience
}

signal time_phase_changed(new_phase: int, hour: int)
signal weather_changed(new_weather: int)
signal sun_position_updated(direction: Vector3, light_color: Color, energy: float)

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")
const GameClock = preload("res://scripts/systems/game_clock.gd")

@export var current_time_phase: TimeOfDay = TimeOfDay.NOON
@export var current_weather: WeatherType = WeatherType.CLEAR
@export var current_hour: int = 12
@export var current_minute: int = 0
@export var auto_sync_clock: bool = true

var sun_light: DirectionalLight3D = null
var world_env: WorldEnvironment = null
var game_clock: GameClock = null
var rain_particles: CPUParticles3D = null
var rain_audio: AudioStreamPlayer = null
var streetlights: Array[OmniLight3D] = []

# Time Profile Definitions (Genshin Visual Benchmark)
const TIME_PROFILES := {
	TimeOfDay.DAWN: {
		"zenith_color": Color(0.18, 0.16, 0.38, 1.0),
		"horizon_color": Color(0.95, 0.62, 0.42, 1.0),
		"horizon_glow_color": Color(1.0, 0.78, 0.55, 1.0),
		"sun_direction": Vector3(0.72, 0.28, -0.42),
		"sun_disk_color": Color(1.0, 0.88, 0.70, 1.0),
		"sun_light_color": Color(1.0, 0.86, 0.72, 1.0),
		"sun_energy": 1.05,
		"fog_density": 0.016, # Soft morning mist
		"fog_albedo": Color(0.85, 0.68, 0.60, 1.0),
		"stars_intensity": 0.0,
		"streetlights_on": false
	},
	TimeOfDay.NOON: {
		"zenith_color": Color(0.14, 0.45, 0.92, 1.0),
		"horizon_color": Color(0.52, 0.76, 0.98, 1.0),
		"horizon_glow_color": Color(0.75, 0.88, 1.0, 1.0),
		"sun_direction": Vector3(0.18, 0.94, -0.25),
		"sun_disk_color": Color(1.0, 0.98, 0.92, 1.0),
		"sun_light_color": Color(1.0, 0.96, 0.90, 1.0),
		"sun_energy": 1.45,
		"fog_density": 0.008, # Pristine daytime clarity
		"fog_albedo": Color(0.72, 0.84, 0.96, 1.0),
		"stars_intensity": 0.0,
		"streetlights_on": false
	},
	TimeOfDay.SUNSET: {
		"zenith_color": Color(0.12, 0.14, 0.40, 1.0),
		"horizon_color": Color(0.98, 0.36, 0.20, 1.0),
		"horizon_glow_color": Color(1.0, 0.62, 0.28, 1.0),
		"sun_direction": Vector3(-0.76, 0.22, -0.32),
		"sun_disk_color": Color(1.0, 0.60, 0.22, 1.0),
		"sun_light_color": Color(1.0, 0.52, 0.30, 1.0),
		"sun_energy": 1.15,
		"fog_density": 0.014, # Warm coastal dusk haze
		"fog_albedo": Color(0.82, 0.40, 0.32, 1.0),
		"stars_intensity": 0.6,
		"streetlights_on": true
	},
	TimeOfDay.NIGHT: {
		"zenith_color": Color(0.02, 0.03, 0.09, 1.0),
		"horizon_color": Color(0.06, 0.12, 0.25, 1.0),
		"horizon_glow_color": Color(0.12, 0.22, 0.45, 1.0),
		"sun_direction": Vector3(-0.35, 0.78, 0.42), # Cool silver moon
		"sun_disk_color": Color(0.78, 0.88, 1.0, 1.0),
		"sun_light_color": Color(0.55, 0.70, 0.96, 1.0),
		"sun_energy": 0.35,
		"fog_density": 0.020, # Night coastal fog
		"fog_albedo": Color(0.08, 0.14, 0.28, 1.0),
		"stars_intensity": 3.2, # Sparkling anime stars
		"streetlights_on": true
	}
}

func _ready() -> void:
	ensure_setup()

func ensure_setup() -> void:
	_resolve_scene_nodes()
	_setup_weather_particles()
	_setup_weather_audio()
	apply_cycle_parameters()

func _resolve_scene_nodes() -> void:
	if not world_env:
		if get_parent() and get_parent().has_node("WorldEnvironment"):
			world_env = get_parent().get_node("WorldEnvironment") as WorldEnvironment
		elif is_inside_tree() and get_tree() and get_tree().root:
			world_env = get_tree().root.find_child("WorldEnvironment", true, false) as WorldEnvironment

	if not sun_light:
		if get_parent() and get_parent().has_node("DirectionalLight3D"):
			sun_light = get_parent().get_node("DirectionalLight3D") as DirectionalLight3D
		elif is_inside_tree() and get_tree() and get_tree().root:
			sun_light = get_tree().root.find_child("DirectionalLight3D", true, false) as DirectionalLight3D

	if not sun_light:
		# Instantiate default dynamic celestial light
		sun_light = DirectionalLight3D.new()
		sun_light.name = "DirectionalLight3D"
		sun_light.shadow_enabled = true
		if get_parent():
			get_parent().add_child(sun_light)
		else:
			add_child(sun_light)

	# Locate street lights in parent/tree if not populated
	if streetlights.is_empty() and get_parent():
		for child in get_parent().find_children("*", "OmniLight3D", true, false):
			if child.name.contains("StreetLight") or child.name.contains("PoleLight"):
				streetlights.append(child)

func _setup_weather_particles() -> void:
	if not rain_particles:
		rain_particles = find_child("RainParticles", true, false) as CPUParticles3D
		if not rain_particles:
			rain_particles = CPUParticles3D.new()
			rain_particles.name = "RainParticles"
			rain_particles.amount = 300
			rain_particles.lifetime = 1.2
			rain_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			rain_particles.emission_box_extents = Vector3(25.0, 1.0, 25.0)
			rain_particles.direction = Vector3(-0.15, -1.0, 0.08)
			rain_particles.spread = 4.0
			rain_particles.initial_velocity_min = 16.0
			rain_particles.initial_velocity_max = 22.0
			
			var p_mesh := BoxMesh.new()
			p_mesh.size = Vector3(0.018, 0.42, 0.018)
			var p_mat := StandardMaterial3D.new()
			p_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
			p_mat.albedo_color = Color(0.72, 0.88, 1.0, 0.65)
			p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			p_mesh.material = p_mat
			rain_particles.mesh = p_mesh
			rain_particles.position = Vector3(0, 12.0, 0)
			rain_particles.emitting = false
			add_child(rain_particles)

func _setup_weather_audio() -> void:
	if not rain_audio:
		rain_audio = find_child("RainAudio", true, false) as AudioStreamPlayer
		if not rain_audio:
			rain_audio = AudioStreamPlayer.new()
			rain_audio.name = "RainAudio"
			rain_audio.volume_db = -5.0
			add_child(rain_audio)

func register_streetlight(light: OmniLight3D) -> void:
	if light and not streetlights.has(light):
		streetlights.append(light)
		# Update its initial state
		var profile = TIME_PROFILES.get(current_time_phase, TIME_PROFILES[TimeOfDay.NOON])
		light.visible = profile.get("streetlights_on", false)

func set_time(hour: int, minute: int = 0) -> void:
	current_hour = clamp(hour, 0, 23)
	current_minute = clamp(minute, 0, 59)
	var new_phase = get_time_phase_for_hour(current_hour)
	var phase_changed = (new_phase != current_time_phase)
	current_time_phase = new_phase
	apply_cycle_parameters()
	if phase_changed:
		emit_signal("time_phase_changed", current_time_phase, current_hour)

func get_time_phase_for_hour(h: int) -> TimeOfDay:
	if h >= 5 and h < 8:
		return TimeOfDay.DAWN
	elif h >= 8 and h < 17:
		return TimeOfDay.NOON
	elif h >= 17 and h < 20:
		return TimeOfDay.SUNSET
	else:
		return TimeOfDay.NIGHT

func set_weather(weather: WeatherType) -> void:
	if current_weather == weather:
		return
	current_weather = weather
	apply_cycle_parameters()
	emit_signal("weather_changed", current_weather)

func is_raining() -> bool:
	return current_weather == WeatherType.COASTAL_RAIN

func apply_cycle_parameters() -> void:
	_resolve_scene_nodes()
	var profile = TIME_PROFILES.get(current_time_phase, TIME_PROFILES[TimeOfDay.NOON])

	# 1. Update Directional Sun/Moon Light
	var sun_dir: Vector3 = profile["sun_direction"]
	var sun_color: Color = profile["sun_light_color"]
	var sun_energy: float = profile["sun_energy"]

	# Weather modifications to celestial light
	match current_weather:
		WeatherType.OVERCAST:
			sun_energy *= 0.45
			sun_color = sun_color.lerp(Color(0.7, 0.75, 0.85), 0.5)
		WeatherType.COASTAL_RAIN:
			sun_energy *= 0.30
			sun_color = sun_color.lerp(Color(0.55, 0.65, 0.78), 0.65)

	if sun_light:
		sun_light.light_color = sun_color
		sun_light.light_energy = sun_energy
		# Orient light along sun direction
		var target_rot = Transform3D().looking_at(sun_dir.normalized(), Vector3.UP).basis
		sun_light.basis = target_rot

	# 2. Update WorldEnvironment Sky and Volumetric Fog
	if world_env and world_env.environment:
		var env := world_env.environment

		# Fog adjustments
		var base_fog_density: float = profile["fog_density"]
		var base_fog_albedo: Color = profile["fog_albedo"]
		if current_weather == WeatherType.OVERCAST:
			base_fog_density += 0.008
			base_fog_albedo = base_fog_albedo.lerp(Color(0.65, 0.70, 0.78), 0.6)
		elif current_weather == WeatherType.COASTAL_RAIN:
			base_fog_density += 0.016
			base_fog_albedo = base_fog_albedo.lerp(Color(0.45, 0.52, 0.62), 0.75)

		env.volumetric_fog_density = base_fog_density
		env.volumetric_fog_albedo = base_fog_albedo

		# Shader Sky adjustments
		if env.sky and env.sky.sky_material and env.sky.sky_material is ShaderMaterial:
			var mat := env.sky.sky_material as ShaderMaterial
			var zenith: Color = profile["zenith_color"]
			var horizon: Color = profile["horizon_color"]
			var glow: Color = profile["horizon_glow_color"]
			var stars: float = profile["stars_intensity"]
			var cloud_cov: float = 0.38

			if current_weather == WeatherType.OVERCAST:
				zenith = zenith.lerp(Color(0.35, 0.42, 0.52), 0.7)
				horizon = horizon.lerp(Color(0.50, 0.56, 0.64), 0.7)
				glow = glow.lerp(Color(0.58, 0.62, 0.68), 0.7)
				cloud_cov = 0.85
				stars = 0.0
			elif current_weather == WeatherType.COASTAL_RAIN:
				zenith = zenith.lerp(Color(0.18, 0.22, 0.28), 0.85)
				horizon = horizon.lerp(Color(0.28, 0.32, 0.38), 0.85)
				glow = glow.lerp(Color(0.32, 0.36, 0.42), 0.85)
				cloud_cov = 0.96
				stars = 0.0

			mat.set_shader_parameter("zenith_color", zenith)
			mat.set_shader_parameter("horizon_color", horizon)
			mat.set_shader_parameter("horizon_glow_color", glow)
			mat.set_shader_parameter("sun_direction", sun_dir)
			mat.set_shader_parameter("sun_disk_color", profile["sun_disk_color"])
			mat.set_shader_parameter("stars_intensity", stars)
			mat.set_shader_parameter("cloud_coverage", cloud_cov)

	# 3. Update Street Lights
	var lights_on: bool = profile.get("streetlights_on", false)
	# Force streetlights on during heavy rain / stormy twilight
	if current_weather == WeatherType.COASTAL_RAIN:
		lights_on = true

	for light in streetlights:
		if is_instance_valid(light):
			light.visible = lights_on

	# 4. Update Rain Particles & Audio
	var raining = (current_weather == WeatherType.COASTAL_RAIN)
	if rain_particles and is_inside_tree():
		rain_particles.emitting = raining

	if rain_audio:
		if raining:
			if not rain_audio.playing and rain_audio.is_inside_tree():
				rain_audio.stream = ProceduralCinematicAudio.create_coastal_rain_ambience()
				rain_audio.play()
		else:
			if rain_audio.playing:
				rain_audio.stop()

	emit_signal("sun_position_updated", sun_dir, sun_color, sun_energy)

func serialize() -> Dictionary:
	return {
		"hour": current_hour,
		"minute": current_minute,
		"time_phase": current_time_phase,
		"weather": current_weather
	}

func deserialize(data: Dictionary) -> void:
	if data.has("hour"):
		current_hour = int(data["hour"])
	if data.has("minute"):
		current_minute = int(data["minute"])
	if data.has("weather"):
		current_weather = int(data["weather"])
	if data.has("time_phase"):
		current_time_phase = int(data["time_phase"])
	else:
		current_time_phase = get_time_phase_for_hour(current_hour)
	apply_cycle_parameters()
