class_name EmergencyWarningStrobe
extends OmniLight3D

## EmergencyWarningStrobe
## Simulates an industrial alarm strobe beacon in Sector 11 Facility.
## Pulses light energy sharply and rotates a beacon reflector for intense anime emergency mood.

@export var pulse_speed: float = 2.2
@export var peak_energy: float = 3.2
@export var min_energy: float = 0.25
@export var alarm_color: Color = Color(0.96, 0.12, 0.18, 1.0)
@export var strobe_radius: float = 16.0

var _beacon_housing: Node3D = null

func _ready() -> void:
	light_color = alarm_color
	omni_range = strobe_radius
	omni_attenuation = 1.2
	shadow_enabled = false # Keep ultra-fast on Intel UHD / Compatibility
	_create_beacon_housing()

func _create_beacon_housing() -> void:
	_beacon_housing = Node3D.new()
	_beacon_housing.name = "BeaconHousing"
	add_child(_beacon_housing)

	# Small cylindrical housing base
	var base_mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.18
	cyl.bottom_radius = 0.22
	cyl.height = 0.25
	base_mesh.mesh = cyl
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.12, 0.14, 0.18)
	base_mat.metallic = 0.8
	base_mat.roughness = 0.35
	base_mesh.material_override = base_mat
	_beacon_housing.add_child(base_mesh)

	# Glowing beacon dome
	var dome_mesh := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 0.16
	dome.height = 0.28
	dome_mesh.mesh = dome
	dome_mesh.position = Vector3(0, 0.12, 0)
	var dome_mat := StandardMaterial3D.new()
	dome_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	dome_mat.albedo_color = alarm_color
	dome_mesh.material_override = dome_mat
	_beacon_housing.add_child(dome_mesh)

func _process(_delta: float) -> void:
	var t: float = float(Time.get_ticks_msec()) * 0.001
	# Sharp strobe flash pulse waveform
	var raw_sine: float = sin(t * pulse_speed * TAU)
	var flash: float = pow(maxf(0.0, raw_sine), 3.0)
	light_energy = lerpf(min_energy, peak_energy, flash)

	if _beacon_housing:
		_beacon_housing.rotate_y(_delta * pulse_speed * 4.0)
