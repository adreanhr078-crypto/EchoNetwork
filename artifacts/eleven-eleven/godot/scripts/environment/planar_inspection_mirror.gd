extends Node3D

## One bounded reflection, active only beside the mirror. Shared world renders
## the actual current avatar, including its animation and additive modifiers.
const MIRROR_LAYER := 1 << 19
@export var glass_size:=Vector2(4.0,2.8)
@export var reflection_height:=358
@export var active_distance:=11.0
var reflection: SubViewport
var camera: Camera3D
var surface: MeshInstance3D

func _ready() -> void:
	reflection = SubViewport.new()
	reflection.name = "Reflection"
	reflection.size = Vector2i(int(round(reflection_height*glass_size.x/glass_size.y)),reflection_height)
	reflection.render_target_update_mode = SubViewport.UPDATE_DISABLED
	reflection.msaa_3d = Viewport.MSAA_DISABLED
	add_child(reflection)
	reflection.world_3d = get_viewport().world_3d
	camera = Camera3D.new()
	camera.current = true
	reflection.add_child(camera)
	surface = MeshInstance3D.new()
	surface.name = "ActualReflection"
	surface.layers = MIRROR_LAYER
	var quad := QuadMesh.new()
	quad.size = glass_size
	surface.mesh = quad
	surface.rotation.y = -PI/2.0
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded,cull_disabled; uniform sampler2D reflected:filter_linear; void fragment(){ALBEDO=texture(reflected,vec2(1.0-UV.x,UV.y)).rgb;}"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("reflected",reflection.get_texture())
	surface.material_override = mat
	add_child(surface)

func _process(_delta: float) -> void:
	var source := get_viewport().get_camera_3d()
	if not source or not source.is_inside_tree(): return
	var normal := -global_basis.x.normalized()
	var offset := source.global_position-global_position
	if not is_visible_in_tree() or offset.length() > active_distance or offset.dot(normal) <= 0.08:
		reflection.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	camera.cull_mask = source.cull_mask & ~MIRROR_LAYER
	camera.environment=source.environment
	var reflected_position := source.global_position - 2.0*normal*offset.dot(normal)
	# Align the virtual camera with the physical glass, then use an off-axis
	# frustum through its four corners. A copied FOV produces a fake moving TV.
	var basis := Basis(-global_basis.z,global_basis.y,global_basis.x).orthonormalized()
	camera.global_transform = Transform3D(basis,reflected_position)
	var center := basis.inverse() * (global_position-reflected_position)
	var distance := maxf(0.08,-center.z)
	# The virtual camera lies behind the physical mirror and its wall.
	# Clip at the glass plane, so the wall cannot cover the reflected actor.
	var near := distance+0.002
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.set_frustum(glass_size.y*near/distance,Vector2(center.x,center.y)*near/distance,near,90.0)
	reflection.render_target_update_mode = SubViewport.UPDATE_ONCE
