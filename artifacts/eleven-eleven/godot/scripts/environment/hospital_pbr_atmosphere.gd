extends Node3D

## Visual/physical atmosphere only. All story,collision and patient ownership
## remain with the measured native ward. Legacy visuals remain a diagnostic option.
const HEADWALL=preload("res://assets/environments/hospital_cp45/hospital_headwall_p2.glb")
const CURTAIN=preload("res://assets/environments/hospital_cp45/hospital_pleated_curtain.glb")
const EXTERIOR=preload("res://assets/environments/hospital_cp45/hospital_exterior_original.png")
const CLOTH=preload("res://shaders/ward_curtain.gdshader")
const WET=preload("res://shaders/ward_wet_glass.gdshader")
const BED_PATH="res://assets/environments/hospital_cp45/hospital_bed_p2.glb"
static var _rain_cache:AudioStreamWAV
var room:Node3D
var dressing:Node3D
var _cloth:ShaderMaterial
var _curtain_materials:Array[ShaderMaterial]=[]
var _curtain_wakes:=PackedFloat32Array([0.0,0.0])
var _peak_wake:=0.0
var _rain_sound:AudioStreamPlayer3D
var _wake:=0.0
var _layer:=1

func _ready()->void:
 dressing=get_parent();room=dressing.room
 _layer=room.get_node("Floor/FloorMesh").layers
 var wall:=StandardMaterial3D.new();wall.albedo_color=Color(.74,.72,.67);wall.roughness=.86
 for mesh:MeshInstance3D in room.find_children("*","MeshInstance3D",true,false):
  if str(mesh.name) in ["NorthWallMesh","WestWallMesh","EastWallMesh","SouthWallBelowWindowMesh","SouthWallAboveWindowMesh"] or str(mesh.name).begins_with("SouthWindowPier"):mesh.material_override=wall
 for old in ["HeadwallWarmPanel","MedicalServiceRail","ReadingLightHousing"]:
  var node:=dressing.get_node_or_null(old)
  if node is GeometryInstance3D:node.layers=0
 for node in dressing.get_children():
  if str(node.name).begins_with("ServiceSocket") and node is GeometryInstance3D:node.layers=0
 var head:=HEADWALL.instantiate();head.name="MeasuredTripoHeadwall";head.position=Vector3(-3.16,.4,-.1);head.rotation.y=PI*.5;add_child(head);_layers(head)
 var bed_scene:=load(BED_PATH) as PackedScene
 if bed_scene:
  room.get_node("WardFurniture/WardBedVisual").visible=false
  var bed:=bed_scene.instantiate();bed.name="MeasuredTripoBed";room.get_node("WardFurniture").add_child(bed);_layers(bed)
 _cloth=ShaderMaterial.new();_cloth.shader=CLOTH
 for side in [-1.0,1.0]:
  var curtain:=CURTAIN.instantiate();curtain.name="TopAnchoredCurtain";curtain.position=Vector3(side*1.67,.96,-2.7);add_child(curtain);_layers(curtain)
  var cloth:=_cloth.duplicate() as ShaderMaterial;_curtain_materials.append(cloth)
  for mesh:MeshInstance3D in curtain.find_children("*","MeshInstance3D",true,false):mesh.material_override=cloth
 var pole:=StandardMaterial3D.new();pole.albedo_color=Color(.55,.58,.56);pole.metallic=.65;pole.roughness=.34
 _box("CurtainTrack",Vector3(3.8,.035,.05),Vector3(0,2.76,-2.7),pole)
 dressing.get_node("RainWindowView").layers=0
 var background:=MeshInstance3D.new();background.name="OriginalExteriorMatte";var quad:=QuadMesh.new();quad.size=Vector2(12,7.52);background.mesh=quad;background.position=Vector3(0,2.1,-8.5);background.layers=_layer;background.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var matte:=StandardMaterial3D.new();matte.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;matte.albedo_texture=EXTERIOR;matte.uv1_scale=Vector3(.555,1,1);matte.uv1_offset=Vector3(.2225,0,0);background.material_override=matte;add_child(background)
 var glass:=ShaderMaterial.new();glass.shader=WET;dressing.rain=glass
 room.get_node("WindowGlassBarrier/WindowGlassBarrierMesh").material_override=glass
 var floor_material:ShaderMaterial=room.get_node("Floor/FloorMesh").material_override
 floor_material.set_shader_parameter("floor_color",Color(.44,.47,.46))
 var sun:DirectionalLight3D=room.get_node("WardDaylight");sun.light_color=Color(1,.91,.77);sun.light_energy=1.55
 var environment:Environment=room.get_node("HospitalWorldEnvironment").environment;environment.ambient_light_color=Color(.83,.86,.88);environment.ambient_light_energy=.52
 if RenderingServer.get_current_rendering_method()=="forward_plus":environment.ssr_enabled=true;environment.ssr_max_steps=32
 var lamp:=OmniLight3D.new();lamp.name="HeadwallReadingBounce";lamp.position=Vector3(-2.8,1.7,-.1);lamp.light_color=Color(1,.8,.53);lamp.light_energy=.24;lamp.omni_range=2.4;lamp.shadow_enabled=false;lamp.light_cull_mask=_layer;add_child(lamp)
 var fixture:=StandardMaterial3D.new();fixture.albedo_color=Color(.82,.81,.74);fixture.emission_enabled=true;fixture.emission=Color(.82,.78,.65);fixture.emission_energy_multiplier=.35
 _box("CeilingPractical",Vector3(.55,.025,1.1),Vector3(0,3.17,0),fixture)
 var mirror:Node=room.get_node("WardMirrorReflection")
 var mirror_material:ShaderMaterial=mirror.surface.material_override
 var display_shader:Shader=mirror_material.shader.duplicate()
 display_shader.code=display_shader.code.replace("reflected:filter_linear","reflected:source_color,filter_linear")
 mirror_material.shader=display_shader
 _build_rain_sound();sync_audio(false)

