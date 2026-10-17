extends Node3D
## Room08 presentation. No colliders, triggers, durable flags, rewards or actor edits.
const ENV_LAYER := 1 << 18
const MIRROR_LAYER := 1 << 19
var room: Node3D
var local_time := 0.0
var inspection_age := 10.0
var inspection_count := 0
var override_count := 0
var _record: MeshInstance3D
var _caption: Label3D
var _beacon: StandardMaterial3D
var _network: ShaderMaterial
var _beam: ShaderMaterial
var _glint: ShaderMaterial
var _glint_surface: MeshInstance3D
var _motes: Node3D
var _inspect_sound: AudioStreamPlayer3D
var _override_sound: AudioStreamPlayer3D
var _gate_sound: AudioStreamPlayer3D

func _ready() -> void:
	room = get_parent()
	_network = ShaderMaterial.new()
	_network.shader = preload("res://shaders/surveillance_network.gdshader")
	room.get_node("MonitorWallScreens").get_child(0).material_override = _network
	_beam = ShaderMaterial.new()
	_beam.shader = preload("res://shaders/surveillance_beam.gdshader")
	for beam in room._laser_beams:
		beam.material_override = _beam
		beam.mesh.radial_segments = 12
		beam.mesh.top_radius = 0.055
		beam.mesh.bottom_radius = 0.055
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon = _ink(Color(0.9,0.12,0.07))
	_build_emitters()
	_build_mirror_record()
	_motes = preload("res://scripts/environment/room_motes.gd").new()
	_motes.name = "SurveillanceAir"
	_motes.anchors.assign([Vector3(7,2,-10),Vector3(0,3.5,-18)])
	_motes.particles_per_anchor = 18
	_motes.tint = Color(.62,.52,.85,.24)
	room.add_child(_motes)
	_inspect_sound = _sound("GlassInspection",Vector3(8.2,1.6,-10),ProceduralCinematicAudio.create_physical_signal(.28,[.015],111108,.25),-12)
	_override_sound = _sound("OverrideLatch",Vector3(0,3,-18),ProceduralCinematicAudio.create_physical_signal(.3,[.01],111118,.35),-9)
	_gate_sound = _sound("GatePressure",Vector3(0,1.8,-35.8),ProceduralCinematicAudio.create_pressure_air(.6,111128),-12)
	# Only room meshes receive this fill; never OR another visible layer into
	# ActualReflection, which must remain excluded from its own virtual camera.
	for mesh in room.find_children("*","MeshInstance3D",true,false):
		if not (mesh.layers & MIRROR_LAYER): mesh.layers |= ENV_LAYER
	for mesh in room.find_children("*","MultiMeshInstance3D",true,false): mesh.layers |= ENV_LAYER
	var fill := OmniLight3D.new()
	fill.name = "EnvironmentOnlyDaisFill"
	fill.position = Vector3(0,1.5,-18)
	fill.light_color = Color(.49,.61,.78)
	fill.light_energy = .5
	fill.omni_range = 19
	fill.light_cull_mask = ENV_LAYER
	fill.shadow_enabled = false
	add_child(fill)
	refresh()
	sync_accessibility()

