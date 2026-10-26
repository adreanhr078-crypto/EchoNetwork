extends Node

## One shared video texture per memory, not one decoder or viewport per monitor.
## All added geometry is presentation-only; room controllers keep all authority.
const MONITOR=preload("res://engine_visuals/shaders/memory_monitor.gdshader")
const WATER=preload("res://engine_visuals/shaders/leak_water.gdshader")
const DROPS=preload("res://engine_visuals/shaders/leak_drops.gdshader")
const Adapter=preload("res://engine_visuals/HyperMaterialAdapter.gd")
const LAYER=1<<18
const MEDIA="res://assets/cinematics/memory-screens/"
const ROOMS={
	"opening":{"screens":[[Vector3(4.75,2.6,-5.0),-65.0,2.9,"city"]],"leaks":[[Vector3(6.5,2.8,-7.7),Vector3(6.0,0.028,-7.7),Vector2(1.5,3.0)]]},
	"maintenance":{"screens":[[Vector3(-3.1,2.9,-5.5),72.0,2.5,"city"]],"leaks":[[Vector3(-3.5,2.7,-3.5),Vector3(-3.1,0.028,-3.5),Vector2(1.5,2.3)]]},
	"security":{"screens":[[Vector3(-3.75,2.8,-5.2),72.0,2.5,"friends"]],"leaks":[[Vector3(-4.0,2.8,-9.0),Vector3(-3.65,0.028,-9.0),Vector2(1.4,2.7)]]},
	"specimen":{"screens":[[Vector3(-23.0,2.7,-13.7),-12.0,3.0,"friends"]],"leaks":[[Vector3(-27.0,2.7,-15.0),Vector3(-26.5,0.028,-15.0),Vector2(1.8,2.8)]]},
	"archive":{"screens":[[Vector3(-6.0,2.5,13.55),180.0,3.1,"city"],[Vector3(-21.55,2.8,-4.0),90.0,3.8,"friends"]],"leaks":[]},
	"reactor":{"screens":[[Vector3(-5.3,-1.2,-12.5),20.0,2.8,"city"]],"leaks":[]},
	"decon":{"screens":[[Vector3(-4.8,5.2,-16.8),8.0,3.0,"friends"]],"leaks":[[Vector3(10.6,2.6,-11.8),Vector3(10.0,0.028,-11.8),Vector2(2.1,3.1)]]},
	"mirror":{"screens":[[Vector3(-13.55,2.6,-7.0),90.0,3.1,"city"],[Vector3(13.55,2.6,-22.0),-90.0,3.5,"friends"]],"leaks":[]}
}
var main: Node3D
var rooms: Dictionary={}
var sources: Dictionary={}
var active_room:=""
var quality:="high"
var reduced_motion:=false
var nearest_screen: Node3D
var audible_gain:=0.0
var audible_screen: Node3D
var screen_audio: AudioStreamPlayer3D
var drip_audio: AudioStreamPlayer3D
var _discovery_clock:=0.0
var _audio_gain:=0.0
var _audio_pending: Node3D
var _audible_clip:=""
var _water_materials: Array[ShaderMaterial]=[]
var _adapter=Adapter.new()
var _metal: ShaderMaterial
var _screen_count:=0
var _ripples: Array[Vector4]=[Vector4(0,0,-100,0),Vector4(0,0,-100,0),Vector4(0,0,-100,0),Vector4(0,0,-100,0)]
var _ripple_cursor:=0

func configure(owner_scene: Node3D) -> void:
	main=owner_scene
	process_mode=Node.PROCESS_MODE_ALWAYS
	add_to_group("echo_wet_surface_providers")
	var original:=StandardMaterial3D.new()
	original.albedo_color=Color(0.08,0.12,0.16)
	original.roughness=0.48
	original.metallic=0.3
	_metal=_adapter.convert_material(original)
	for id in ["city","friends","reel"]: _create_source(id)
	screen_audio=AudioStreamPlayer3D.new()
	screen_audio.name="NearestMemoryStereo"
	screen_audio.max_distance=5.0
	screen_audio.unit_size=1.7
	screen_audio.panning_strength=0.6
	screen_audio.volume_db=-80.0
	add_child(screen_audio)
	drip_audio=AudioStreamPlayer3D.new()
	drip_audio.name="NearestPipeDrip"
	drip_audio.max_distance=5.0
	drip_audio.unit_size=1.4
	drip_audio.panning_strength=0.7
	drip_audio.volume_db=-80.0
	if ResourceLoader.exists(MEDIA+"pipe-drip.ogg"):
		drip_audio.stream=load(MEDIA+"pipe-drip.ogg")
		drip_audio.stream.loop=true
	add_child(drip_audio)
	for audio in [screen_audio,drip_audio]:
		audio.bus="SFX" if AudioServer.get_bus_index("SFX")>=0 else "Master"
	var footsteps=main.player.find_child("EchoFootstepSystem",true,false)
	if footsteps: footsteps.footstep_triggered.connect(_on_footstep)
	_discover_rooms()
	sync_preferences()

