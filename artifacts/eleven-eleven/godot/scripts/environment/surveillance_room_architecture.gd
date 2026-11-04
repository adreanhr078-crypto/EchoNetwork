extends Node3D

## Room08 appearance only. Native collision,mirror inspection,terminal,save and
## gate keep authority;the concept's closed dais facade is deliberately omitted
## to preserve the existing traversable space beneath the native platform.
const BAY=preload("res://assets/environments/surveillance_cp45/surveillance_server_bay_p2.glb")
const TRUSS=preload("res://assets/environments/surveillance_cp45/surveillance_ceiling_truss.glb")
const RAIL=preload("res://assets/environments/surveillance_cp45/surveillance_open_rail.glb")
const SPINE=preload("res://assets/environments/decon_clinical/decon_service_spine_precision.glb")
const LAMP=preload("res://assets/environments/decon_clinical/decon_service_light_precision.glb")
const KIT=preload("res://scripts/environment/specimen_mechanical_dressing.gd")
const EMITTER=preload("res://shaders/surveillance_service_emitter.gdshader")
const ARC=preload("res://shaders/surveillance_equipment_arc.gdshader")
const FLOOR=preload("res://shaders/surveillance_industrial_floor.gdshader")
const CEILING=preload("res://shaders/surveillance_ceiling_panels.gdshader")
const FEEDS=preload("res://assets/environments/surveillance_cp45/surveillance_record_feed_atlas.jpg")
const FAN=preload("res://assets/environments/maintenance_cp45/maintenance_ventilation_fan_pbr.glb")
const PARTICLE=preload("res://engine_visuals/shaders/kinetic_particle.gdshader")
const LAYER=1<<18
var room:Node3D
var _finishes:Dictionary={}
var _signals:Array[ShaderMaterial]=[]
var _arc:ShaderMaterial
var _fans:Array[Node3D]=[]
var _air:Array[GPUParticles3D]=[]
var _sounds:Array[AudioStreamPlayer3D]=[]
var _door_signal:ShaderMaterial

static func evidence_paths()->PackedStringArray:
 var paths:=PackedStringArray(["res://scripts/environment/surveillance_room_architecture.gd",BAY.resource_path,TRUSS.resource_path,RAIL.resource_path,SPINE.resource_path,LAMP.resource_path,EMITTER.resource_path,ARC.resource_path,FLOOR.resource_path,CEILING.resource_path,FEEDS.resource_path,FAN.resource_path,PARTICLE.resource_path,"res://shaders/surveillance_network.gdshader",BAY.resource_path+".import",FEEDS.resource_path+".import"])
 for suffix in ["basecolor.jpg","normal.jpg","rm.png"]:
  var path:String="res://assets/environments/surveillance_cp45/surveillance_server_bay_p2_room08-server-bay-p2-pbr4k_"+suffix
  paths.append(path);paths.append(path+".import")
 return paths

func get_effect_evidence()->Dictionary:
 var angles:Array=[]
 for fan in _fans:angles.append(fan.rotation.z)
 return {"fan_angles":angles,"fans":_fans.size(),"air_emitters":_air.size(),"air_budget":24,"air_stopped":_air.all(func(air:GPUParticles3D):return not air.emitting and air.speed_scale==0.0),"all_silent":_sounds.all(func(sound:AudioStreamPlayer3D):return not sound.playing),"all_hum_started":_sounds.all(func(sound:AudioStreamPlayer3D):return sound.playing),"corona_active":float(_arc.get_shader_parameter("active")),"clock":room._presentation.local_time,"has_measured_reflection":has_node("MeasuredInteriorReflection")}

