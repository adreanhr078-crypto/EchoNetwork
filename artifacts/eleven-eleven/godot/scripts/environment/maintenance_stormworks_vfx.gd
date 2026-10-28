extends Node3D

## Physical water/air presentation only. The room supplies every time sample.
## Bounds and vents are room-local; bounds.end.y is the water surface.
## No timers, process callbacks, collision, light, audio or gameplay authority.
const WATER_SHADER = preload("res://shaders/maintenance_stormworks_water.gdshader")
const WIND_SHADER = preload("res://shaders/maintenance_stormworks_wind.gdshader")
const MAX_IMPACTS := 8
const MAX_VENTS := 12

var _room: Node3D
var _visuals: Node3D
var _water: MeshInstance3D
var _water_material: ShaderMaterial
var _air_materials: Array[ShaderMaterial] = []
var _pressure_material: ShaderMaterial
var _water_bounds := AABB()
var _has_water := false
var _present := false
var _reduced_motion := false
var _audio_muted := true
var _elapsed := 0.0
var _last_source_time := NAN
var _impacts := PackedVector4Array()
var _impact_cursor := 0
var _landing_height_tolerance := 0.8

func configure(room: Node3D, configuration: Dictionary) -> void:
	if not is_instance_valid(room):
		push_error("Stormworks VFX requires a live room owner")
		return
	if get_parent() == null:
		room.add_child(self)
	elif get_parent() != room:
		push_error("Stormworks VFX must be a direct child of its room")
		return
	_clear_visuals()
	_room = room
	transform = Transform3D.IDENTITY
	_elapsed = 0.0
	_last_source_time = NAN
	_impact_cursor = 0
	_landing_height_tolerance = clampf(float(configuration.get("landing_height_tolerance", 0.8)), 0.05, 3.0)
	_visuals = Node3D.new()
	_visuals.name = "StormworksPhysicalAtmosphere"
	add_child(_visuals)
	_reset_impacts()
	var bounds: Variant = configuration.get("water_bounds", AABB())
	_has_water = bounds is AABB and bounds.position.is_finite() and bounds.size.is_finite() and bounds.size.x > 0.1 and bounds.size.z > 0.1 and bounds.size.y >= 0.0
	if _has_water:
		_water_bounds = bounds
		_build_water(configuration)
	var positions: Variant = configuration.get("vent_positions", [])
	if positions is Array:
		for index in mini(positions.size(), MAX_VENTS):
			var point: Variant = positions[index]
			if point is Vector3 and point.is_finite():
				_build_vent(point, index, configuration)
	_visuals.visible = _present
	_apply_motion()
	_write_time()

func _build_water(configuration: Dictionary) -> void:
	_water = MeshInstance3D.new()
	_water.name = "TealServiceWater"
	var plane := PlaneMesh.new()
	plane.size = Vector2(_water_bounds.size.x, _water_bounds.size.z)
	var segments := 48 if String(configuration.get("quality", "high")) == "high" else 24
	plane.subdivide_width = segments
	plane.subdivide_depth = segments
	_water.mesh = plane
	_water.position = Vector3(_water_bounds.get_center().x, _water_bounds.end.y, _water_bounds.get_center().z)
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_water.extra_cull_margin = 0.08
	_water.layers = int(configuration.get("render_layers", 1 | (1 << 18)))
	_water_material = ShaderMaterial.new()
	_water_material.shader = WATER_SHADER
	_water_material.set_shader_parameter("water_size", plane.size)
	_water_material.set_shader_parameter("impact_points", _impacts)
	_water.material_override = _water_material
	_visuals.add_child(_water)