func _create_source(id: String) -> void:
	var video:=VideoStreamPlayer.new()
	video.name="SharedMemory_"+id
	video.expand=true
	video.size=Vector2.ONE
	video.position=Vector2(-4,-4)
	video.mouse_filter=Control.MOUSE_FILTER_IGNORE
	video.volume_db=-80.0
	video.loop=true
	video.buffering_msec=150
	add_child(video)
	var poster_path:=MEDIA+("city" if id=="reel" else id)+"-poster.webp"
	sources[id]={"video":video,"tier":"","started":false,"poster":load(poster_path) if ResourceLoader.exists(poster_path) else null}

func _discover_rooms() -> void:
	_register_room("opening",main)
	var maintenance=main.get_node_or_null("SystemJourneyPreview")
	if maintenance and is_instance_valid(maintenance.room): _register_room("maintenance",maintenance.room)
	var route=main.get_node_or_null("NativeJourneyController")
	if route and is_instance_valid(route.security): _register_room("security",route.security)
	var campaign=main.get_node_or_null("NativeCampaignController")
	if campaign:
		for i in mini(campaign.rooms.size(),5):
			_register_room(["specimen","archive","reactor","decon","mirror"][i],campaign.rooms[i])

func _register_room(id: String, room: Node3D) -> void:
	if rooms.has(id) or not is_instance_valid(room): return
	var holder:=Node3D.new()
	holder.name="PsychologicalMemoryAtmosphere"
	room.add_child(holder)
	var data={"room":room,"holder":holder,"screens":[],"puddles":[],"drops":[]}
	for spec in ROOMS[id].screens:
		var monitor:=Node3D.new()
		monitor.name="FloatingMemory_"+str(_screen_count)
		monitor.position=spec[0]+Vector3(sin(_screen_count*2.7)*0.10,0,0)
		monitor.rotation.y=deg_to_rad(spec[1])
		monitor.rotation.z=deg_to_rad(-3.0 if _screen_count%2==0 else 3.5)
		monitor.rotation.x=deg_to_rad(3.0)
		holder.add_child(monitor)
		var width:float=spec[2]
		var mesh:=MeshInstance3D.new()
		mesh.name="IntactMemorySurface"
		mesh.mesh=QuadMesh.new()
		mesh.mesh.size=Vector2(width,width*0.5625)
		mesh.custom_aabb=mesh.mesh.get_aabb().grow(0.12)
		mesh.material_override=ShaderMaterial.new()
		mesh.material_override.shader=MONITOR
		mesh.material_override.set_shader_parameter("phase",float(_screen_count)*1.7+0.4)
		mesh.layers=LAYER
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.material_override.set_shader_parameter("tint",Color(0.8,0.93,1.0) if id in ["opening","security","decon"] else Color(1.0,0.9,0.85))
		monitor.add_child(mesh)
		monitor.set_meta("clip",spec[3])
		monitor.set_meta("surface",mesh)
		data.screens.append(monitor)
		_screen_count+=1
	for spec in ROOMS[id].leaks:
		var puddle:=MeshInstance3D.new()
		puddle.name="ShallowLeakingWater"
		puddle.mesh=PlaneMesh.new()
		puddle.mesh.size=spec[2]
		puddle.position=spec[1]
		puddle.layers=LAYER
		puddle.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material:=ShaderMaterial.new()
		material.shader=WATER
		material.set_shader_parameter("ripples",_ripples)
		puddle.material_override=material
		_water_materials.append(material)
		holder.add_child(puddle)
		data.puddles.append(puddle)
		_build_leak(holder,spec[0],spec[1],data)
	rooms[id]=data
	holder.hide()

func _box(parent:Node3D,position:Vector3,size:Vector3,material:Material) -> void:
	var mesh:=MeshInstance3D.new()
	mesh.mesh=BoxMesh.new()
	mesh.mesh.size=size
	mesh.position=position
	mesh.material_override=material
	mesh.layers=LAYER
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)

