extends Node3D

## Presentation only. No collision, progression, input or camera ownership.
const MAIN_ONLY_LAYER := 1 << 18
var trial: Node
var laboratory: Node3D
var water: MeshInstance3D
var material: ShaderMaterial
var coolant_material: ShaderMaterial
var reflection_view: SubViewport
var reflection_camera: Camera3D
var elapsed := 0.0
var active := false
var presentation_covered := false
var pact_view_active := false
var _update_clock := 0.0
var _step_clock := 0.0
var _ripple_index := 0
var physical_basins:Array[MeshInstance3D]=[]

func configure(director: Node, room: Node3D) -> void:
	trial = director
	laboratory = room
	water = MeshInstance3D.new()
	water.name = "SubjectiveMemoryWaterSurface"
	water.mesh = PlaneMesh.new()
	water.mesh.size = Vector2(31.6,39.6)
	# The existing decorative pool's top is0.04m. Keep the new surface above
	# it, otherwise the old opaque violet material completely occludes it.
	water.position = Vector3(0,.055,-20)
	water.layers = MAIN_ONLY_LAYER
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/memory_water.gdshader")
	_set_surface_parameter("reflection_gain",1.0)
	_set_surface_parameter("reflection_tint",Color.WHITE)
	water.material_override = material
	reflection_view = SubViewport.new()
	reflection_view.name = "MemoryWaterReflection"
	reflection_view.size = Vector2i(768,960)
	reflection_view.world_3d = get_viewport().world_3d
	reflection_view.transparent_bg = false
	reflection_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(reflection_view)
	reflection_camera = Camera3D.new()
	reflection_view.add_child(reflection_camera)
	reflection_camera.current = true
	_set_surface_parameter("reflection_map", reflection_view.get_texture())
	coolant_material=material.duplicate()
	coolant_material.set_shader_parameter("reflection_gain",.55)
	coolant_material.set_shader_parameter("reflection_tint",Color(.90,.95,1.0))
	water.hide()
	# Permanent physical coolant reservoirs flank the original dry route;
	# the full subjective surface remains controlled by the Canon event.
	for side in [-1.0,1.0]:
		var basin:=MeshInstance3D.new()
		basin.name="ClinicalCoolantWater"
		var plane:=PlaneMesh.new();plane.size=Vector2(4.2,25.0)
		basin.mesh=plane;basin.position=Vector3(side*11,.055,-20)
		basin.layers=MAIN_ONLY_LAYER;basin.material_override=coolant_material
		basin.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(basin);physical_basins.append(basin)

func _process(delta: float) -> void:
	if not is_instance_valid(trial) or not is_instance_valid(laboratory): return
	var full_surface:bool=pact_view_active or trial.phase in ["memories","refusal","abyss","drowning"]
	var local_player:Vector3=laboratory.to_local(laboratory.player.global_position) if is_instance_valid(laboratory.player) else Vector3(999,999,999)
	var in_room:bool=absf(local_player.x)<17 and local_player.z<1 and local_player.z> -41 and local_player.y<12
	var show_water: bool = not presentation_covered and in_room
	water.visible=show_water and full_surface
	for basin in physical_basins:basin.visible=show_water
	if not show_water:
		if active:
			water.hide()
			reflection_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		active = false
		return
	if not active:
		active = true
		elapsed = 0.0
		_step_clock = 0.0
		_ripple_index = 0
		for key in ["ripple_a","ripple_b","ripple_c","ripple_d"]: _set_surface_parameter(key,Vector4(0,0,-100,0))
		_update_clock = 1.0
	if not laboratory.reduced_motion: elapsed += delta
	_set_surface_parameter("elapsed",elapsed)
	_set_surface_parameter("motion",0.0 if laboratory.reduced_motion else 1.0)
	_step_clock += delta
	var player: Node3D = laboratory.player
	if not laboratory.reduced_motion and player is CharacterBody3D and _step_clock > .35:
		if absf(player.global_position.y-water.global_position.y) < .22 and Vector2(player.velocity.x,player.velocity.z).length() > .5:
			var key: String = ["ripple_a","ripple_b","ripple_c","ripple_d"][_ripple_index%4]
			_set_surface_parameter(key,Vector4(player.global_position.x,player.global_position.z,elapsed,1))
			_ripple_index += 1
			_step_clock = 0.0
	_update_clock += delta
	var low:bool=is_instance_valid(trial.main) and trial.main.visual_quality=="low"
	var resolution:=Vector2i(320,400) if low else Vector2i(768,960)
	if reflection_view.size!=resolution:reflection_view.size=resolution
	if _update_clock < 1.0/(15.0 if full_surface else (6.0 if low else 12.0)): return
	_update_clock = 0.0
	var source: Camera3D = get_viewport().get_camera_3d()
	if not is_instance_valid(source): return
	var eye := source.global_position
	eye.y = 2.0*water.global_position.y-eye.y
	var height: float = water.global_position.y-eye.y
	if height <= .01:
		reflection_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	# Off-axis projection: the near plane is the physical water rectangle.
	# Clipping at the water height removes submerged floor/dais undersides
	# without replacing any world materials or changing their render layers.
	reflection_camera.global_position = eye
	reflection_camera.look_at(eye+Vector3.UP,Vector3(0,0,-1))
	reflection_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	var centre: Vector3 = water.global_position-eye
	var offset := Vector2(reflection_camera.global_basis.x.dot(centre),reflection_camera.global_basis.y.dot(centre))
	reflection_camera.set_frustum(39.6,offset,height,maxf(height+10.0,source.far))
	reflection_camera.cull_mask = source.cull_mask & ~MAIN_ONLY_LAYER
	reflection_camera.environment = source.environment
	var vp: Projection = reflection_camera.get_camera_projection()*Projection(reflection_camera.global_transform.affine_inverse())
	_set_surface_parameter("reflection_vp",vp)
	reflection_view.render_target_update_mode = SubViewport.UPDATE_ONCE


func _set_surface_parameter(parameter:StringName,value:Variant)->void:
	material.set_shader_parameter(parameter,value)
	if coolant_material:coolant_material.set_shader_parameter(parameter,value)
