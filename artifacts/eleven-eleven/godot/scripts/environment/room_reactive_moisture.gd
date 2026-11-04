extends Node3D

## Decorative shallow water and ventilation. The existing animation contact
## signal owns every foot ripple; no independent footstep or progression timer.
const WATER=preload("res://shaders/room_condensation_water.gdshader")
const PARTICLE=preload("res://engine_visuals/shaders/kinetic_particle.gdshader")
var owner_room:Node3D
var clock_property:="_mist_time"
var puddles:Array[MeshInstance3D]=[]
var particles:Array[GPUParticles3D]=[]
var water_material:ShaderMaterial
var wet_contact_count:=0
var _step_source:Node
var _ripples:Array[Vector4]=[Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO]
var _cursor:=0
var _motion:=true
var _quality:=""

func _ready()->void:
	add_to_group("echo_wet_surface_providers")
	water_material=ShaderMaterial.new();water_material.shader=WATER
	water_material.set_shader_parameter("ripples",_ripples)
	var patches:=[ [Vector3(0,.018,-8.7),Vector2(3.0,2.6)], [Vector3(-4.8,.018,-11.7),Vector2(2.4,2.2)], [Vector3(4.8,.018,-11.7),Vector2(2.4,2.2)], [Vector3(-5,.018,-20.5),Vector2(2.7,2.0)], [Vector3(5,.018,-20.5),Vector2(2.7,2.0)], [Vector3(0,.018,-25.5),Vector2(2.2,1.8)] ]
	for i in patches.size():
		var draw:=MeshInstance3D.new();draw.name="CondensationPuddle_%d"%i
		var plane:=PlaneMesh.new();plane.size=patches[i][1];draw.mesh=plane
		draw.position=patches[i][0];draw.material_override=water_material
		draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.layers|=1<<18;add_child(draw);puddles.append(draw)
	for x in [-6.5,6.5]:
		var vent:=_particles(24,3.0,Color(.68,.73,.78,.10),0)
		vent.name="ExtractionAirflow";vent.position=Vector3(x,6.4,-16)
		var process:=vent.process_material as ParticleProcessMaterial
		process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process.emission_box_extents=Vector3(1.5,.05,10)
		process.direction=Vector3(.10,-1,.16);process.spread=18
		process.gravity=Vector3(.04,-.10,.025)
		process.initial_velocity_min=.30;process.initial_velocity_max=.62
		process.scale_min=.20;process.scale_max=.45
		process.turbulence_enabled=RenderingServer.get_current_rendering_method()=="forward_plus"
		process.turbulence_noise_strength=.22;process.turbulence_noise_scale=1.3
	for x in [-6.5,6.5]:
		for z in [-11.0,-16.0,-21.0]:
			var mist:=_particles(8,2.2,Color(.52,.68,.73,.12),0)
			mist.name="VesselCondensation";mist.position=Vector3(x,.35,z)
			var process:=mist.process_material as ParticleProcessMaterial
			process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			process.emission_sphere_radius=.65;process.gravity=Vector3(.03,.04,0)
			process.initial_velocity_min=.07;process.initial_velocity_max=.14
			process.scale_min=.12;process.scale_max=.25
	_refresh()

func _particles(count:int,lifetime:float,tint:Color,shape:int)->GPUParticles3D:
	var draw:=GPUParticles3D.new();draw.amount=count;draw.lifetime=lifetime
	draw.local_coords=false;draw.visibility_aabb=AABB(Vector3(-14,-8,-35),Vector3(28,20,70))
	draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process:=ParticleProcessMaterial.new();process.direction=Vector3.UP;process.spread=35
	var ramp:=Gradient.new();ramp.set_color(0,Color(1,1,1,0));ramp.set_color(1,Color(1,1,1,0));ramp.add_point(.2,Color.WHITE)
	var gradient:=GradientTexture1D.new();gradient.gradient=ramp;process.color_ramp=gradient
	draw.process_material=process
	var finish:=ShaderMaterial.new();finish.shader=PARTICLE
	finish.set_shader_parameter("tint",tint);finish.set_shader_parameter("brightness",.10);finish.set_shader_parameter("shape",shape)
	var quad:=QuadMesh.new();quad.size=Vector2.ONE;quad.material=finish;draw.draw_pass_1=quad
	add_child(draw);particles.append(draw);return draw

func _process(_delta:float)->void:
	if not is_instance_valid(_step_source) and is_instance_valid(owner_room.player):
		_step_source=owner_room.player.find_child("EchoFootstepSystem",true,false)
		if _step_source and not _step_source.is_connected("footstep_triggered",_on_footstep):
			_step_source.connect("footstep_triggered",_on_footstep)
	_refresh()

func _refresh()->void:
	_motion=not owner_room.reduced_motion and owner_room.is_visible_in_tree()
	var manager:Node=get_node("/root/HyperAnimeWorldManager")
	var quality:String=manager.quality
	if quality!=_quality:
		_quality=quality
		for draw in particles:draw.amount_ratio=.25 if quality=="low" else (.55 if quality=="medium" else 1.0)
		water_material.set_shader_parameter("detail",0.0 if quality=="low" else 1.0)
	water_material.set_shader_parameter("motion",1.0 if _motion else 0.0)
	water_material.set_shader_parameter("elapsed",float(owner_room.get(clock_property)))
	for draw in particles:
		draw.speed_scale=1.0 if _motion else 0.0
		draw.emitting=_motion

func contains_water(world_position:Vector3)->bool:
	if not is_instance_valid(owner_room) or not owner_room.is_visible_in_tree():return false
	for puddle in puddles:
		var point:Vector3=puddle.to_local(world_position)
		var uv:Vector2=Vector2(point.x,point.z)/(puddle.mesh.size*.5)
		if absf(point.y)<.25 and uv.length()<.90:return true
	return false

func _on_footstep(_left:bool,_surface:String,running:bool,position:Vector3)->void:
	if get_tree().paused or not _motion or not position.is_finite() or not contains_water(position):return
	_ripples[_cursor]=Vector4(position.x,position.z,float(owner_room.get(clock_property)),.95 if running else .62)
	_cursor=(_cursor+1)%4;wet_contact_count+=1
	water_material.set_shader_parameter("ripples",_ripples)

func get_effect_evidence()->Dictionary:
	var count:=0
	if is_instance_valid(_step_source):
		for connection in _step_source.get_signal_connection_list("footstep_triggered"):
			if connection.callable==Callable(self,"_on_footstep"):count+=1
	var fade_out:=particles.all(func(draw:GPUParticles3D):return draw.process_material.color_ramp.gradient.sample(1.0).a==0.0)
	return {"wet_contacts":wet_contact_count,"contact_connections":count,"ripple_slots":_ripples.size(),"particle_nodes":particles.size(),"particle_budget":96,"fade_out_transparent":fade_out,"motion":_motion,"elapsed":float(owner_room.get(clock_property))}