func _ready()->void:
 room=get_parent();process_priority=1;set_meta("source_revision","room08-p2-20261029")
 var bay:Mesh=_mesh(BAY)
 var source:=bay.surface_get_material(0) as StandardMaterial3D
 var finish:ShaderMaterial=KIT._texture_finish(source,room)
 finish.set_shader_parameter("normal_strength",.45)
 finish.set_shader_parameter("minimum_roughness",.40)
 finish.set_shader_parameter("surface_roughness",.82)
 finish.set_shader_parameter("metalness",.65)
 for side in [-1.0,1.0]:
  var basis:=Basis(Vector3.UP,PI*.5 if side<0 else -PI*.5)
  for chunk in 2:
   var placements:Array=[]
   for row in 2:
    for i in 5:placements.append(Transform3D(basis,Vector3(side*14,.22+row*3.8,-2.7-(chunk*5+i)*3.4)))
   _batch("ServerWall_%s_%d"%["W" if side<0 else "E",chunk],bay,placements,finish)
 for wall in ["South","North"]:
  var placements:Array=[]
  for row in (2 if wall=="South" else 1):
   for x in [-9.9,-6.5,-3.1,3.1,6.5,9.9]:placements.append(Transform3D(Basis(Vector3.UP,PI if wall=="South" else 0.0),Vector3(x,.22+row*3.8,-.02 if wall=="South" else -35.98)))
  _batch(wall+"PortalFlankingEquipment",bay,placements,finish)
 var spines:Array=[];var lamps:Array=[]
 for side in [-1.0,1.0]:
  var basis:=Basis(Vector3.UP,PI*.5 if side<0 else -PI*.5)
  for i in 11:spines.append(Transform3D(basis.scaled(Vector3(1,1.10,1)),Vector3(side*14,.05,-1.0-i*3.4)))
  for i in 10:
   for y in [.12,3.82,7.62]:lamps.append(Transform3D(basis,Vector3(side*13.84,y,-2.7-i*3.4)))
 _batch("TwentyTwoPrecisionServiceColumns",_manufactured_mesh(SPINE),spines)
 _batch("SixtyRecessedTaskLights",_manufactured_mesh(LAMP),lamps)
 var roof:Array=[]
 for z in [-3.5,-9.3,-15.1,-20.9,-26.7,-32.5]:roof.append(Transform3D(Basis.IDENTITY,Vector3(0,7.18,z)))
 _batch("SixMeasuredRoofTrusses",_manufactured_mesh(TRUSS),roof,null,true)
 var rails:Array=[Transform3D(Basis.IDENTITY,Vector3(0,2.35,-21.95)),Transform3D(Basis.IDENTITY,Vector3(0,2.35,-14.05))]
 for side in [-1.0,1.0]:rails.append(Transform3D(Basis(Vector3.UP,PI*.5)*Basis.from_scale(Vector3(.375,1,1)),Vector3(side*3.95,2.35,-19.5)))
 _batch("FourNativeRailingSkins",_manufactured_mesh(RAIL),rails,null,true)
 for label in ["DaisRailNorth","DaisRailSouth","DaisRailWestEdge","DaisRailEastEdge"]:
  for child in room.get_node(label).get_children():
   if child is MeshInstance3D:child.visible=false
 var floor:=ShaderMaterial.new();floor.shader=FLOOR
 floor.set_shader_parameter("grain",preload("res://assets/environments/maintenance_jutsu_v1_Maintenance ceramic grain 512.png"))
 for child in room.get_node("Floor").get_children():
  if child is MeshInstance3D:child.material_override=floor
 for label in ["WestWall","EastWall","Ceiling","NorthWallWest","NorthWallEast","NorthLintel","SouthWallWest","SouthWallEast","SouthLintel"]:
  var body:Node=room.get_node_or_null(label)
  if not body:continue
  for child in body.get_children():
   if child is MeshInstance3D:child.material_override=_solid("Ceiling" if label=="Ceiling" else "Hull",Color(.46,.48,.50) if label=="Ceiling" else Color(.055,.068,.085),.12 if label=="Ceiling" else .28,.76)
 var deck:ShaderMaterial=_solid("DaisDeck",Color(.30,.34,.40),.32,.64)
 for node in room.get_children():
  if str(node.name).begins_with("WestStair") or str(node.name).begins_with("EastStair") or node.name=="CommandDaisDeck":
   for child in node.get_children():
    if child is MeshInstance3D:child.material_override=deck
 _arc=ShaderMaterial.new();_arc.shader=ARC
 for point in [Vector3(-13.79,2.0,-6.1),Vector3(13.79,5.8,-26.5)]:
  var arc:=MeshInstance3D.new();arc.name="ProtectedEquipmentCorona";var quad:=QuadMesh.new();quad.size=Vector2(.12,.34);arc.mesh=quad;arc.position=point;arc.rotation.y=PI*.5 if point.x<0 else -PI*.5;arc.layers=LAYER;arc.material_override=_arc;arc.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(arc)
 for child in room.get_node("ServiceLighting").get_children():
  if child is OmniLight3D:child.light_color=Color(.98,.82,.62);child.light_energy*=.70
 for side in [-1.0,1.0]:
  for z in [-9.0,-27.0]:
   var fill:=OmniLight3D.new();fill.name="EquipmentOnlyWarmBounce";fill.position=Vector3(side*12.2,3.8,z);fill.light_color=Color(.91,.78,.64);fill.light_energy=.35;fill.omni_range=9;fill.light_cull_mask=LAYER;fill.shadow_enabled=false;add_child(fill)
 room._presentation._network.set_shader_parameter("feed_atlas",FEEDS)
 room._presentation._network.set_shader_parameter("has_feed_atlas",true)
 _install_gate_skin()
 # A/B on this Godot4.8dev7/Intel backend:the new probe alone leaves seven
 # texture RIDs at shutdown,even after a render drain. Keep it diagnostic;
 # normal presentation retains engine SSR and the genuine planar mirror.
 if OS.get_cmdline_user_args().has("--surveillance-probe-control"):
  var probe:=ReflectionProbe.new();probe.name="MeasuredInteriorReflection";probe.position=Vector3(0,3.9,-18);probe.size=Vector3(28.4,8.6,36.4);probe.interior=true;probe.box_projection=true;probe.intensity=.72;probe.ambient_mode=ReflectionProbe.AMBIENT_COLOR;probe.ambient_color=Color(.31,.29,.26);probe.ambient_color_energy=.65;probe.cull_mask=LAYER;probe.enable_shadows=false;probe.mesh_lod_threshold=2.0;probe.update_mode=ReflectionProbe.UPDATE_ONCE;add_child(probe)
 var ceiling:=ShaderMaterial.new();ceiling.shader=CEILING
 for child in room.get_node("Ceiling").get_children():
  if child is MeshInstance3D:child.material_override=ceiling
 _install_ventilation()
 _refresh(false)

