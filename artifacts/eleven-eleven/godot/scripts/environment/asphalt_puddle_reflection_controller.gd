class_name AsphaltPuddleReflectionController
extends Node3D

## AAA Real-Time Wet Asphalt Rain Puddle & Screen-Space Reflection Controller
## Simulates dynamic rain ground reflections, roughness/specular transition,
## and footstep water splash acoustics in Minato-Kasumi Town.

signal wetness_changed(new_wetness: float, roughness: float, specular: float)
signal puddle_splashed(splash_position: Vector3, player_velocity: float)

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")

@export_range(0.0, 1.0) var wetness: float = 0.0:
	set(val):
		wetness = clampf(val, 0.0, 1.0)
		_update_puddle_materials()
		emit_signal("wetness_changed", wetness, get_roughness(), get_specular())

const DRY_ROUGHNESS: float = 0.85
const WET_ROUGHNESS: float = 0.08
const DRY_SPECULAR: float = 0.20
const WET_SPECULAR: float = 0.95

var puddle_locations: Array[Vector3] = [
	Vector3(-2.0, 0.01, 3.0),
	Vector3(4.5, 0.01, -1.5),
	Vector3(-8.0, 0.01, 7.0),
	Vector3(1.0, 0.01, 10.0)
]

var puddle_mesh_instances: Array[MeshInstance3D] = []

func _ready() -> void:
	_create_puddle_meshes()

func _create_puddle_meshes() -> void:
	for i in range(puddle_locations.size()):
		var p_pos = puddle_locations[i]
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.name = "PuddleMesh_%d" % i
		mesh_inst.position = p_pos

		var plane_mesh := PlaneMesh.new()
		plane_mesh.size = Vector2(2.5, 1.8)
		mesh_inst.mesh = plane_mesh

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.12, 0.14, 0.6)
		mat.roughness = DRY_ROUGHNESS
		mat.metallic_specular = DRY_SPECULAR
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh_inst.material_override = mat

		add_child(mesh_inst)
		puddle_mesh_instances.append(mesh_inst)

func _update_puddle_materials() -> void:
	var cur_rough = get_roughness()
	var cur_spec = get_specular()
	for inst in puddle_mesh_instances:
		if inst and inst.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = inst.material_override
			mat.roughness = cur_rough
			mat.metallic_specular = cur_spec
			mat.albedo_color.a = clampf(0.3 + wetness * 0.5, 0.0, 0.9)

func set_wetness(val: float) -> void:
	wetness = val

func get_wetness() -> float:
	return wetness

func get_roughness() -> float:
	return lerpf(DRY_ROUGHNESS, WET_ROUGHNESS, wetness)

func get_specular() -> float:
	return lerpf(DRY_SPECULAR, WET_SPECULAR, wetness)

func is_wet() -> bool:
	return wetness > 0.1

## Stepping or sprinting into an asphalt puddle triggers water spray and audio splash
func step_into_puddle(splash_pos: Vector3 = Vector3.ZERO, player_vel: float = 4.0) -> Dictionary:
	if is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_wet_surface_splash_sfx()
		audio.play()
		audio.finished.connect(func(): audio.queue_free())

	emit_signal("puddle_splashed", splash_pos, player_vel)

	return {
		"success": true,
		"splash_pos": splash_pos,
		"player_velocity": player_vel,
		"wetness": wetness,
		"roughness": get_roughness(),
		"specular": get_specular()
	}

## Synchronizes wetness with the town dynamic weather system
func sync_with_weather(weather_name: String) -> void:
	var w_upper = weather_name.to_upper()
	if w_upper.contains("RAIN") or w_upper.contains("STORM") or w_upper.contains("TYPHOON"):
		set_wetness(1.0)
	elif w_upper.contains("DRIZZLE") or w_upper.contains("MIST"):
		set_wetness(0.5)
	elif w_upper.contains("OVERCAST"):
		set_wetness(0.25)
	else:
		set_wetness(0.0)

## Explicit teardown — frees all dynamic puddle meshes and materials to prevent ObjectDB / RID leaks
func _exit_tree() -> void:
	for inst in puddle_mesh_instances:
		if is_instance_valid(inst):
			if inst.material_override != null:
				inst.material_override = null
			inst.queue_free()
	puddle_mesh_instances.clear()