func _layers(node:Node)->void:
 if node is GeometryInstance3D:node.layers=_layer
 for child in node.get_children():_layers(child)
func _box(label:String,size:Vector3,point:Vector3,material:Material)->void:
 var mesh:=MeshInstance3D.new();mesh.name=label;var box:=BoxMesh.new();box.size=size;mesh.mesh=box;mesh.position=point;mesh.material_override=material;mesh.layers=_layer;add_child(mesh)
func _process(delta:float)->void:
 if not is_instance_valid(room):return
 sync_audio()
 if not room.is_visible_in_tree() or room.reduced_motion:return
 _wake=0.0
 for i in _curtain_materials.size():
  var target:=0.0
  if room.player is CharacterBody3D and room.player.is_on_floor():
   var local:Vector3=room.to_local(room.player.global_position)
   var distance:float=Vector2(local.x-(-1.67 if i==0 else 1.67),local.z+2.7).length()
   target=clampf(1.0-distance/1.25,0,1)*clampf(Vector2(room.player.velocity.x,room.player.velocity.z).length()*.4,0,1)
  _curtain_wakes[i]=move_toward(_curtain_wakes[i],target,delta*2.0)
  _wake=maxf(_wake,_curtain_wakes[i]);_peak_wake=maxf(_peak_wake,_wake)
  _curtain_materials[i].set_shader_parameter("elapsed",dressing.elapsed);_curtain_materials[i].set_shader_parameter("echo_wake",_curtain_wakes[i])
func sync_audio(start:bool=true)->void:
 if not _rain_sound:return
 if room.audio_muted or not room.is_visible_in_tree():_rain_sound.stop()
 elif start and not get_tree().paused and not _rain_sound.playing:_rain_sound.play()
func _build_rain_sound()->void:
 if not _rain_cache:
  var rng:=RandomNumberGenerator.new();rng.seed=11111010
  var samples:=PackedFloat32Array();samples.resize(48510);var filtered:=0.0
  for i in samples.size():
   filtered=lerpf(filtered,rng.randf_range(-1,1),.16)
   samples[i]=filtered*.25+(rng.randf_range(-.16,.16) if rng.randf()<.003 else 0.0)
  # Crossfade the tail into the loop entry without touching global random state.
  for i in 256:samples[samples.size()-256+i]=lerpf(samples[samples.size()-256+i],samples[i],float(i)/255.0)
  _rain_cache=ProceduralCinematicAudio.generate_wav(samples,22050);_rain_cache.loop_mode=AudioStreamWAV.LOOP_FORWARD;_rain_cache.loop_begin=256;_rain_cache.loop_end=samples.size()
 _rain_sound=AudioStreamPlayer3D.new();_rain_sound.name="RainOutsideGlassSFX";_rain_sound.stream=_rain_cache;_rain_sound.position=Vector3(0,1.8,-2.84);_rain_sound.volume_db=-28;_rain_sound.unit_size=2.0;_rain_sound.max_distance=7;_rain_sound.bus="SFX" if AudioServer.get_bus_index("SFX")>=0 else "Master";add_child(_rain_sound)
func get_effect_evidence()->Dictionary:
 return {"clock":dressing.elapsed,"wake":_wake,"peak_wake":_peak_wake,"curtain_wakes":Array(_curtain_wakes),"cloth_clock":_curtain_materials[0].get_shader_parameter("elapsed"),"silent":not _rain_sound.playing,"bed_present":room.has_node("WardFurniture/MeasuredTripoBed"),"story":[room.bed_awakened_done,room.mark_revealed_done,room.chapter_completed_done]}
