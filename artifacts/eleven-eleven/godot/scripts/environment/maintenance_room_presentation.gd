extends Node3D

## Room-local craft. Receives existing task state; never advances it or edits physics.
const FINISH = preload("res://shaders/maintenance_surface_finish.gdshader")
var route_stage := 0
var reduced_motion := false
var _service_material: StandardMaterial3D
var _gauge_needle: MeshInstance3D
var _pressure_caption: Label3D
var _vent: CPUParticles3D
var _settling := 0.0
var _language := "ar"
var _finishes: Dictionary = {}
var _boundary_finishes: Array[ShaderMaterial] = []
var _aperture_open := false
var _motion_time := 0.0
var _inside_room := false
var _airflow: Array[CPUParticles3D] = []

func _ready() -> void:
	name = "MaintenanceRoomPresentation"
	_finish_source(get_parent())
	_build_equipment()
	_build_vent()
	_build_airflow()
	get_parent().service_release_started.connect(_on_release)
	get_parent().service_opened.connect(func(): set_route_stage(6))
	_apply_service_state()

func _finish_source(node: Node) -> void:
	for child in node.get_children():
		if child == self: continue
		if child is MeshInstance3D and child.mesh:
			for surface in child.mesh.get_surface_count():
				var original = child.get_active_material(surface)
				if not original is StandardMaterial3D or original.emission_enabled: continue
				if _finishes.has(original):
					child.set_surface_override_material(surface, _finishes[original])
					continue
				var material := ShaderMaterial.new()
				material.shader = FINISH
				var source_name: String = original.resource_name.to_lower()
				var tint: Color = original.albedo_color
				if "ivory" in source_name: tint = Color(0.94, 0.94, 0.94)
				elif "graphite" in source_name: tint = Color(0.98, 0.99, 1)
				elif "void" in source_name: tint = Color(0.42, 0.48, 0.58)
				elif "lowpoly" in source_name: tint = Color(0.28, 0.37, 0.45)
				material.set_shader_parameter("tint", tint)
				material.set_shader_parameter("metal", minf(original.metallic, 0.28))
				material.set_shader_parameter("base_roughness", original.roughness)
				if original.albedo_texture:
					material.set_shader_parameter("textured", true)
					material.set_shader_parameter("source_albedo", original.albedo_texture)
				child.set_surface_override_material(surface, material)
				_finishes[original] = material
				if "void" in source_name: _boundary_finishes.append(material)
		_finish_source(child)

func open_campaign_aperture() -> void:
	# Imported walls share one mesh/material. Keep the source and isolated
	# room intact; reveal only the exact gap between the adapter's side piers.
	for material in _boundary_finishes:
		material.set_shader_parameter("aperture_room_inverse",get_parent().global_transform.affine_inverse())
		material.set_shader_parameter("aperture_min",Vector3(-0.9,5.2,-14.78))
		material.set_shader_parameter("aperture_max",Vector3(0.9,8.6,-14.22))
		material.set_shader_parameter("campaign_aperture",true)
	if _aperture_open: return
	_aperture_open = true
	var lining := _material(Color(0.15,0.22,0.28),0.45,0.6)
	for x in [-0.92,0.92]:
		_box("CampaignApertureJambLeft" if x<0 else "CampaignApertureJambRight",Vector3(x,6.9,-14.5),Vector3(0.04,3.4,0.44),lining)
	_box("CampaignApertureHeader",Vector3(0,8.62,-14.5),Vector3(1.88,0.04,0.44),lining)

func set_presence(inside: bool) -> void:
	_inside_room = inside
	for airflow in _airflow:
		airflow.visible = inside and not reduced_motion
		airflow.emitting = airflow.visible

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat

