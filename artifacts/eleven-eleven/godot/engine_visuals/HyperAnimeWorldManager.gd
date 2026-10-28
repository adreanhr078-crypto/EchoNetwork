extends Node

signal quality_changed(tier: String)

const Adapter = preload("res://engine_visuals/HyperMaterialAdapter.gd")
const SURFACE = preload("res://engine_visuals/shaders/reactive_surface_pro.gdshader")
const SCREEN = preload("res://engine_visuals/shaders/impact_screen.gdshader")
const SKY = preload("res://engine_visuals/shaders/chromatic_sky.gdshader")
const PRESETS := {
	"archive_memory_vault": {"shadow":Color("2b2e3b"),"sky":Color(.045,.045,.042),"horizon":Color(.21,.215,.205),"key":Color(1,.94,.84),"rim":Color(.48,.66,.66),"fog":.0028,"bloom":.28},
	"reactor_containment": {"shadow":Color("262c46"),"sky":Color(.055,.065,.075),"horizon":Color(.21,.24,.25),"key":Color(.91,.96,1),"rim":Color(.35,.70,.80),"fog":.0022,"bloom":.22},
	"maintenance_pressure_bay": {"shadow":Color("2a2e3b"),"sky":Color(.045,.05,.05),"horizon":Color(.20,.21,.205),"key":Color(1,.96,.90),"rim":Color(.46,.70,.72),"fog":.0018,"bloom":.18},
	"arcane_neon_sanctuary": {"shadow":Color("2a0f3d"),"sky":Color(0.09,0.04,0.21),"horizon":Color(0.18,0.28,0.4),"key":Color(0.78,0.86,1),"rim":Color(0.65,0.24,0.85),"fog":0.006,"bloom":0.55},
	"celestial_vivid_day": {"shadow":Color("141038"),"sky":Color(0.15,0.35,0.7),"horizon":Color(0.62,0.76,0.95),"key":Color(1,0.9,0.76),"rim":Color(0.28,0.44,0.85),"fog":0.002,"bloom":0.36},
	"crimson_overdrive": {"shadow":Color("3b1219"),"sky":Color(0.24,0.04,0.08),"horizon":Color(0.5,0.17,0.22),"key":Color(1,0.54,0.42),"rim":Color(0.55,0.18,0.65),"fog":0.008,"bloom":0.65},
	"abyssal_bioluminescence": {"shadow":Color("141038"),"sky":Color(0.02,0.07,0.16),"horizon":Color(0.06,0.3,0.38),"key":Color(0.46,0.77,0.92),"rim":Color(0.37,0.23,0.76),"fog":0.01,"bloom":0.5}
}
var main: Node3D
var player: CharacterBody3D
var environment: Environment
var world_node: WorldEnvironment
var key_light: DirectionalLight3D
var rim_light: DirectionalLight3D
var attributes: CameraAttributesPractical
var height_fog: FogVolume
var reduced_motion := false
var quality := "high"
var visual_time := 0.0
var preset := "arcane_neon_sanctuary"
var adapter = Adapter.new()
var ripple_points: Array[Vector4] = []
var ripple_strengths: Array[float] = []
var surface_materials: Array[ShaderMaterial] = []
var _ripple_cursor := 0
var _preset_tween: Tween
var _screen_layer: CanvasLayer
var _screen_rect: ColorRect
var _screen_material: ShaderMaterial
var _impact_age := 0.0
var _impact_duration := 0.0
var _impact_strength := 0.0
var _saved_scale := 1.0
var _leased_scale := -1.0
var _release_at := 0
var _last_tick := 0
var _leased_environments: Dictionary = {}
var _owned_environment := false
var _original_attributes: CameraAttributes
var _last_camera_environment: Environment
var _surface_overlay_shader: Shader
var _viewport_state: Dictionary = {}
var _archive_context := false
var _facility_preset_context := ""
var _facility_preset_tween:Tween
var _preset_before_facility := ""
var _height_fog_before_facility := Color(.4,.5,.68)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_tick = Time.get_ticks_usec()
	for i in 16:
		ripple_points.append(Vector4(0,0,0,-1000))
		ripple_strengths.append(0.0)
	RenderingServer.global_shader_parameter_set("player_world_pos",Vector3.ZERO)
	RenderingServer.global_shader_parameter_set("global_wind_data",Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("hyper_visual_time",0.0)
	get_tree().node_added.connect(_on_node_added)

func attach_scene(scene: Node3D, body: CharacterBody3D) -> void:
	if main == scene: return
	detach_scene()
	main = scene
	player = body
	var viewport:=main.get_viewport()
	_viewport_state={"scale":viewport.scaling_3d_scale,"msaa":viewport.msaa_3d,"ssaa":viewport.screen_space_aa}
	world_node = main.find_child("WorldEnvironment",true,false) as WorldEnvironment
	if not world_node:
		world_node = WorldEnvironment.new()
		world_node.name = "WorldEnvironment"
		main.add_child(world_node)
		_owned_environment = true
	if not world_node.environment: world_node.environment = Environment.new()
	environment = world_node.environment
	_lease_environment(environment)
	attributes = CameraAttributesPractical.new()
	attributes.auto_exposure_enabled = false
	_original_attributes = world_node.camera_attributes
	world_node.camera_attributes = attributes
	key_light = DirectionalLight3D.new()
	key_light.name = "HyperChromaticKey"
	key_light.rotation_degrees = Vector3(-42,-28,0)
	key_light.light_energy = 0.06
	key_light.shadow_enabled = false
	main.add_child(key_light)
	rim_light = DirectionalLight3D.new()
	rim_light.name = "HyperChromaticCounterRim"
	rim_light.rotation_degrees = Vector3(-24,145,0)
	rim_light.light_energy = 0.04
	rim_light.shadow_enabled = false
	main.add_child(rim_light)
	if RenderingServer.get_current_rendering_method()=="forward_plus":
		height_fog=FogVolume.new()
		height_fog.name="HyperHeightAbsorption"
		height_fog.size=Vector3(22,4,22)
		var fog_material:=FogMaterial.new()
		fog_material.density=0.003
		fog_material.albedo=Color(0.4,0.5,0.68)
		fog_material.height_falloff=0.6
		fog_material.edge_fade=0.2
		height_fog.material=fog_material
		main.add_child(height_fog)
	_build_screen()
	adapter.convert_tree(main)
	for mesh in main.find_children("*","MeshInstance3D",true,false): _bind_surface_overlay(mesh)
	set_reduced_motion(main.get("reduced_motion")==true)
	set_preset(preset,0.0)
	_apply_viewport_quality()
	main.tree_exiting.connect(_scene_exiting.bind(main.get_instance_id()),CONNECT_ONE_SHOT)

func _scene_exiting(id: int) -> void:
	if is_instance_valid(main) and main.get_instance_id()==id: detach_scene()

func _lease_environment(env: Environment) -> void:
	var id := env.get_instance_id()
	if _leased_environments.has(id): return
	var original: Environment = env.duplicate(true)
	_leased_environments[id] = {"resource":env,"original":original}
	configure_environment(env)
	if is_instance_valid(world_node) and env!=world_node.environment:
		# A camera-owned interior (the ward/inspection) must not inherit the
		# Environment resource's unconfigured 0.05 volumetric density.
		env.volumetric_fog_density=0.002
		env.volumetric_fog_albedo=Color(0.8,0.84,0.9)
		env.volumetric_fog_emission=Color.BLACK

func configure_environment(env: Environment) -> void:
	var forward := RenderingServer.get_current_rendering_method() == "forward_plus"
	var rich := forward and quality in ["high","ultra"]
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.18
	env.tonemap_white = 6.5
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.38
	env.adjustment_contrast = 1.22
	env.adjustment_brightness = 1.04
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_sky_contribution = 0.0
	# Retain authored exposure and light energy; inject chroma without crushing
	# the darkest texels with the literal very dark palette reference.
	env.ambient_light_color = Color(0.68,0.67,0.78)
	env.ssao_enabled = rich
	env.ssao_intensity = 0.85
	env.ssao_power = 1.0
	env.ssao_light_affect = 0.0
	env.ssil_enabled = rich
	env.ssil_intensity = 0.65
	env.ssr_enabled = rich
	env.ssr_max_steps = 48 if quality == "high" else 64
	env.glow_enabled = forward and quality != "low"
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_normalized = true
	env.set_glow_level(0,0.25)
	env.set_glow_level(1,0.6)
	env.set_glow_level(2,0.35)
	env.volumetric_fog_enabled = rich
	env.volumetric_fog_anisotropy = 0.7
	env.volumetric_fog_ambient_inject = 0.35
	env.volumetric_fog_length = 32.0
	env.fog_height = 0.0
	env.fog_height_density = 0.03
	if forward and not env.sky:
		env.sky = Sky.new()
		var sky_material := ShaderMaterial.new()
		sky_material.shader = SKY
		env.sky.sky_material = sky_material

func set_quality(tier: String) -> bool:
	if tier not in ["low","medium","high","ultra"]: return false
	quality = tier
	_apply_viewport_quality()
	for lease in _leased_environments.values(): configure_environment(lease.resource)
	var vfx:=get_node_or_null("/root/KineticVFXOrchestrator")
	if vfx:
		vfx.quality=tier
		vfx.set_reduced_motion(reduced_motion)
	quality_changed.emit(quality)
	return true

func _apply_viewport_quality() -> void:
	if not is_instance_valid(main): return
	var viewport:=main.get_viewport()
	viewport.scaling_3d_scale=0.65 if quality=="low" else (0.85 if quality=="medium" else 1.0)
	viewport.msaa_3d=Viewport.MSAA_DISABLED if quality=="low" else Viewport.MSAA_4X
	viewport.screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA if quality!="low" and RenderingServer.get_current_rendering_method()!="gl_compatibility" else Viewport.SCREEN_SPACE_AA_DISABLED

func set_preset(id: String, duration: float = 0.8) -> bool:
	if not PRESETS.has(id) or not is_instance_valid(environment): return false
	preset = id
	if _preset_tween and _preset_tween.is_valid(): _preset_tween.kill()
	var values: Dictionary = PRESETS[id]
	var properties := {"volumetric_fog_density":values.fog,"volumetric_fog_albedo":values.horizon,"volumetric_fog_emission":values.shadow,"glow_intensity":values.bloom,"background_color":values.sky}
	if duration <= 0 or reduced_motion:
		for prop in properties: environment.set(prop,properties[prop])
	else:
		_preset_tween = create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_STOP)
		for prop in properties: _preset_tween.tween_property(environment,prop,properties[prop],duration).set_trans(Tween.TRANS_SINE)
	if is_instance_valid(key_light): key_light.light_color = values.key
	if is_instance_valid(rim_light): rim_light.light_color = values.rim
	if environment.sky and environment.sky.sky_material is ShaderMaterial:
		var sky_material := environment.sky.sky_material as ShaderMaterial
		if sky_material.shader == SKY:
			if duration>0.0 and not reduced_motion:
				_preset_tween.tween_property(sky_material,"shader_parameter/zenith",values.sky,duration)
				_preset_tween.tween_property(sky_material,"shader_parameter/horizon",values.horizon,duration)
			else:
				sky_material.set_shader_parameter("zenith",values.sky)
				sky_material.set_shader_parameter("horizon",values.horizon)
	return true

