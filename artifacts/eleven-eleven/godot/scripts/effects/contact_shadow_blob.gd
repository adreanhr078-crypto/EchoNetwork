class_name ContactShadowBlob
extends Node3D

## Projects a stylized anime contact shadow blob beneath characters in Compatibility mode.
## Uses a simple raycast to position a soft elliptical shadow mesh on the floor.

@export var shadow_radius: float = 0.45
@export var max_distance: float = 4.0
@export var shadow_color: Color = Color(0.015, 0.02, 0.035, 0.65)

var _shadow_mesh: MeshInstance3D = null
var _raycast: RayCast3D = null

func _ready() -> void:
	_setup_shadow_mesh()
	_setup_raycast()

func _setup_shadow_mesh() -> void:
	_shadow_mesh = MeshInstance3D.new()
	_shadow_mesh.name = "ShadowBlobMesh"
	
	var quad := QuadMesh.new()
	quad.size = Vector2(shadow_radius * 2.0, shadow_radius * 2.0)
	quad.orientation = PlaneMesh.FACE_Y
	_shadow_mesh.mesh = quad
	
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = shadow_color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	# Generate a soft circular gradient texture procedurally
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var center := Vector2(32, 32)
	for y in range(64):
		for x in range(64):
			var dist := Vector2(x, y).distance_to(center) / 30.0
			var alpha := clampf(1.0 - dist, 0.0, 1.0)
			alpha = alpha * alpha # smooth quadratic falloff
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	var tex := ImageTexture.create_from_image(img)
	mat.albedo_texture = tex
	_shadow_mesh.material_override = mat
	_shadow_mesh.top_level = true
	add_child(_shadow_mesh)

func _setup_raycast() -> void:
	_raycast = RayCast3D.new()
	_raycast.name = "ShadowRayCast"
	_raycast.target_position = Vector3(0, -max_distance, 0)
	_raycast.collision_mask = 1 # Ground / World
	_raycast.enabled = true
	add_child(_raycast)

func _process(_delta: float) -> void:
	if not _shadow_mesh or not _raycast:
		return
	
	_raycast.global_position = global_position + Vector3(0, 0.2, 0)
	_raycast.force_raycast_update()
	
	if _raycast.is_colliding():
		var hit_pos := _raycast.get_collision_point()
		var hit_normal := _raycast.get_collision_normal()
		var dist := global_position.y - hit_pos.y
		
		_shadow_mesh.visible = true
		_shadow_mesh.global_position = hit_pos + hit_normal * 0.015
		
		# Scale down and fade as character ascends (e.g. during jumps)
		var factor := clampf(1.0 - (dist / max_distance), 0.15, 1.0)
		_shadow_mesh.scale = Vector3(factor, 1.0, factor)
		var mat := _shadow_mesh.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color.a = shadow_color.a * factor
	else:
		_shadow_mesh.visible = false

func _exit_tree() -> void:
	if _shadow_mesh and is_instance_valid(_shadow_mesh):
		_shadow_mesh.queue_free()
