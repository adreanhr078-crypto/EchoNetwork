extends Node3D

## Local air, condensation and cooling. No hazards, progression or extra footsteps.
const PARTICLE = preload("res://shaders/physical_air.gdshader")
const FAN = preload("res://assets/environments/maintenance_cp45/maintenance_ventilation_fan_pbr.glb")
var room:Node3D
var role := ""
var elapsed := 0.0
var _air:Array[GPUParticles3D]=[]
var _rotors:Array[Node3D]=[]
var _step_source:Node
var _dust:GPUParticles3D
var _last_dust := -1.0
var _dust_contacts := 0
var _motion := false
var _quality := ""

static func install(owner_room:Node3D,kind:String)->void:
	if owner_room.has_node("PhysicalDeviceAtmosphere") or OS.get_cmdline_user_args().has("--device-atmosphere-baseline"):return
	var effect:Node3D=load("res://scripts/environment/room_device_atmosphere.gd").new()
	effect.name="PhysicalDeviceAtmosphere";effect.room=owner_room;effect.role=kind;owner_room.add_child(effect)

func _ready()->void:
	match role:
		"security":
			for side in [-1.0,1.0]:
				var fan:Node3D=FAN.instantiate();fan.name="ServiceExtractionFan";fan.position=Vector3(side*4.16,3.3,-8.6 if side<0 else -14.5);fan.rotation.y=PI*.5 if side<0 else -PI*.5;fan.scale=Vector3.ONE*.58;add_child(fan)
				_rotors.append(fan.find_child("FanPBRRotorPivot",true,false))
				for mesh:MeshInstance3D in fan.find_children("*","MeshInstance3D",true,false):
					mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					for index in mesh.mesh.get_surface_count():mesh.set_surface_override_material(index,preload("res://scripts/environment/specimen_mechanical_dressing.gd")._texture_finish(mesh.get_active_material(index),room))
				_jet(fan.position+Vector3(-side*.12,0,0),Vector3(-side,-.12,0),16,.05,Color(.64,.70,.73,.17))
		"specimen":
			for index in [0,2,4]:
				var cfg:Dictionary=room._specimen_tanks[index]
				_jet(Vector3(cfg.x+.82,4.48,cfg.z-.82),Vector3(.22,-.18,.12),16,.25,Color(.68,.79,.82,.25))
		"archive":
			for point in [Vector3(-6,3.75,-5.94),Vector3(-16,3.75,5.94)]:
				_jet(point,Vector3(0,.3,-.1 if point.z>0 else .1),18,.035,Color(.78,.70,.58,.20))
		"reactor":
			for side in [-1.0,1.0]:
				_jet(Vector3(side*4.52,1.4,-22),Vector3(side*.18,.48,0),24,.30,Color(.66,.75,.79,.26))
	if role in ["security","archive"]:
		_dust=_jet(Vector3.ZERO,Vector3.UP,12,.045,Color(.61,.57,.49,.19))
		_dust.name="ActualContactDust";_dust.one_shot=true;_dust.explosiveness=.85;_dust.emitting=false;_dust.lifetime=.75;_air.erase(_dust)
	_sync()

func _notification(what:int)->void:
	if what in [NOTIFICATION_PAUSED,NOTIFICATION_UNPAUSED,NOTIFICATION_VISIBILITY_CHANGED] and is_inside_tree() and is_instance_valid(room):_sync()