func make_reactive_surface(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SURFACE
	material.set_shader_parameter("base_color",color)
	surface_materials.append(material)
	_sync_ripples(material)
	return material

func imprint(position: Vector3, strength: float = 1.0) -> void:
	if reduced_motion or not position.is_finite() or not is_finite(strength): return
	ripple_points[_ripple_cursor] = Vector4(position.x,position.y,position.z,visual_time)
	ripple_strengths[_ripple_cursor] = clampf(strength,0.0,2.0)
	_ripple_cursor = (_ripple_cursor+1)%16
	for material in surface_materials: _sync_ripples(material)

func _sync_ripples(material: ShaderMaterial) -> void:
	material.set_shader_parameter("ripple_points",ripple_points)
	material.set_shader_parameter("ripple_strengths",ripple_strengths)

func _build_screen() -> void:
	_screen_layer = CanvasLayer.new()
	_screen_layer.name = "HyperImpactPresentation"
	_screen_layer.layer = 3
	main.add_child(_screen_layer)
	_screen_rect = ColorRect.new()
	_screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen_material = ShaderMaterial.new()
	if RenderingServer.get_current_rendering_method()=="gl_compatibility":
		# No framebuffer read, aberration or radial blur on the fallback tier.
		# Keep a very small colored impact cue and the same pause-safe contract.
		var fallback:=Shader.new()
		fallback.code="shader_type canvas_item; render_mode unshaded; uniform float strength=0.0; uniform float phase=0.0; uniform vec2 impact_center=vec2(0.5); uniform vec2 viewport_size=vec2(960,540); void fragment(){COLOR=vec4(0.25,0.38,0.5,strength*0.018);}"
		_screen_material.shader=fallback
	else:
		_screen_material.shader = SCREEN
	_screen_rect.material = _screen_material
	_screen_rect.visible = false
	_screen_layer.add_child(_screen_rect)

func trigger_impact_pulse(intensity: float, duration: float, world_pos: Vector3) -> void:
	if reduced_motion or get_tree().paused or not is_instance_valid(main): return
	if not is_finite(intensity) or not is_finite(duration) or not world_pos.is_finite(): return
	var camera := main.get_viewport().get_camera_3d()
	if not camera or camera.is_position_behind(world_pos): return
	_impact_strength = clampf(maxf(_impact_strength,intensity),0.0,1.0)
	_impact_duration = clampf(duration,0.06,0.5)
	_impact_age = 0.0
	_screen_material.set_shader_parameter("impact_center",camera.unproject_position(world_pos)/main.get_viewport().get_visible_rect().size)
	_screen_material.set_shader_parameter("viewport_size",main.get_viewport().get_visible_rect().size)
	_screen_rect.visible = true
	# Only a confirmed combat event may stop time. Physical landings use the
	# camera/VFX response and never slow human traversal.
	if player and bool(player.get("combat_available")) and intensity >= 0.65:
		if _leased_scale < 0.0:
			_saved_scale = Engine.time_scale
			_leased_scale = _saved_scale * 0.3
			Engine.time_scale = _leased_scale
		_release_at = Time.get_ticks_usec()+55000

func _release_time() -> void:
	if _leased_scale >= 0.0 and is_equal_approx(Engine.time_scale,_leased_scale): Engine.time_scale = _saved_scale
	_leased_scale = -1.0
	_release_at = 0

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if enabled:
		if not _facility_preset_context.is_empty() or (_facility_preset_tween!=null and _facility_preset_tween==_preset_tween and _facility_preset_tween.is_valid()):
			_apply_facility_room_preset(preset,0.0)
		_release_time()
		_impact_strength = 0.0
		if is_instance_valid(_screen_rect): _screen_rect.visible = false
		for i in 16: ripple_strengths[i] = 0.0
		for material in surface_materials: _sync_ripples(material)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real_delta := clampf(float(now-_last_tick)/1000000.0,0.0,0.1)
	_last_tick = now
	if _leased_scale >= 0 and (now>=_release_at or get_tree().paused): _release_time()
	if get_tree().paused: return
	if not reduced_motion: visual_time += real_delta * Engine.time_scale
	RenderingServer.global_shader_parameter_set("hyper_visual_time",visual_time)
	if not is_instance_valid(main) or not is_instance_valid(player): return
	adapter.sync_animated_values()
	RenderingServer.global_shader_parameter_set("player_world_pos",player.global_position)
	var wind := Vector3(0.08,0.0,0.035)*(0.7+sin(visual_time*0.37)*0.3)-player.velocity*0.01
	RenderingServer.global_shader_parameter_set("global_wind_data",Vector4(wind.x,wind.y,wind.z,visual_time))
	var camera := main.get_viewport().get_camera_3d()
	if camera and camera.environment and camera.environment!=_last_camera_environment:
		_lease_environment(camera.environment)
		_last_camera_environment=camera.environment
	environment=camera.environment if camera and camera.environment else world_node.environment
	_sync_room_environment_context()
	if is_instance_valid(height_fog):
		height_fog.visible=quality in ["high","ultra"] and not (camera and camera.environment)
		height_fog.global_position=player.global_position+Vector3.UP
	# The ward's dedicated camera environment owns its lighting. Global
	# facility fill lights must not leak into it.
	var local_override := camera and camera.environment!=null
	if is_instance_valid(key_light): key_light.visible=not local_override
	if is_instance_valid(rim_light): rim_light.visible=not local_override
	if _impact_strength > 0:
		_impact_age += real_delta
		var phase := clampf(_impact_age/maxf(_impact_duration,0.001),0.0,1.0)
		_screen_material.set_shader_parameter("phase",phase)
		_screen_material.set_shader_parameter("strength",_impact_strength*(1.0-phase))
		if phase>=1.0:
			_impact_strength = 0.0
			_screen_rect.visible = false

func _apply_facility_room_preset(id:String,duration:float)->void:
	if not is_instance_valid(world_node):return
	# The shared renderer owns the facility lease. A cinematic/ward camera's
	# private Environment keeps its independent ownership during a transition.
	var active_environment:Environment=environment
	environment=world_node.environment
	set_preset(id,duration)
	_facility_preset_tween=_preset_tween
	environment=active_environment

func _sync_room_environment_context()->void:
	var campaign:Node=main.get_node_or_null("NativeCampaignController")
	var next_profile:=""
	if campaign!=null and campaign.active:
		if campaign.current==1:next_profile="archive_memory_vault"
		elif campaign.current==2 and "rooms" in campaign and campaign.rooms.size()>2 and is_instance_valid(player):
			# The campaign advances at the previous room's exit,while the
			# player is still in its conduit. Enter this profile only inside
			# the measured reactor,without owning any progression trigger.
			var point:Vector3=campaign.rooms[2].to_local(player.global_position)
			if point.z<=.15 and point.z>=-44.25 and absf(point.x)<=18.25:
				next_profile="reactor_containment"
	elif is_instance_valid(player):
		var maintenance:Node=main.get_node_or_null("SystemJourneyPreview")
		if maintenance!=null and "room" in maintenance and is_instance_valid(maintenance.room):
			var point:Vector3=maintenance.room.to_local(player.global_position)
			var inside_room:bool=point.x>=-4.25 and point.x<=5.25 and point.z<=.55 and point.z>=-14.65
			if maintenance.room.has_method("contains_presentation_point"):inside_room=maintenance.room.contains_presentation_point(point)
			if inside_room:next_profile="maintenance_pressure_bay"
	if next_profile==_facility_preset_context:return
	# Save the real prior environment once,including direct archive→reactor
	# transitions. A facility profile never becomes the next scene's baseline.
	if _facility_preset_context.is_empty():
		_preset_before_facility=preset
		if is_instance_valid(height_fog) and height_fog.material is FogMaterial:
			_height_fog_before_facility=height_fog.material.albedo
	_apply_facility_room_preset(_preset_before_facility if next_profile.is_empty() else next_profile,.65)
	if is_instance_valid(height_fog) and height_fog.material is FogMaterial:
		if next_profile=="archive_memory_vault":height_fog.material.albedo=Color(.40,.41,.39)
		elif next_profile=="reactor_containment":height_fog.material.albedo=Color(.38,.41,.44)
		elif next_profile=="maintenance_pressure_bay":height_fog.material.albedo=Color(.40,.42,.41)
		else:height_fog.material.albedo=_height_fog_before_facility
	if next_profile.is_empty():_preset_before_facility=""
	_facility_preset_context=next_profile
	_archive_context=next_profile=="archive_memory_vault"

func _on_node_added(node: Node) -> void:
	if node is MeshInstance3D and is_instance_valid(main): _convert_added.call_deferred(weakref(node))

func _convert_added(reference: WeakRef) -> void:
	var node: Node = reference.get_ref()
	if is_instance_valid(node) and is_instance_valid(main) and main.is_ancestor_of(node):
		adapter.convert_mesh(node as MeshInstance3D)
		_bind_surface_overlay(node as MeshInstance3D)

func _bind_surface_overlay(mesh: MeshInstance3D) -> void:
	var label:=str(mesh.name).to_lower()
	if not mesh.mesh or not (label.contains("floor") or label.contains("deck")): return
	if mesh.get_aabb().size.y>0.8 or mesh.has_meta("hyper_surface_overlay"): return
	if not _surface_overlay_shader:
		_surface_overlay_shader=Shader.new()
		var code:=SURFACE.code.replace("render_mode cull_back, diffuse_burley, specular_schlick_ggx;","render_mode unshaded, blend_add, depth_draw_never, cull_back;")
		code=code.replace("ALBEDO = mix(color, color*vec3(0.72,0.9,1.0),fresnel*0.15);","ALBEDO = signal_color.rgb * ripple * 0.14;\n ALPHA=clamp(ripple,0.0,1.0);")
		code=code.replace("EMISSION = signal_color.rgb * (ripple*(0.12+energy_enabled*1.8) + energy_enabled*proximity*(grid*0.2+caustic*0.08));","EMISSION=vec3(0.0);")
		_surface_overlay_shader.code=code
	for index in mesh.mesh.get_surface_count():
		var original:=mesh.get_active_material(index)
		if not original or original.next_pass: continue
		var retained: Material=original.duplicate()
		var overlay:=ShaderMaterial.new()
		overlay.shader=_surface_overlay_shader
		overlay.set_shader_parameter("signal_color",Color(0.36,0.42,0.5))
		surface_materials.append(overlay)
		_sync_ripples(overlay)
		retained.next_pass=overlay
		if mesh.material_override: mesh.material_override=retained
		else: mesh.set_surface_override_material(index,retained)
	mesh.set_meta("hyper_surface_overlay",true)

func detach_scene() -> void:
	if not _facility_preset_context.is_empty():preset=_preset_before_facility
	_archive_context=false;_facility_preset_context="";_preset_before_facility=""
	_facility_preset_tween=null
	_release_time()
	_impact_strength=0.0
	_impact_duration=0.0
	if is_instance_valid(main) and not _viewport_state.is_empty():
		var viewport:=main.get_viewport()
		viewport.scaling_3d_scale=_viewport_state.scale
		viewport.msaa_3d=_viewport_state.msaa
		viewport.screen_space_aa=_viewport_state.ssaa
	_viewport_state.clear()
	if _preset_tween and _preset_tween.is_valid(): _preset_tween.kill()
	for lease in _leased_environments.values():
		var env: Environment = lease.resource
		var original: Environment = lease.original
		for prop in original.get_property_list():
			if int(prop.usage)&PROPERTY_USAGE_STORAGE and str(prop.name) not in ["resource_path","resource_name","resource_local_to_scene"]:
				env.set(prop.name,original.get(prop.name))
	_leased_environments.clear()
	for node in [key_light,rim_light,height_fog,_screen_layer]:
		if is_instance_valid(node): node.queue_free()
	if _owned_environment and is_instance_valid(world_node): world_node.queue_free()
	_owned_environment = false
	if is_instance_valid(world_node): world_node.camera_attributes=_original_attributes
	main = null
	player = null
	environment = null
	world_node = null
	surface_materials.clear()
	adapter.cache.clear()
	adapter.sources.clear()
	adapter.states.clear()
	_last_camera_environment=null

func _exit_tree() -> void:
	_release_time()
