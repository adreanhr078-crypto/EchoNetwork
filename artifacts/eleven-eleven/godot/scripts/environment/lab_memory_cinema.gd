extends Node3D

## Whole, original Canon memory footage. No story flags or input ownership.
var laboratory:Node3D
var director:Node
var players:Array[VideoStreamPlayer]=[]
var panels:Array[Sprite3D]=[]
var frames:Array[MeshInstance3D]=[]
var posters:Array[Texture2D]=[]
const SCREEN_WIDTH_M:=2.624
var _desired_high:=true
var _loaded_high:Array[bool]=[]
var _variants:Array=[]

func configure(room:Node3D,trial:Node)->void:
	laboratory=room;director=trial
	var world:Node=get_node_or_null("/root/HyperAnimeWorldManager")
	_desired_high=not world or world.quality in ["high","ultra"]
	if world and not world.quality_changed.is_connected(_on_quality_changed):
		world.quality_changed.connect(_on_quality_changed)
	for i in 2:
		var viewport:=SubViewport.new()
		viewport.disable_3d=true;viewport.transparent_bg=false
		viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE
		add_child(viewport)
		var video:=VideoStreamPlayer.new()
		video.expand=true;video.volume_db= -80
		viewport.add_child(video)
		players.append(video)
		var label:="city" if i==0 else "friends"
		_variants.append([load("res://assets/cinematics/memory-screens/"+label+"-low.ogv"),load("res://assets/cinematics/memory-screens/"+label+"-high.ogv")])
		_loaded_high.append(not _desired_high)
		_set_stream_quality(i,_desired_high)
		video.finished.connect(_on_film_finished.bind(i))
		posters.append(load("res://assets/cinematics/memory-screens/"+("city-poster.webp" if i==0 else "friends-poster.webp")))
		var at:=Vector3(-7 if i==0 else 7,2.3,-19.62)
		var frame:=MeshInstance3D.new();frame.name="IntactMemoryScreenFrame"
		var box:=BoxMesh.new();box.size=Vector3(2.72,1.57,.08);frame.mesh=box
		var mat:=ShaderMaterial.new()
		mat.shader=preload("res://shaders/clinical_architecture_surface.gdshader")
		mat.resource_name="ClinicalMemoryScreenCasing"
		mat.set_shader_parameter("base_color",Color(.44,.49,.55))
		mat.set_shader_parameter("metalness",.35)
		mat.set_shader_parameter("surface_roughness",.48)
		mat.set_shader_parameter("minimum_roughness",.40)
		mat.set_shader_parameter("ceramic_finish",false)
		mat.set_shader_parameter("finish_grain",preload("res://assets/environments/maintenance_jutsu_v1_Maintenance ceramic grain 512.png"))
		frame.material_override=mat;frame.position=at-Vector3(0,0,.07)
		add_child(frame);frames.append(frame)
		# A physical rear casing reads from the reverse route without showing
		# a reversed film or replacing the original whole front picture.
		var rear:=MeshInstance3D.new();rear.name="MemoryScreenRearCasing"
		var rear_mesh:=BoxMesh.new();rear_mesh.size=Vector3(2.48,1.32,.014)
		rear.mesh=rear_mesh;rear.position=Vector3(0,0,-.051)
		rear.material_override=mat;frame.add_child(rear)
		var vent_material:=StandardMaterial3D.new()
		vent_material.albedo_color=Color(.055,.075,.105);vent_material.roughness=.6
		var vent_mesh:=BoxMesh.new();vent_mesh.size=Vector3(2.12,.025,.008)
		var vents:=MultiMesh.new();vents.transform_format=MultiMesh.TRANSFORM_3D
		vents.mesh=vent_mesh;vents.instance_count=5
		for row in 5:vents.set_instance_transform(row,Transform3D(Basis.IDENTITY,Vector3(0,-.36+.18*row,-.063)))
		var vent_draw:=MultiMeshInstance3D.new();vent_draw.name="MemoryScreenRearVents"
		vent_draw.multimesh=vents;vent_draw.material_override=vent_material;frame.add_child(vent_draw)
		var panel:=Sprite3D.new();panel.name="WholeMovingMemory"
		panel.texture=viewport.get_texture();panel.pixel_size=SCREEN_WIDTH_M/viewport.size.x
		panel.shaded=false;panel.position=at;panel.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(panel);panels.append(panel)
		frame.hide();panel.hide()

func _live()->bool:
	return is_instance_valid(director) and (director.phase in ["memories","refusal","abyss"] or laboratory.confrontation_done)

func _set_stream_quality(index:int,high:bool)->void:
	if _loaded_high[index]==high:return
	var video:VideoStreamPlayer=players[index]
	var viewport:SubViewport=video.get_parent()
	# Only called before playback, after stop or at the natural loop end.
	# Theora has no reliable arbitrary seek; do not restart an active film
	# just because the player changes a graphics preference while paused.
	video.stream=_variants[index][1 if high else 0]
	viewport.size=Vector2i(1280,720) if high else Vector2i(512,288)
	video.size=Vector2(viewport.size)
	if index<panels.size():
		# finished can fire after this node's process callback. Resize the
		# sprite in the same transaction as its viewport, before rendering.
		panels[index].pixel_size=SCREEN_WIDTH_M/maxi(1,panels[index].texture.get_width())
	_loaded_high[index]=high

func _on_quality_changed(tier:String)->void:
	_desired_high=tier in ["high","ultra"]
	for index in players.size():
		if not players[index].is_playing():_set_stream_quality(index,_desired_high)

func _on_film_finished(index:int)->void:
	if _live() and not laboratory.reduced_motion:
		_set_stream_quality(index,_desired_high)
		players[index].play()

func _process(_delta:float)->void:
	if not is_instance_valid(laboratory) or not is_instance_valid(director):return
	var p:Vector3=laboratory.to_local(laboratory.player.global_position) if is_instance_valid(laboratory.player) else Vector3(999,999,999)
	var visible_now:bool=_live() and absf(p.x)<17 and p.z<1 and p.z> -41
	for i in players.size():
		panels[i].visible=visible_now;frames[i].visible=visible_now
		var video:=players[i]
		if visible_now:
			if not video.is_playing() and not laboratory.reduced_motion:
				_set_stream_quality(i,_desired_high)
				video.play()
			panels[i].texture=posters[i] if laboratory.reduced_motion else video.get_parent().get_texture()
			panels[i].pixel_size=SCREEN_WIDTH_M/maxi(1,panels[i].texture.get_width())
			video.paused=laboratory.reduced_motion
		elif video.is_playing():video.stop()
