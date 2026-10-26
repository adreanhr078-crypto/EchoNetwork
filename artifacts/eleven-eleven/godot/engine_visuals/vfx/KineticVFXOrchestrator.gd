extends Node

const PARTICLE = preload("res://engine_visuals/shaders/kinetic_particle.gdshader")
const RIBBON = preload("res://engine_visuals/shaders/kinetic_ribbon.gdshader")
const SpringRig = preload("res://engine_visuals/camera/DynamicActionCameraRig.gd")
const POOL_SIZE := 12
var player: CharacterBody3D
var holder: Node3D
var reduced_motion := false
var quality := "high"
var emitted_bursts := 0
var dropped_bursts := 0
var pool: Array[GPUParticles3D] = []
var remaining: Array[float] = []
var ambient: Array[GPUParticles3D] = []
var trails: Array[GPUParticles3D] = []
var _attack_trail := 0.0
var _connections: Array = []
var _wind_timer := 0.0
var _secondary: Dictionary = {}

func attach_player(scene: Node3D, body: CharacterBody3D) -> void:
	detach_player()
	player = body
	holder = Node3D.new()
	holder.name = "KineticVFXPool"
	scene.add_child(holder)
	for i in POOL_SIZE:
		var particles := _particles(24,0.5,true)
		particles.name = "Burst%02d"%i
		particles.emitting = false
		holder.add_child(particles)
		pool.append(particles)
		remaining.append(0.0)
	for layer in 3:
		var particles := _particles(12+layer*12,5.0,false)
		particles.name = "AmbientDepth%d"%layer
		var process := particles.process_material as ParticleProcessMaterial
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process.emission_box_extents = Vector3(2.0+layer*2.0,1.4+layer,2.0+layer*2.0)
		process.gravity = Vector3(0,0.035+layer*0.025,0)
		process.initial_velocity_min = 0.015
		process.initial_velocity_max = 0.08
		process.scale_min = 0.014 if layer!=0 else 0.018
		process.scale_max = 0.035 if layer!=0 else 0.055
		process.turbulence_enabled = RenderingServer.get_current_rendering_method()=="forward_plus"
		process.turbulence_noise_strength = 0.18
		process.turbulence_noise_scale = 2.0
		var material := particles.draw_pass_1.material as ShaderMaterial
		material.set_shader_parameter("tint",Color(0.35,0.5+layer*0.06,0.65,0.3))
		material.set_shader_parameter("brightness",0.22)
		holder.add_child(particles)
		ambient.append(particles)
	var supports_trails:=RenderingServer.get_current_rendering_method()!="gl_compatibility"
	for index in (2 if supports_trails else 0):
		var trail := _particles(12,0.25,false)
		trail.name="KineticRibbon%d"%index
		trail.trail_enabled=true
		trail.trail_lifetime=0.18
		var ribbon:=RibbonTrailMesh.new()
		ribbon.size=0.045
		ribbon.sections=5
		ribbon.section_length=0.08
		var material:=ShaderMaterial.new()
		material.shader=RIBBON
		ribbon.material=material
		trail.draw_pass_1=ribbon
		trail.emitting=false
		holder.add_child(trail)
		trails.append(trail)
	var footstep := body.find_child("EchoFootstepSystem",true,false)
	if footstep: _connect(footstep,"footstep_triggered",_on_footstep)
	_connect(body,"landing_executed",_on_landing)
	_connect(body,"combat_roll_executed",_on_roll)
	_connect(body,"attack_hit",_on_attack)
	scene.tree_exiting.connect(_scene_exiting.bind(weakref(body)),CONNECT_ONE_SHOT)
	set_reduced_motion(scene.get("reduced_motion")==true)

func _scene_exiting(reference: WeakRef) -> void:
	if reference.get_ref()==player: detach_player()

func _connect(node: Node, signal_name: String, callback: Callable) -> void:
	if node.has_signal(signal_name) and not node.is_connected(signal_name,callback):
		node.connect(signal_name,callback)
		_connections.append([weakref(node),signal_name,callback])