func _build_leak(parent:Node3D,source:Vector3,ground:Vector3,data:Dictionary) -> void:
	# A ruptured floor riser, not a free-floating spout, explains the leak.
	var height:=maxf(0.2,source.y-ground.y)
	var pipe:=MeshInstance3D.new()
	pipe.mesh=CylinderMesh.new()
	pipe.mesh.top_radius=0.065
	pipe.mesh.bottom_radius=0.065
	pipe.mesh.height=height
	pipe.mesh.radial_segments=12
	pipe.position=Vector3(source.x,ground.y+height*0.5,source.z)
	pipe.material_override=_metal
	pipe.layers=LAYER
	parent.add_child(pipe)
	_box(parent,source+Vector3(0,0.04,0),Vector3(0.23,0.12,0.23),_metal)
	var drops:=MultiMeshInstance3D.new()
	drops.name="BoundedPipeDroplets"
	drops.multimesh=MultiMesh.new()
	drops.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	drops.multimesh.use_custom_data=true
	var bead:=SphereMesh.new()
	bead.radius=0.008
	bead.height=0.05
	bead.radial_segments=8
	bead.rings=4
	drops.multimesh.mesh=bead
	drops.multimesh.instance_count=16
	drops.position=source
	var material:=ShaderMaterial.new()
	material.shader=DROPS
	material.set_shader_parameter("height",height)
	drops.material_override=material
	drops.custom_aabb=AABB(Vector3(-0.2,-height-0.2,-0.2),Vector3(0.4,height+0.4,0.4))
	drops.layers=LAYER
	drops.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 16:
		drops.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(sin(i*6.1)*0.025,0,cos(i*7.3)*0.025)))
		drops.multimesh.set_instance_custom_data(i,Color(float(i)/16.0,0,0,1))
	parent.add_child(drops)
	data.drops.append(drops)

func _current_room() -> String:
	var campaign=main.get_node_or_null("NativeCampaignController")
	if campaign and campaign.active:
		return ["specimen","archive","reactor","decon","mirror"][campaign.current] if campaign.current<5 else ""
	var route=main.get_node_or_null("NativeJourneyController")
	if route and route.security_entered: return "security"
	return "opening" if main.player.global_position.z>-18.4 else ("maintenance" if rooms.has("maintenance") else "")

func sync_preferences() -> void:
	if not is_instance_valid(main):return
	quality=main.visual_quality
	reduced_motion=main.reduced_motion
	for data in rooms.values():
		for drops in data.drops:
			drops.visible=not reduced_motion
			drops.multimesh.visible_instance_count=5 if quality=="low" else 16
	for material in _water_materials:
		material.set_shader_parameter("motion",0.0 if reduced_motion else 1.0)
		material.set_shader_parameter("detail",0.35 if quality=="low" else 1.0)
	for source in sources.values(): source.video.paused=reduced_motion or get_tree().paused
	for data in rooms.values():
		for monitor in data.screens:
			var material:ShaderMaterial=monitor.get_meta("surface").material_override
			material.set_shader_parameter("detail",0.0 if quality=="low" else 1.0)
	if main.audio_muted or get_tree().paused:
		for audio in [screen_audio,drip_audio]:
			if audio: audio.stop()
		_audio_gain=0.0
		audible_gain=0.0

func _process(delta:float) -> void:
	if not is_instance_valid(main): return
	if quality!=main.visual_quality or reduced_motion!=main.reduced_motion: sync_preferences()
	if get_tree().paused:
		for source in sources.values(): source.video.paused=true
		for audio in [screen_audio,drip_audio]: audio.stop()
		_audio_gain=0.0
		audible_gain=0.0
		return
	_discovery_clock-=delta
	if _discovery_clock<=0.0:
		_discovery_clock=0.4
		_discover_rooms()
	active_room=_current_room()
	for id in rooms: rooms[id].holder.visible=id==active_room
	var used:Dictionary={}
	var screens:Array=rooms[active_room].screens if rooms.has(active_room) else []
	for monitor in screens:
		var clip:String="reel" if quality=="low" else monitor.get_meta("clip")
		used[clip]=true
		var video:VideoStreamPlayer=_ensure_source(clip)
		var material:ShaderMaterial=monitor.get_meta("surface").material_override
		material.set_shader_parameter("footage",video.get_video_texture() if video.stream_position>0.04 else sources[clip].poster)
		material.set_shader_parameter("motion",0.0 if reduced_motion else 1.0)
		var duration:=16.0 if clip=="reel" else 8.0
		material.set_shader_parameter("clip_duration",duration)
		material.set_shader_parameter("playback_time",fmod(video.stream_position,duration))
	for id in sources:
		var video:VideoStreamPlayer=sources[id].video
		if not used.has(id):
			video.stop()
			sources[id].started=false
		else: video.paused=reduced_motion and video.stream_position>0.05
	_update_audio(screens,delta)