func _process(_delta:float)->void:_refresh()
func sync_accessibility()->void:_refresh()
func _refresh(start_audio:bool=true)->void:
 var time:float=room._presentation.local_time if room._presentation else 0.0
 var visible_room:bool=room.is_visible_in_tree()
 var motion:float=0.0 if room.reduced_motion or not visible_room else 1.0
 for finish in _signals:
  finish.set_shader_parameter("elapsed",time);finish.set_shader_parameter("motion",motion);finish.set_shader_parameter("cleared",1.0 if room.override_done else 0.0)
 _arc.set_shader_parameter("elapsed",time);_arc.set_shader_parameter("motion",motion);_arc.set_shader_parameter("active",0.0 if room.override_done else 1.0)
 if _door_signal:_door_signal.set_shader_parameter("cleared",1.0 if room.gate_open else 0.0)
 if motion>0.0:
  for i in _fans.size():_fans[i].rotation.z=-fposmod(time*4.2+i*.31,TAU)
 var manager:Node=get_node("/root/HyperAnimeWorldManager")
 for air in _air:
  air.amount_ratio=.25 if manager.quality=="low" else (.55 if manager.quality=="medium" else 1.0)
  air.speed_scale=motion;air.emitting=motion>0.0
 for sound in _sounds:
  if room.audio_muted or not visible_room:sound.stop()
  elif start_audio and not get_tree().paused and not sound.playing:sound.play()

func _install_gate_skin()->void:
 var finish:ShaderMaterial=_solid("GatePanel",Color(.27,.27,.25),.45,.55)
 for child in room._gate.get_children():
  if child is MeshInstance3D:child.material_override=finish
 _door_signal=ShaderMaterial.new();_door_signal.shader=EMITTER;_door_signal.set_shader_parameter("device_role",2)
 for side in [-1.0,1.0]:
  _box(room._gate,"NativeDoorStatus",Vector3(side*.82,0,.12),Vector3(.025,.70,.025),_door_signal)
  _box(self,"NativePortalPost",Vector3(side*1.18,1.50,-35.92),Vector3(.18,3.0,.25),_solid("PortalSteel",Color(.32,.33,.34),.55,.46))
 _box(self,"NativePortalLintel",Vector3(0,3.0,-35.92),Vector3(2.54,.18,.25),_finishes.PortalSteel)
 for y in [-1.02,-.62,-.22,.22,.62,1.02]:_box(room._gate,"NativeDoorSeam",Vector3(0,y,.113),Vector3(1.70,.018,.02),_finishes.PortalSteel)

func _box(parent:Node3D,label:String,point:Vector3,size:Vector3,finish:ShaderMaterial)->void:
 var draw:=MeshInstance3D.new();draw.name=label;var mesh:=BoxMesh.new();mesh.size=size;draw.mesh=mesh;draw.position=point;draw.material_override=finish;draw.layers|=LAYER;parent.add_child(draw)