func _particles(count: int, lifetime: float, one_shot: bool) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = count
	particles.lifetime = lifetime
	particles.one_shot = one_shot
	particles.explosiveness = 1.0 if one_shot else 0.0
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-12,-8,-12),Vector3(24,16,24))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 70.0
	process.initial_velocity_min = 0.1
	process.initial_velocity_max = 0.5
	process.gravity = Vector3(0,-0.25,0)
	process.scale_min = 0.035
	process.scale_max = 0.085
	var gradient := Gradient.new()
	gradient.set_color(0,Color(1,1,1,0.7))
	gradient.add_point(0.25,Color.WHITE)
	gradient.set_color(1,Color(1,1,1,0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	particles.process_material = process
	var material := ShaderMaterial.new()
	material.shader = PARTICLE
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = material
	particles.draw_pass_1 = quad
	return particles

func emit_burst(position: Vector3, direction: Vector3, kind: String, energy: float = 0.0) -> bool:
	if reduced_motion or not is_instance_valid(holder) or not position.is_finite() or not direction.is_finite(): return false
	if get_tree().paused: return false
	var index := -1
	for i in pool.size():
		if remaining[i]<=0:
			index=i
			break
	if index<0:
		dropped_bursts += 1
		return false
	var particles := pool[index]
	particles.global_position = position+Vector3.UP*0.025
	var process := particles.process_material as ParticleProcessMaterial
	var material := particles.draw_pass_1.material as ShaderMaterial
	process.direction = direction.normalized() if direction.length_squared()>0.001 else Vector3.UP
	process.initial_velocity_max = 1.4 if kind in ["landing","dash"] else 0.45
	process.scale_max = 0.16 if kind=="landing" else 0.065
	particles.amount_ratio = 0.35 if quality=="low" else 1.0
	material.set_shader_parameter("shape",1 if kind in ["wind","dash","attack"] else 0)
	material.set_shader_parameter("tint",Color(0.3,0.7,0.9,0.7) if energy>0 else Color(0.42,0.43,0.48,0.35))
	material.set_shader_parameter("brightness",1.1 if energy>0 else 0.22)
	particles.restart()
	particles.emitting = true
	remaining[index] = particles.lifetime+0.12
	emitted_bursts += 1
	return true

func _on_footstep(_left: bool, surface: String, running: bool, position: Vector3) -> void:
	if not is_instance_valid(player): return
	var empowered := bool(player.get("combat_available"))
	get_node("/root/HyperAnimeWorldManager").imprint(position,0.45 if running else 0.22)
	emit_burst(position,Vector3.UP,"water" if surface=="water" else "step",0.2 if empowered else 0.0)

func _on_landing(speed: float, heavy: bool) -> void:
	if not is_instance_valid(player): return
	get_node("/root/HyperAnimeWorldManager").imprint(player.global_position,1.4 if heavy else 0.6)
	emit_burst(player.global_position,Vector3.UP,"landing")
	var rig := player.get_node_or_null("DynamicActionCameraRig")
	if rig: rig.landed(speed)

func _on_roll(direction: Vector3) -> void:
	if not is_instance_valid(player): return
	get_node("/root/HyperAnimeWorldManager").imprint(player.global_position,0.6)
	emit_burst(player.global_position,-direction+Vector3.UP*0.1,"dash",0.3 if bool(player.get("combat_available")) else 0.0)

func _on_attack(_damage: int, _critical: bool) -> void:
	if not is_instance_valid(player) or not bool(player.get("combat_available")): return
	var origin := player.global_position+Vector3.UP
	_attack_trail=0.18
	emit_burst(origin,-player.global_basis.z,"attack",0.65)
	get_node("/root/HyperAnimeWorldManager").trigger_impact_pulse(0.7,0.18,origin)
	var rig := player.get_node_or_null("DynamicActionCameraRig")
	if rig: rig.add_trauma(0.25,-player.global_basis.z)

static func exponential_velocity(current: Vector2, desired: Vector2, rate: float, delta: float) -> Vector2:
	return current.lerp(desired,1.0-exp(-maxf(rate,0.0)*maxf(delta,0.0)))

static func momentum_lean(yaw_error: float, speed_ratio: float) -> float:
	return clampf(-yaw_error*clampf(speed_ratio,0.0,1.0)*0.08,-0.045,0.045)

func register_secondary(accessory: Node3D, stiffness: float = 3.0) -> bool:
	# Opt in only. Existing V31 cape bones and authored contact poses are never
	# silently replaced by this generic transform driver.
	if not accessory or not accessory.is_in_group("hyper_secondary_accessory"): return false
	_secondary[accessory.get_instance_id()] = {"node":weakref(accessory),"rest":accessory.rotation,"position":Vector3.ZERO,"velocity":Vector3.ZERO,"frequency":maxf(stiffness,0.2)}
	return true

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	for particles in ambient:
		particles.visible = not enabled and quality!="low"
		particles.emitting = particles.visible
	for i in pool.size():
		pool[i].visible = not enabled
		if enabled:
			pool[i].emitting = false
			remaining[i]=0.0
	for trail in trails:
		trail.visible=not enabled
		if enabled: trail.emitting=false

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	for i in remaining.size(): remaining[i]=maxf(0.0,remaining[i]-delta)
	var camera := player.get_viewport().get_camera_3d()
	var enabled := not reduced_motion and not bool(player.get("control_locked")) and not bool(player.get("opening_recovery_active"))
	_attack_trail=maxf(0.0,_attack_trail-delta)
	for index in trails.size():
		var trail:=trails[index]
		trail.global_position=player.global_position+player.global_basis.x*(0.25 if index==0 else -0.25)+Vector3.UP*(0.85 if index==0 else 1.15)
		trail.visible=enabled and quality!="low"
		trail.emitting=trail.visible and bool(player.get("combat_available")) and (player.velocity.length()>5.0 or _attack_trail>0.0)
	for layer in ambient.size():
		var particles := ambient[layer]
		particles.visible = enabled and quality!="low"
		particles.emitting = particles.visible
		if camera: particles.global_position = camera.global_position-camera.global_basis.z*(2.0+layer*3.0)
	_wind_timer = maxf(0.0,_wind_timer-delta)
	if enabled and player.velocity.length()>3.8 and _wind_timer<=0 and player.is_on_floor():
		_wind_timer=0.28
		emit_burst(player.global_position+Vector3.UP*0.6,-player.velocity,"wind")
	for id in _secondary.keys():
		var data: Dictionary = _secondary[id]
		var accessory: Node3D = data.node.get_ref()
		if not is_instance_valid(accessory):
			_secondary.erase(id)
			continue
		var goal := Vector3.ZERO if reduced_motion else Vector3(player.velocity.z,0,-player.velocity.x)*0.008+Vector3(0.008*sin(get_node("/root/HyperAnimeWorldManager").visual_time*1.8),0,0)
		var spring := SpringRig.spring(data.position,data.velocity,goal,data.frequency,delta)
		data.position=spring[0].limit_length(0.12)
		data.velocity=spring[1]
		accessory.rotation=data.rest+data.position

func detach_player() -> void:
	for binding in _connections:
		var node: Node = binding[0].get_ref()
		if is_instance_valid(node) and node.is_connected(binding[1],binding[2]): node.disconnect(binding[1],binding[2])
	_connections.clear()
	for data in _secondary.values():
		var accessory: Node3D = data.node.get_ref()
		if is_instance_valid(accessory): accessory.rotation = data.rest
	_secondary.clear()
	if is_instance_valid(holder): holder.queue_free()
	holder=null
	player=null
	pool.clear()
	remaining.clear()
	ambient.clear()
	trails.clear()