func _jet(point:Vector3,direction:Vector3,count:int,size:float,tint:Color)->GPUParticles3D:
	var draw:=GPUParticles3D.new();draw.name="PhysicalAirflow";draw.position=point;draw.amount=count;draw.lifetime=3.0;draw.local_coords=true;draw.preprocess=.4;draw.visibility_aabb=AABB(Vector3(-2,-2,-2),Vector3(4,5,4));draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process:=ParticleProcessMaterial.new();process.direction=direction.normalized();process.spread=18;process.gravity=Vector3(.015,.025,0);process.initial_velocity_min=.15;process.initial_velocity_max=.36;process.scale_min=size;process.scale_max=size*2
	process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_SPHERE;process.emission_sphere_radius=.12
	var ramp:=Gradient.new();ramp.set_color(0,Color(1,1,1,0));ramp.set_color(1,Color(1,1,1,0));ramp.add_point(.25,Color.WHITE);var gradient:=GradientTexture1D.new();gradient.gradient=ramp;process.color_ramp=gradient;draw.process_material=process
	var finish:=ShaderMaterial.new();finish.shader=PARTICLE;finish.set_shader_parameter("tint",tint)
	var quad:=QuadMesh.new();quad.size=Vector2.ONE;quad.material=finish;draw.draw_pass_1=quad;add_child(draw);_air.append(draw);return draw

func _process(delta:float)->void:
	_sync()
	if _motion:elapsed+=minf(delta,.1)
	for i in _rotors.size():
		if _motion:_rotors[i].rotation.z=-fposmod(elapsed*3.2+i*.4,TAU)
	if _dust and is_instance_valid(room.player):
		var source:Node=room.player.find_child("EchoFootstepSystem",true,false)
		if source!=_step_source:
			if is_instance_valid(_step_source) and _step_source.is_connected("footstep_triggered",_on_step):_step_source.disconnect("footstep_triggered",_on_step)
			_step_source=source
			if _step_source and not _step_source.is_connected("footstep_triggered",_on_step):_step_source.connect("footstep_triggered",_on_step)

func _sync()->void:
	_motion=room.is_visible_in_tree() and not room.reduced_motion and not get_tree().paused
	_quality=get_node("/root/HyperAnimeWorldManager").quality
	var fraction:=.25 if _quality=="low" else (.55 if _quality=="medium" else 1.0)
	for air in _air:
		air.speed_scale=1.0 if _motion else 0.0;air.emitting=_motion;air.amount_ratio=fraction
		# Native breaker isolation reduces cooling load without changing hazard time.
		if role=="reactor":air.amount_ratio=fraction*(.4 if room.breaker_a_done and room.breaker_b_done else 1.0)
	if _dust:
		_dust.speed_scale=1.0 if _motion else 0.0;_dust.amount_ratio=fraction
		if not _motion:_dust.emitting=false

func _on_step(_left:bool,_surface:String,_running:bool,world_position:Vector3)->void:
	if not _motion or not _dust or get_tree().paused or not world_position.is_finite() or elapsed-_last_dust<.18:return
	var point:Vector3=room.to_local(world_position)
	var near_source:=false
	if role=="security":near_source=absf(point.x)>2.6 and point.z< -4 and point.z> -15
	elif role=="archive":near_source=absf(absf(point.z)-6.5)<1.8 and point.x< -3 and point.x> -19 and absf(point.y)<.3
	if not near_source:return
	_dust.position=point+Vector3.UP*.025;_dust.restart();_dust.emitting=true;_last_dust=elapsed;_dust_contacts+=1

func get_effect_evidence()->Dictionary:
	var connections:=0
	if is_instance_valid(_step_source):
		for connection in _step_source.get_signal_connection_list("footstep_triggered"):
			if connection.callable==Callable(self,"_on_step"):connections+=1
	var budget:=0
	for air in _air:budget+=air.amount
	if _dust:budget+=_dust.amount
	var angles:=[]
	for rotor in _rotors:angles.append(rotor.rotation.z)
	return {"role":role,"clock":elapsed,"motion":_motion,"emitters":_air.size(),"particle_budget":budget,"dust_contacts":_dust_contacts,"contact_connections":connections,"rotor_angles":angles,"quality":_quality,"air_stopped":_air.all(func(air:GPUParticles3D):return not air.emitting and air.speed_scale==0.0),"air_ratio":_air[0].amount_ratio if not _air.is_empty() else 0.0,"transparent_tail":_air.all(func(air:GPUParticles3D):return air.process_material.color_ramp.gradient.sample(1).a==0)}