func _install_ventilation()->void:
 var hum:AudioStreamWAV=ProceduralCinematicAudio.create_pressure_air(2.4,11110808)
 hum.loop_mode=AudioStreamWAV.LOOP_FORWARD;hum.loop_begin=0
 hum.loop_end=int(float(hum.data.size())/float((2 if hum.format==AudioStreamWAV.FORMAT_16_BITS else 1)*(2 if hum.stereo else 1)))
 for side in [-1.0,1.0]:
  var fan:Node3D=FAN.instantiate();fan.name="ReusedRigidExtractionFan";fan.position=Vector3(side*13.65,6.0,-19.3);fan.rotation.y=PI*.5 if side<0 else -PI*.5;add_child(fan)
  var rotor:Node3D=fan.find_child("FanPBRRotorPivot",true,false);assert(rotor!=null,"Qualified rigid fan pivot missing");_fans.append(rotor)
  for draw:MeshInstance3D in fan.find_children("*","MeshInstance3D",true,false):
   draw.layers|=LAYER;draw.lod_bias=.5;draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   for i in draw.mesh.get_surface_count():
    var finish:ShaderMaterial=KIT._texture_finish(draw.get_active_material(i),room);finish.set_shader_parameter("normal_strength",.45);finish.set_shader_parameter("minimum_roughness",.42);draw.set_surface_override_material(i,finish)
  var air:=GPUParticles3D.new();air.name="PhysicalVentilationAir";air.amount=12;air.lifetime=2.8;air.local_coords=true;air.position=Vector3(0,0,.16);air.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var process:=ParticleProcessMaterial.new();process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX;process.emission_box_extents=Vector3(.42,.42,.03);process.direction=Vector3(0,0,1);process.spread=12;process.initial_velocity_min=.18;process.initial_velocity_max=.32;process.gravity=Vector3(0,-.015,.03);process.scale_min=.03;process.scale_max=.065
  var ramp:=Gradient.new();ramp.set_color(0,Color(1,1,1,0));ramp.set_color(1,Color(1,1,1,0));ramp.add_point(.2,Color.WHITE);var gradient:=GradientTexture1D.new();gradient.gradient=ramp;process.color_ramp=gradient;air.process_material=process
  var finish:=ShaderMaterial.new();finish.shader=PARTICLE;finish.set_shader_parameter("tint",Color(.56,.59,.62,.13));finish.set_shader_parameter("brightness",.08);finish.set_shader_parameter("shape",0)
  var quad:=QuadMesh.new();quad.size=Vector2.ONE;quad.material=finish;air.draw_pass_1=quad;fan.add_child(air);_air.append(air)
  var sound:=AudioStreamPlayer3D.new();sound.name="LocalCoolingAirSFX";sound.stream=hum;sound.volume_db=-29;sound.max_distance=8.0;sound.unit_size=1.5;sound.bus="SFX" if AudioServer.get_bus_index("SFX")>=0 else "Master";fan.add_child(sound);_sounds.append(sound)

func _solid(label:String,color:Color,metal:float,rough:float)->ShaderMaterial:
 if not _finishes.has(label):_finishes[label]=KIT._finish(color,metal,rough)
 return _finishes[label]
func _source_finish(source:StandardMaterial3D)->ShaderMaterial:
 var label:String=source.resource_name
 if not _finishes.has(label):
  if label in ["ServiceLamp","Signal"]:
   var result:=ShaderMaterial.new();result.shader=EMITTER;result.set_shader_parameter("device_role",1 if label=="ServiceLamp" else 2);_signals.append(result);_finishes[label]=result
  else:_finishes[label]=KIT._finish(Color(.36,.38,.40) if label in ["Graphite","Ceramic"] else Color(.52,.54,.56),.55,.5)
 return _finishes[label]
func _mesh(scene:PackedScene)->Mesh:
 var source:Node3D=scene.instantiate();var draw:MeshInstance3D=source.find_children("*","MeshInstance3D",true,false)[0];var mesh:Mesh=draw.mesh.duplicate();source.free();return mesh
func _manufactured_mesh(scene:PackedScene)->Mesh:
 var mesh:Mesh=_mesh(scene)
 for i in mesh.get_surface_count():mesh.surface_set_material(i,_source_finish(mesh.surface_get_material(i)))
 return mesh
func _batch(label:String,mesh:Mesh,points:Array,finish:ShaderMaterial=null,shadows:bool=false)->void:
 var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=points.size()
 for i in points.size():mm.set_instance_transform(i,points[i])
 var draw:=MultiMeshInstance3D.new();draw.name=label;draw.multimesh=mm;draw.material_override=finish;draw.layers|=LAYER;draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(draw)