func _box(label: String, point: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.position = point
	visual.material_override = material
	add_child(visual)
	return visual

func _build_equipment() -> void:
	var steel := _material(Color(0.42, 0.52, 0.62), 0.25, 0.48)
	var dark := _material(Color(0.18, 0.25, 0.34), 0.12, 0.60)
	var amber := _material(Color(0.63, 0.36, 0.1), 0.25, 0.65)
	# Wall-mounted plumbing keeps all climb faces, landings and wheel sockets clear.
	var pipe := CylinderMesh.new()
	pipe.top_radius = 0.065
	pipe.bottom_radius = 0.065
	pipe.height = 5.7
	pipe.radial_segments = 10
	var pipes := MultiMeshInstance3D.new()
	pipes.name = "WallPressureLines"
	pipes.material_override = steel
	pipes.multimesh = MultiMesh.new()
	pipes.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	pipes.multimesh.mesh = pipe
	pipes.multimesh.instance_count = 8
	for i in 8:
		var side_x := -4.09 if i < 4 else 5.09
		pipes.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(side_x, 4.25, -3.5 - (i % 4) * 2.45)))
	add_child(pipes)
	# Large wall bays have frames and genuine surface depth rather than bright filler.
	for z in [-4.0, -8.5, -12.0]:
		for x in [-4.17, 5.17]:
			_box("ServicePanelInset", Vector3(x, 5.0, z), Vector3(0.05, 2.1, 1.65), dark)
			_box("PanelUpperFrame", Vector3(x + (0.03 if x < 0 else -0.03), 6.07, z), Vector3(0.055, 0.08, 1.75), steel)
			_box("PanelLowerFrame", Vector3(x + (0.03 if x < 0 else -0.03), 3.93, z), Vector3(0.055, 0.08, 1.75), steel)
	# Six shared, static equipment indicators; no extra lights or collision.
	var indicators := MultiMeshInstance3D.new()
	indicators.name = "PressureBayIndicators"
	indicators.multimesh = MultiMesh.new()
	indicators.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var strip := BoxMesh.new()
	strip.size = Vector3(0.025,0.04,1.45)
	indicators.multimesh.mesh = strip
	indicators.multimesh.instance_count = 6
	var index := 0
	for z in [-4.0,-8.5,-12.0]:
		for x in [-4.12,5.12]:
			indicators.multimesh.set_instance_transform(index,Transform3D(Basis.IDENTITY,Vector3(x,4.15,z)))
			index += 1
	var signal_mat := _material(Color(0.12,0.38,0.44),0.05,0.65)
	signal_mat.emission_enabled = true
	signal_mat.emission = Color(0.15,0.52,0.62)
	signal_mat.emission_energy_multiplier = 0.65
	indicators.material_override = signal_mat
	indicators.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(indicators)
	# Pressure assembly is anchored beside the original valve, not on the exit route.
	_box("PressureHousing", Vector3(1.88, 6.95, -12.57), Vector3(0.64, 0.7, 0.11), steel)
	_box("PressureFace", Vector3(1.88, 6.95, -12.49), Vector3(0.5, 0.49, 0.035), dark)
	_service_material = _material(Color(0.78, 0.44, 0.15), 0.12, 0.55)
	_service_material.emission_enabled = true
	_service_material.emission_energy_multiplier = 0.45
	_gauge_needle = _box("PressureNeedle", Vector3(1.88, 6.95, -12.46), Vector3(0.025, 0.2, 0.025), _service_material)
	_gauge_needle.rotation.z = -0.8
	_box("WheelStatus", Vector3(1.25, 6.94, -12.45), Vector3(0.3, 0.035, 0.04), _service_material)
	for i in 4:
		var marker = _box("PressureScale", Vector3(1.75 + i * 0.08, 7.11, -12.46), Vector3(0.025, 0.05, 0.025), amber)
		marker.rotation.z = -0.6 + i * 0.4
	_pressure_caption = Label3D.new()
	_pressure_caption.name = "PressureCaption"
	_pressure_caption.font = preload("res://assets/fonts/NotoSansArabic.ttf")
	_pressure_caption.font_size = 34
	_pressure_caption.pixel_size = 0.005
	_pressure_caption.position = Vector3(0, 7.44, -12.23)
	_pressure_caption.modulate = Color(0.66, 0.78, 0.86)
	_pressure_caption.outline_size = 0
	add_child(_pressure_caption)
	set_language(_language)