func _build_vent(point: Vector3, index: int, configuration: Dictionary) -> void:
	var height := clampf(float(configuration.get("vent_height", 1.7)), 0.3, 3.2)
	var width := clampf(float(configuration.get("vent_width", 0.65)), 0.15, 1.1)
	var layers := int(configuration.get("render_layers", 1 | (1 << 18)))
	var material := ShaderMaterial.new()
	material.shader = WIND_SHADER
	material.set_shader_parameter("phase", float(index) * 2.399963)
	_air_materials.append(material)
	var sheet_count := 1 if String(configuration.get("quality", "high")) == "low" else 2
	for sheet in sheet_count:
		var plume := MeshInstance3D.new()
		plume.name = "ServiceVent_%02d_Sheet%d" % [index, sheet]
		var quad := QuadMesh.new()
		quad.size = Vector2(width, height)
		plume.mesh = quad
		plume.position = point + Vector3.UP * height * 0.5
		plume.rotation.y = float(sheet) * PI * 0.5
		plume.material_override = material
		plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		plume.layers = layers
		_visuals.add_child(plume)
	if _pressure_material == null:
		_pressure_material = ShaderMaterial.new()
		_pressure_material.shader = WIND_SHADER
		_pressure_material.set_shader_parameter("pressure_indicator", true)
		_pressure_material.set_shader_parameter("pressure", clampf(float(configuration.get("pressure", 0.65)), 0.0, 1.0))
	var marker := MeshInstance3D.new()
	marker.name = "AmberVentPressure_%02d" % index
	var disc := PlaneMesh.new()
	disc.size = Vector2(0.32, 0.32)
	marker.mesh = disc
	marker.position = point + Vector3.UP * 0.025
	marker.material_override = _pressure_material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.layers = layers
	_visuals.add_child(marker)

func set_presence(present: bool) -> void:
	if _present == present:
		return
	_present = present
	_last_source_time = NAN
	_reset_impacts()
	if is_instance_valid(_visuals):
		_visuals.visible = present

func set_reduced_motion(reduced: bool) -> void:
	if _reduced_motion == reduced:
		return
	_reduced_motion = reduced
	_last_source_time = NAN
	_reset_impacts()
	_apply_motion()

func set_audio_muted(muted: bool) -> void:
	# This component intentionally creates no audio sources.
	_audio_muted = muted

func tick_presentation(source_time: float) -> void:
	if not is_finite(source_time):
		return
	var stopped := not _present or _reduced_motion or not is_instance_valid(_room)
	if is_inside_tree() and get_tree().paused:
		stopped = true
	if not stopped and is_finite(_last_source_time):
		# Only positive owner-clock deltas advance effects; scene clock rewinds
		# rebase safely and do not replay old landing events.
		if source_time >= _last_source_time:
			_elapsed += source_time - _last_source_time
		else:
			_reset_impacts()
	_last_source_time = source_time
	_write_time()

func react_to_landing(world_position: Vector3, impact_speed: float) -> void:
	if not _present or _reduced_motion or not _has_water or not is_instance_valid(_room):
		return
	if not world_position.is_finite() or not is_finite(impact_speed) or impact_speed < 1.5:
		return
	if is_inside_tree() and get_tree().paused:
		return
	var point := _room.to_local(world_position)
	if point.x < _water_bounds.position.x or point.x > _water_bounds.end.x or point.z < _water_bounds.position.z or point.z > _water_bounds.end.z:
		return
	if absf(point.y - _water_bounds.end.y) > _landing_height_tolerance:
		return
	var relative := point - _water.position
	_impacts[_impact_cursor] = Vector4(relative.x, relative.z, _elapsed, clampf((impact_speed - 1.0) / 9.0, 0.08, 1.0))
	_impact_cursor = (_impact_cursor + 1) % MAX_IMPACTS
	_water_material.set_shader_parameter("impact_points", _impacts)

func _reset_impacts() -> void:
	_impacts.resize(MAX_IMPACTS)
	for index in MAX_IMPACTS:
		_impacts[index] = Vector4(0, 0, -1000, 0)
	if _water_material != null:
		_water_material.set_shader_parameter("impact_points", _impacts)

func _apply_motion() -> void:
	var motion := 0.0 if _reduced_motion else 1.0
	if _water_material != null:
		_water_material.set_shader_parameter("motion_factor", motion)
	for material in _air_materials:
		material.set_shader_parameter("motion_factor", motion)
	if _pressure_material != null:
		_pressure_material.set_shader_parameter("motion_factor", motion)

func _write_time() -> void:
	if _water_material != null:
		_water_material.set_shader_parameter("presentation_time", _elapsed)
	for material in _air_materials:
		material.set_shader_parameter("presentation_time", _elapsed)
	if _pressure_material != null:
		_pressure_material.set_shader_parameter("presentation_time", _elapsed)

func _clear_visuals() -> void:
	if is_instance_valid(_visuals):
		remove_child(_visuals)
		_visuals.queue_free()
	_visuals = null
	_water = null
	_water_material = null
	_pressure_material = null
	_air_materials.clear()
	_has_water = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		_last_source_time = NAN

func _exit_tree() -> void:
	_present = false
	_last_source_time = NAN
