extends "res://scripts/environment/maintenance_stormworks_vfx.gd"

## Compatibility with the journey's presentation API; never owns route progress.
var route_stage := 0
var language := "ar"

func set_language(value: String) -> void:
	language = value

func set_route_stage(value: int) -> void:
	route_stage = clampi(value,0,7)
	if _pressure_material:
		_pressure_material.set_shader_parameter("pressure",0.08 if route_stage >= 6 else 0.65)

func open_campaign_aperture() -> void:
	# This source has a real geometric rear opening, not a shader-discard wall.
	pass