func _ink(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	return mat

func _batch(label: String,mesh: Mesh,material: Material,points: Array[Vector3]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = points.size()
	for i in points.size(): mm.set_instance_transform(i,Transform3D(Basis.IDENTITY,points[i]))
	var batch := MultiMeshInstance3D.new()
	batch.name = label
	batch.multimesh = mm
	batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)

func _build_emitters() -> void:
	var points: Array[Vector3] = []
	var caps: Array[Vector3] = []
	for z in [-8.0,-12.0,-26.0,-30.0]:
		for x in [-7.05,7.05]:
			points.append(Vector3(x,1.2,z))
			caps.append(Vector3(x+(0.1 if x<0 else -0.1),1.2,z))
	var housing := BoxMesh.new()
	housing.size = Vector3(.18,.3,.24)
	_batch("EightOpticalEmitters",housing,preload("res://scripts/environment/room_panel_finish.gd").material(Color(.38,.43,.5),Vector2(.3,.4),.25,.57),points)
	var cap := BoxMesh.new()
	cap.size = Vector3(.012,.13,.12)
	_batch("EmitterStatus",cap,_beacon,caps)
	var support := BoxMesh.new()
	support.size = Vector3(.18,2.1,.18)
	var columns: Array[Vector3] = [Vector3(-3.6,1.05,-21.6),Vector3(3.6,1.05,-21.6),Vector3(-3.6,1.05,-14.4),Vector3(3.6,1.05,-14.4)]
	_batch("DaisVisualSupports",support,preload("res://scripts/environment/room_panel_finish.gd").material(Color(.24,.3,.38)),columns)

func _quad(label: String,size: Vector2,point: Vector3,mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = QuadMesh.new()
	mesh.mesh.size = size
	mesh.position = point
	mesh.rotation.y = -PI/2
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	return mesh

func _build_mirror_record() -> void:
	_glint = ShaderMaterial.new()
	_glint.shader = preload("res://shaders/mirror_inspection_glint.gdshader")
	_glint_surface = _quad("InspectionRim",Vector2(4,2.8),Vector3(8.318,1.6,-10),_glint)
	# The overlay belongs to the physical glass, never the virtual reflection.
	_glint_surface.layers = MIRROR_LAYER
	_quad("RecordMount",Vector2(1.25,1.65),Vector3(8.34,1.65,-13.0),_ink(Color(.035,.043,.058)))
	var portrait := ShaderMaterial.new()
	portrait.shader = preload("res://shaders/mirror_canon_record.gdshader")
	portrait.set_shader_parameter("approved_page",preload("res://assets/canon/mirror-page009-approved.webp"))
	_record = _quad("ApprovedMirrorMemory",Vector2(1.05,1.174),Vector3(8.32,1.82,-13.0),portrait)
	var bracket := BoxMesh.new()
	bracket.size = Vector3(.1,.08,.6)
	var attachments: Array[Vector3] = [Vector3(8.45,1.2,-12.3),Vector3(8.45,2.1,-12.3)]
	_batch("RecordFrameAttachments",bracket,preload("res://scripts/environment/room_panel_finish.gd").material(Color(.24,.3,.38)),attachments)
	_caption = Label3D.new()
	_caption.name = "MirrorQuestion"
	_caption.font = preload("res://assets/fonts/NotoSansArabic.ttf")
	_caption.position = Vector3(8.30,.67,-13.0)
	_caption.rotation.y = -PI/2
	_caption.font_size = 32
	_caption.pixel_size = .0025
	_caption.outline_size = 5
	_caption.modulate = Color(.77,.69,.88)
	add_child(_caption)

func refresh() -> void:
	if not _network: return
	_network.set_shader_parameter("authority",Vector3(float(room.mirror_inspected),float(room.override_done),float(room.gate_open)))
	_record.visible = room.mirror_inspected
	_beacon.albedo_color = Color(.13,.65,.43) if room.override_done else Color(.9,.12,.07)
	_caption.text = ("ملامح أكبر…\nهل أنت أنا؟" if room.mirror_inspected else "اقترب من الزجاج") if room.presentation_language=="ar" else ("Older features...\nAre you me?" if room.mirror_inspected else "Approach the glass")

func inspect() -> void:
	inspection_count += 1
	inspection_age = 10.0 if room.reduced_motion else 0.0
	if not room.audio_muted: _inspect_sound.play()
	refresh()

func override_activated() -> void:
	override_count += 1
	if not room.audio_muted: _override_sound.play()
	refresh()

func gate_released() -> void:
	if not room.audio_muted: _gate_sound.play()
	_motes.emit_release(Vector3(0,1.8,-35.7))
	refresh()

func restore_silently() -> void:
	inspection_age = 10.0
	_glint.set_shader_parameter("age",inspection_age)
	_glint_surface.visible = false
	_motes._release.visible = false
	stop_audio()
	refresh()

func sync_accessibility() -> void:
	if _motes and is_instance_valid(_motes._air):
		_motes._air.visible = not room.reduced_motion
	if room.reduced_motion:
		inspection_age = 10.0
		if _glint: _glint.set_shader_parameter("age",10.0)
		if _glint_surface: _glint_surface.visible = false
		if _motes:
			_motes._air.visible = false
			_motes._release.visible = false
	if room.audio_muted: stop_audio()

func _process(delta: float) -> void:
	if not room.reduced_motion:
		local_time += minf(delta,.1)
		inspection_age += minf(delta,.1)
	_network.set_shader_parameter("local_time",local_time)
	_beam.set_shader_parameter("local_time",local_time)
	_glint.set_shader_parameter("age",inspection_age)
	_glint_surface.visible = not room.reduced_motion and inspection_age<1.3

func stop_audio() -> void:
	for sound in [_inspect_sound,_override_sound,_gate_sound]:
		if is_instance_valid(sound): sound.stop()

func _sound(label: String,point: Vector3,stream: AudioStream,volume: float) -> AudioStreamPlayer3D:
	var sound := AudioStreamPlayer3D.new()
	sound.name = label
	sound.position = point
	sound.stream = stream
	sound.volume_db = volume
	sound.max_distance = 20
	add_child(sound)
	return sound