func _ensure_source(id:String) -> VideoStreamPlayer:
	var source:Dictionary=sources[id]
	var tier:="low" if quality=="low" else "high"
	var video:VideoStreamPlayer=source.video
	if source.tier!=tier:
		video.stop()
		var path:=MEDIA+id+"-"+tier+".ogv"
		if ResourceLoader.exists(path): video.stream=load(path)
		source.tier=tier
		source.started=false
	if video.stream and not source.started:
		video.play()
		source.started=true
	return video

static func proximity_gain(distance:float) -> float:
	return 1.0-smoothstep(1.2,5.0,distance)

func _update_audio(screens:Array,delta:float) -> void:
	nearest_screen=null
	var nearest:=5.0
	for monitor in screens:
		var distance:float=main.player.global_position.distance_to(monitor.global_position-Vector3.UP)
		if distance<nearest: nearest=distance;nearest_screen=monitor
	var muted:bool=main.audio_muted or AudioServer.is_bus_mute(0) or main.player.control_locked
	var desired:=proximity_gain(nearest) if nearest_screen and not muted else 0.0
	var desired_clip:String=("reel" if quality=="low" else nearest_screen.get_meta("clip")) if nearest_screen else ""
	# Fade fully to silence before changing a spatial source, never teleport sound.
	if nearest_screen!=audible_screen or desired_clip!=_audible_clip:
		desired=0.0
		if _audio_gain<0.002:
			screen_audio.stop()
			audible_screen=nearest_screen
			_audible_clip=desired_clip
			if audible_screen:
				var clip:=desired_clip
				var path:=MEDIA+clip+".ogg"
				if ResourceLoader.exists(path):
					screen_audio.stream=load(path)
					screen_audio.stream.loop=true
				screen_audio.global_position=audible_screen.global_position
				screen_audio.play(fmod(sources[clip].video.stream_position,16.0 if clip=="reel" else 8.0))
	_audio_gain=move_toward(_audio_gain,desired,delta*2.0)
	if muted:_audio_gain=0.0
	audible_gain=_audio_gain
	screen_audio.volume_db=linear_to_db(maxf(0.0001,_audio_gain))-12.0
	if muted or _audio_gain<=0.001: screen_audio.stop()
	elif audible_screen and not screen_audio.playing: screen_audio.play(fmod(sources[_audible_clip].video.stream_position,16.0 if _audible_clip=="reel" else 8.0))
	var closest:MeshInstance3D
	var drip_distance:=5.0
	if rooms.has(active_room):
		for puddle in rooms[active_room].puddles:
			var distance:float=main.player.global_position.distance_to(puddle.global_position)
			if distance<drip_distance: closest=puddle;drip_distance=distance
	if closest and not muted and drip_audio.stream:
		drip_audio.global_position=closest.global_position+Vector3.UP*0.2
		drip_audio.volume_db=linear_to_db(maxf(0.0001,proximity_gain(drip_distance)))-22.0
		if not drip_audio.playing:drip_audio.play()
	else:drip_audio.stop()

func contains_water(world_position:Vector3) -> bool:
	if not rooms.has(active_room):return false
	for puddle in rooms[active_room].puddles:
		var local:Vector3=puddle.to_local(world_position)
		var uv:Vector2=Vector2(local.x,local.z)/(puddle.mesh.size*0.5)
		if absf(local.y)<0.25 and uv.length()<0.90:return true
	return false

func _on_footstep(_left:bool,_surface:String,running:bool,position:Vector3) -> void:
	if reduced_motion or not contains_water(position):return
	var clock:float=get_node("/root/HyperAnimeWorldManager").visual_time
	_ripples[_ripple_cursor]=Vector4(position.x,position.z,clock,0.8 if running else 0.45)
	_ripple_cursor=(_ripple_cursor+1)%4
	for material in _water_materials:material.set_shader_parameter("ripples",_ripples)

func decoder_count() -> int:
	var count:=0
	for source in sources.values():
		if source.video.is_playing() and not source.video.paused:count+=1
	return count