func _build_vent() -> void:
	_vent = CPUParticles3D.new()
	_vent.name = "PressureReleaseMist"
	_vent.emitting = false
	_vent.one_shot = true
	_vent.amount = 16
	_vent.lifetime = 1.1
	_vent.explosiveness = 0.2
	_vent.position = Vector3(0, 7.75, -12.6)
	_vent.direction = Vector3(0, -0.1, 1)
	_vent.spread = 22
	_vent.initial_velocity_min = 0.25
	_vent.initial_velocity_max = 0.7
	_vent.gravity = Vector3(0, 0.15, 0)
	_vent.scale_amount_min = 0.05
	_vent.scale_amount_max = 0.14
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.55, 0.78, 0.90, 0.20)
	var radial := GradientTexture2D.new()
	radial.width = 32
	radial.height = 32
	radial.fill = GradientTexture2D.FILL_RADIAL
	radial.fill_from = Vector2(0.5, 0.5)
	radial.fill_to = Vector2(1, 0.5)
	radial.gradient = Gradient.new()
	radial.gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	mat.albedo_texture = radial
	mat.no_depth_test = false
	mesh.material = mat
	_vent.mesh = mesh
	_vent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_vent)

func _build_airflow() -> void:
	# Local slow air at the actual pressure lines, clear of grips and landings.
	# Two batches share the existing soft mist material; no new light/collider.
	for point in [Vector3(-3.95,4.6,-4.0),Vector3(4.95,6.8,-9.9)]:
		var airflow := CPUParticles3D.new()
		airflow.name = "ServiceLineAirflow"
		airflow.position = point
		airflow.mesh = _vent.mesh
		airflow.amount = 12
		airflow.lifetime = 3.0
		airflow.direction = Vector3(1 if point.x<0 else -1,0.18,0.1)
		airflow.spread = 12
		airflow.initial_velocity_min = 0.15
		airflow.initial_velocity_max = 0.35
		airflow.gravity = Vector3(0,0.04,0)
		airflow.scale_amount_min = 0.22
		airflow.scale_amount_max = 0.42
		airflow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		airflow.emitting = false
		airflow.visible = false
		add_child(airflow)
		_airflow.append(airflow)

func set_route_stage(value: int) -> void:
	if route_stage == clampi(value, 0, 7): return
	route_stage = clampi(value, 0, 7)
	_settling = 0.0
	_apply_service_state()

func set_language(language: String) -> void:
	_language = language
	if _pressure_caption:
		_pressure_caption.text = "منفذ الصيانة · تنفيس الضغط" if language == "ar" else "SERVICE ACCESS · PRESSURE RELIEF"

func set_reduced_motion(reduced: bool) -> void:
	reduced_motion = reduced
	if reduced and _vent:
		_vent.emitting = false
		_vent.visible = false
	elif _vent: _vent.visible = true
	set_presence(_inside_room)
	_apply_service_state()

func _on_release() -> void:
	_settling = 1.4
	if not reduced_motion:
		_vent.restart()
		_vent.emitting = true

func _process(delta: float) -> void:
	if not reduced_motion and _inside_room:
		_motion_time += delta
		if route_stage < 6: _gauge_needle.rotation.z = -0.8+sin(_motion_time*5.0)*0.025
	if _settling <= 0 or reduced_motion: return
	_settling = maxf(0, _settling - delta)
	# One quiet decay tied to pressure release. No perpetual pulse or flashing.
	_service_material.emission_energy_multiplier = 0.45 + _settling * 0.18

func _apply_service_state() -> void:
	if not _service_material: return
	var color := Color(0.28, 0.47, 0.56)
	if route_stage == 5: color = Color(0.78, 0.44, 0.15)
	elif route_stage >= 6: color = Color(0.24, 0.72, 0.67)
	_service_material.albedo_color = color
	_service_material.emission = color
	_service_material.emission_energy_multiplier = 0.45
	_gauge_needle.rotation.z = 0.7 if route_stage >= 6 else -0.8
