extends Node3D

## Local, editable presentation of the existing laboratory beats. This node
## never accepts a pact, ends a confrontation, grants power or records progress.
const Audio = preload("res://scripts/audio/procedural_cinematic_audio.gd")
var room: Node3D
var main: Node
var actor: Node3D
var stage := "dormant"
var active := false
var _zero: Node3D
var _zero_fallback: Node3D
var generated_zero: Node3D
const ZERO_PROFILE_PATH := "res://assets/characters/zero_manifestation_profile_v1.json"
var _rings: Array[MeshInstance3D] = []
var _splinters: Array[MeshInstance3D] = []
var _shards: Array[MeshInstance3D] = []
var _shadow_material: ShaderMaterial
var _vein_material: ShaderMaterial
var _splinter_positions: Array[Vector3] = []
var _suppressed_wing: Node3D
var _wing_was_visible := false
var _signal_material: StandardMaterial3D
var _elapsed := 0.0
var _duration := 0.0
var _kind := ""
var _camera: Camera3D
var _previous: Camera3D
var _overlay: CanvasLayer
var _skip: Button
var _sound: AudioStreamPlayer
var _impact := 0.0
var _phase := 0.0
var _return_elapsed := -1.0
var _return_pose := Transform3D.IDENTITY
var _return_fov := 48.0
var _start_pose := Transform3D.IDENTITY
var _end_pose := Transform3D.IDENTITY
var _owned_controls := false

func _ready() -> void:
	room = get_parent()
	_build_laboratory_details()
	_build_zero()
	_build_fracture_field()
	set_stage("dormant", true)

func _material(color: Color, emission := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.38
	mat.metallic = 0.45
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat

func _visual(label: String, mesh: Mesh, point: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = point
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

func _bar(label: String, point: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _visual(label, mesh, point, mat)

func _build_laboratory_details() -> void:
	var structure := _material(Color(0.08,0.12,0.17))
	var steel := _material(Color(0.29,0.35,0.42))
	var cyan := _material(Color(0.07,0.66,0.79), 0.8)
	_signal_material = _material(Color(0.66,0.08,0.22), 0.5)
	# Keep the authored collision and central player routes completely intact.
	# Repeated structural ribs, insets and warm circuit traces add depth to the
	# existing envelope; every new component is decorative and noncolliding.
	for z in [-6.0,-12.0,-18.0,-24.0,-30.0,-36.0]:
		for side in [-1.0,1.0]:
			_bar("WallRib", Vector3(side*15.7,4.4,z), Vector3(0.36,8.7,0.65), structure)
			_bar("WallInset", Vector3(side*15.48,3.8,z+2.0), Vector3(0.05,3.2,3.4), steel)
			_bar("InsetSignal", Vector3(side*15.43,4.2,z+2.0), Vector3(0.045,0.055,2.8), cyan)
			_bar("CeilingRib", Vector3(side*8.0,9.64,z), Vector3(15.6,0.25,0.38), structure)
	for side in [-1.0,1.0]:
		for z in [-10.0,-14.0,-18.0,-22.0,-26.0,-30.0,-34.0]:
			_bar("FloorSignal",Vector3(side*9.8,0.037,z),Vector3(0.05,0.018,2.6),cyan)
			_bar("FloorPanelSeam",Vector3(side*7.9,0.027,z),Vector3(6.0,0.014,0.045),structure)
		_bar("TheaterWarning",Vector3(side*5.85,1.215,-20.0),Vector3(0.065,0.02,10.8),_signal_material)
		for z in [-16.0,-24.0]:
			var capsule := CylinderMesh.new()
			capsule.top_radius = 0.31
			capsule.bottom_radius = 0.31
			capsule.height = 1.9
			_visual("ObservationColumn",capsule,Vector3(side*11.7,0.95,z),structure)
			var ring := TorusMesh.new()
			ring.inner_radius = 0.29
			ring.outer_radius = 0.35
			_visual("ColumnIndicator",ring,Vector3(side*11.7,1.53,z),cyan)
	# A medical instrument tray ties the later fracture feedback to the lab.
	for x in [-4.0,4.0]:
		_bar("InstrumentTray",Vector3(x,2.04,-20.7),Vector3(1.2,0.065,0.72),steel)
		for dx in [-0.42,0.42]:
			_bar("TraySupport",Vector3(x+dx,1.63,-20.7),Vector3(0.07,0.8,0.07),structure)
		for i in 4:
			_bar("Instrument",Vector3(x-0.36+i*0.23,2.095,-20.7),Vector3(0.045,0.025,0.42),steel)
	# The north wall must still read as an observation chamber behind Zero.
	# Large subdued panels and a thin seam keep the giant's silhouette legible.
	for x in [-11.5,-7.2,7.2,11.5]:
		_bar("NorthObservationInset",Vector3(x,4.0,-39.76),Vector3(3.7,5.8,0.04),steel)
		_bar("NorthObservationMullion",Vector3(x+2.0,4.0,-39.69),Vector3(0.12,6.3,0.14),structure)
		_bar("NorthReadout",Vector3(x,2.0,-39.69),Vector3(2.9,0.04,0.05),cyan)
	for x in [-6.0,6.0]:
		_bar("AltarFloorPath",Vector3(x,0.04,-33.0),Vector3(0.04,0.018,10.0),cyan)
	for data in [[Vector3(-5.0,4.4,-28.0),Color(0.7,0.81,1.0)],[Vector3(4.0,3.8,-30.0),Color(1.0,0.66,0.48)]]:
		var light:=OmniLight3D.new()
		light.name="StoryFill"
		light.position=data[0]
		light.light_color=data[1]
		light.light_energy=4.0
		light.omni_range=17.0
		light.omni_attenuation=0.7
		light.shadow_enabled=false
		add_child(light)

func _build_zero() -> void:
	_zero = Node3D.new()
	_zero.name = "ZeroShadowManifestation"
	_zero.position = Vector3(0,0.04,-35.5)
	add_child(_zero)
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled;
uniform float motion = 0.0;
uniform float phase = 0.0;
uniform float vein_layer = 0.0;
uniform float pact_energy = 0.0;
varying vec3 local_point;
float hash3(vec3 p) {
 return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);
}
float noise3(vec3 p) {
 vec3 cell=floor(p);
 vec3 f=fract(p); f=f*f*(3.0-2.0*f);
 float lower=mix(mix(hash3(cell),hash3(cell+vec3(1,0,0)),f.x),mix(hash3(cell+vec3(0,1,0)),hash3(cell+vec3(1,1,0)),f.x),f.y);
 float upper=mix(mix(hash3(cell+vec3(0,0,1)),hash3(cell+vec3(1,0,1)),f.x),mix(hash3(cell+vec3(0,1,1)),hash3(cell+vec3(1,1,1)),f.x),f.y);
 return mix(lower,upper,f.z);
}
void vertex() {
 local_point = VERTEX;
 float h = clamp(VERTEX.y / 6.2, 0.0, 1.0);
 float fringe = max(0.0,abs(VERTEX.x)-1.7);
 VERTEX.x += sin(VERTEX.y * 2.1 + phase * 0.7) * motion * (1.0-h) * 0.04;
 VERTEX.z += cos(VERTEX.y * 1.7 + phase * 0.55) * motion * (0.028+fringe*0.035);
}
void fragment() {
 float facing = pow(1.0 - abs(dot(normalize(NORMAL),normalize(VIEW))), 4.0);
 float broad=noise3(local_point*3.2);
 float grain=broad*0.72+noise3(local_point*37.0)*0.28;
 // The mantle is an incomplete network mass. Sparse opaque cutouts break
 // its surface and edges without transparent smoke or a translucent body.
 if (vein_layer<0.5 && local_point.y<5.08 && noise3(local_point*6.7)<0.23) discard;
 vec3 warped=local_point*8.0+vec3(broad*1.9,broad*0.7,broad*1.3);
 float fracture=1.0-smoothstep(0.015,0.085,abs(noise3(warped)-0.5));
 fracture*=smoothstep(0.61,0.82,noise3(local_point*1.8+4.1));
 vec3 ink=mix(vec3(0.030,0.036,0.052),vec3(0.059,0.062,0.088),grain);
 vec3 signal=mix(vec3(0.50,0.026,0.13),vec3(0.30,0.065,0.71),smoothstep(-1.6,0.4,local_point.x));
 ALBEDO=mix(ink,signal*0.3,vein_layer);
 METALLIC=0.10;
 ROUGHNESS=0.72+grain*0.16;
 float life = 0.94+0.06*sin(phase*0.7+local_point.y*1.9);
 EMISSION=ink*0.11+signal*facing*(0.20+broad*0.30)+signal*fracture*0.22;
 EMISSION+=signal*vein_layer*life*(0.85+pact_energy*0.18);
}"""
	_shadow_material = ShaderMaterial.new()
	_shadow_material.shader = shader
	_vein_material=_shadow_material.duplicate()
	_vein_material.set_shader_parameter("vein_layer",1.0)
	_zero_fallback=Node3D.new()
	_zero_fallback.name="TemporaryProceduralBody"
	_zero.add_child(_zero_fallback)
	preload("res://scripts/cinematics/zero_manifestation_geometry.gd").build(_zero_fallback,_shadow_material,_vein_material)
	generated_zero=preload("res://scripts/cinematics/zero_generated_model_slot.gd").new()
	generated_zero.name="GeneratedZeroModelSlot"
	_zero.add_child(generated_zero)
	if generated_zero.load_profile(ZERO_PROFILE_PATH): _zero_fallback.hide()
	# Local soft rims reveal the original thorn/limb weave against the lab.
	# These inherit the manifestation visibility: none exist before collapse.
	for data in [[Vector3(-3.0,4.1,-1.2),Color(0.55,0.64,0.73),1.75],[Vector3(2.7,2.7,-0.8),Color(0.65,0.50,0.46),1.35],[Vector3(0.0,4.8,3.5),Color(0.58,0.64,0.70),1.25]]:
		var rim:=OmniLight3D.new()
		rim.name="ManifestationSoftRim"
		rim.position=data[0]
		rim.light_color=data[1]
		rim.light_energy=data[2]
		rim.omni_range=8.0
		rim.omni_attenuation=1.4
		rim.shadow_enabled=false
		_zero.add_child(rim)
	var field:=Node3D.new()
	field.name="IndependentZeroNetworkField"
	_zero.add_child(field)
	preload("res://scripts/cinematics/zero_manifestation_geometry.gd").build_independent_field(field,_shadow_material,_vein_material)
	for i in 3:
		var torus := TorusMesh.new()
		torus.inner_radius = 1.75+i*0.4
		torus.outer_radius = torus.inner_radius+0.025
		var ring := _visual("CovenantRing",torus,Vector3(0,0.06+i*0.018,0),_material(Color(0.38,0.06,0.62),0.9),_zero)
		_rings.append(ring)
	# Angular shards break the silhouette without smoke transparency overdraw.
	for i in 32:
		var mesh := PrismMesh.new()
		mesh.size = Vector3(0.06+0.024*(i%3),0.12+0.038*(i%5),0.028)
		var a: float = i*TAU/32.0
		var shard := _visual("ShadowSplinter",mesh,Vector3(cos(a)*(2.3+0.17*(i%4)),0.5+0.36*(i%15),sin(a)*1.35),_vein_material,_zero)
		shard.rotation = Vector3(0.25*cos(a),a,0.25*sin(a))
		_splinters.append(shard)
		_splinter_positions.append(shard.position)

func _build_fracture_field() -> void:
	var mat := _material(Color(0.35,0.48,0.60),0.1)
	for i in 12:
		var mesh := PrismMesh.new()
		mesh.size = Vector3(0.22+0.04*(i%4),0.11,0.42)
		var angle: float = i*TAU/12.0
		var shard := _visual("LaboratoryFragment",mesh,Vector3(cos(angle)*2.8,0.08,-27.0+sin(angle)*2.3),mat)
		shard.rotation.y = angle
		shard.hide()
		_shards.append(shard)

func set_stage(value: String, restoring := false) -> void:
	stage = value
	if generated_zero: generated_zero.set_stage_hint(restoring)
	_zero.visible = value in ["manifested","accepted"]
	if _shadow_material: _shadow_material.set_shader_parameter("pact_energy",1.0 if value=="accepted" else 0.0)
	if _vein_material: _vein_material.set_shader_parameter("pact_energy",1.0 if value=="accepted" else 0.0)
	for shard in _shards: shard.visible = value in ["revenge","stasis"]
	if _signal_material:
		_signal_material.emission = Color(0.42,0.06,0.71) if value=="stasis" else Color(0.66,0.08,0.22)
	if not restoring and value=="accepted": _play_chime()
	if value=="stasis": _impact=0.0

func _play_chime() -> void:
	if room.audio_muted: return
	if not _sound:
		_sound = AudioStreamPlayer.new()
		_sound.name = "CovenantChime"
		_sound.volume_db = -20.0
		add_child(_sound)
	_sound.stream = Audio.create_covenant_chime()
	_sound.play()

func impact_feedback(contacts: int) -> void:
	if contacts<1 or contacts>3 or stage=="stasis": return
	_impact=0.0 if room.reduced_motion else 0.38
	for i in _shards.size():
		if i<contacts*4: _shards[i].show()

func begin(kind: String, owner: Node, subject: Node3D = null) -> void:
	finish(true)
	main=owner
	actor=subject
	_kind=kind
	# The existing wing is an oversized luminous combat prop. The dialogue
	# insert suppresses it visually and restores its prior visibility afterward;
	# its manifestation state, power and all attack contacts remain untouched.
	_suppressed_wing=main.player.find_child("ZeroShadowWing",true,false) as Node3D
	if _suppressed_wing and kind in ["accepted","revenge"]:
		_wing_was_visible=_suppressed_wing.visible
		_suppressed_wing.hide()
	_previous = get_viewport().get_camera_3d()
	if not _previous or main.reduced_motion:
		_restore_wing()
		return
	_camera=Camera3D.new()
	_camera.name="PactRevengeCamera"
	_camera.environment=_previous.environment
	_camera.fov=48.0
	_camera.near=0.06
	add_child(_camera)
	var point := Vector3.ZERO
	if kind=="manifested":
		_camera.global_position=room.to_global(Vector3(5.5,3.9,-26.0))
		point=room.to_global(Vector3(-1.8,3.35,-35.5))
		_duration=3.4
	elif kind=="accepted":
		# A measured two-character frame shows Zero's actual acknowledgement
		# and Echo's response together instead of putting Zero behind the lens.
		var toward: Vector3 = (_zero.global_position-main.player.global_position).normalized()
		toward.y=0.0
		toward=toward.normalized()
		var side: Vector3 = Vector3(toward.z,0,-toward.x)
		_camera.global_position=main.player.global_position-toward*3.8+side*4.6+Vector3.UP*3.2
		point=main.player.global_position.lerp(_zero.global_position,0.55)+Vector3.UP*2.75
		_duration=3.6
	else:
		if not is_instance_valid(actor):
			_camera.queue_free()
			_camera=null
			_restore_wing()
			return
		var center: Vector3=(actor.global_position+main.player.global_position)*0.5+Vector3.UP*1.05
		var toward: Vector3=(actor.global_position-main.player.global_position).normalized()
		var side: Vector3=Vector3(toward.z,0,-toward.x)
		_camera.global_position=center+side*3.5+Vector3.UP*0.65
		point=center+Vector3.UP*0.2
		_duration=4.0
	_camera.look_at(point)
	_start_pose=_camera.global_transform
	_end_pose=_start_pose
	_end_pose.origin+=(_camera.global_basis.z*-0.28)
	active=true
	_elapsed=0.0
	_return_elapsed=-1.0
	_owned_controls=kind=="accepted"
	if _owned_controls: main._on_opening_dialogue_started()
	_camera.make_current()
	_overlay=CanvasLayer.new()
	_overlay.layer=96
	add_child(_overlay)
	_skip=Button.new()
	_skip.name="ReturnToPlay"
	_skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_skip.offset_left=-205
	_skip.offset_right=-20
	_skip.offset_top=20
	_skip.offset_bottom=72
	_skip.pressed.connect(finish)
	_overlay.add_child(_skip)
	_skip.add_theme_font_override("font",preload("res://assets/fonts/NotoSansArabic.ttf"))
	_skip.text="عودة للمشهد" if main.presentation_language=="ar" else "Return to scene"

func _process(delta: float) -> void:
	if not room: return
	var still: bool=room.reduced_motion or stage=="stasis"
	if not still: _phase+=delta
	if generated_zero: generated_zero.tick(_phase,still,stage,delta)
	for mat in [_shadow_material,_vein_material]:
		if mat:
			mat.set_shader_parameter("motion",0.0 if still else 1.0)
			mat.set_shader_parameter("phase",_phase)
	for i in _splinters.size():
		_splinters[i].position=_splinter_positions[i] if still else _splinter_positions[i]+Vector3(0.015*sin(_phase*.42+i),0.06*sin(_phase*.65+i),0)
	if _sound and room.audio_muted: _sound.stop()
	_impact=maxf(0.0,_impact-delta)
	for i in _shards.size():
		_shards[i].position.y=0.08 if still else 0.08+sin(_phase*8.0+i)*_impact*0.12
	if not active: return
	if not is_instance_valid(main) or main.reduced_motion:
		finish(true)
		return
	_skip.text="عودة للمشهد" if main.presentation_language=="ar" else "Return to scene"
	_elapsed+=delta
	if _owned_controls: main.player.control_locked=true
	if _return_elapsed>=0.0:
		_return_elapsed+=delta
		if is_instance_valid(_previous):
			var weight := smoothstep(0.0,1.0,minf(_return_elapsed/0.35,1.0))
			_camera.global_transform=_return_pose.interpolate_with(_previous.global_transform,weight)
			_camera.fov=lerpf(_return_fov,_previous.fov,weight)
			_fit_return_camera()
		if _return_elapsed>=0.35: finish(true)
	else:
		_camera.global_transform=_start_pose.interpolate_with(_end_pose,smoothstep(0.0,1.0,minf(_elapsed/2.2,1.0)))
		if _elapsed>=_duration: finish()

func _unhandled_input(event: InputEvent) -> void:
	if active and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_SPACE:
		get_viewport().set_input_as_handled()
		finish()

func finish(immediate := false) -> void:
	if not active: return
	if not immediate and is_instance_valid(_camera) and is_instance_valid(_previous) and not room.reduced_motion:
		if _return_elapsed<0.0:
			_return_elapsed=0.0
			_return_pose=_camera.global_transform
			_return_fov=_camera.fov
			if _skip: _skip.hide()
		return
	active=false
	if is_instance_valid(_previous): _previous.make_current()
	if is_instance_valid(_camera): _camera.queue_free()
	if is_instance_valid(_overlay): _overlay.queue_free()
	_camera=null
	_overlay=null
	_restore_wing()
	# Re-evaluate the existing modal owner even for a shot behind a decision.
	# Other accessibility finish hooks may run first and release old ownership.
	if is_instance_valid(main) and not main.is_queued_for_deletion(): main._release_gameplay_modal_controls()
	_owned_controls=false

func _exit_tree() -> void:
	finish(true)

func _restore_wing() -> void:
	if is_instance_valid(_suppressed_wing) and _wing_was_visible: _suppressed_wing.show()
	_suppressed_wing=null
	_wing_was_visible=false

func _fit_return_camera() -> void:
	if not is_instance_valid(main.player) or not main.player.camera_boom: return
	var player: EchoPlayer=main.player
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=player.camera_boom.shape
	query.transform=Transform3D(Basis.IDENTITY,player.camera_boom.global_position)
	query.motion=_camera.global_position-query.transform.origin
	query.collision_mask=player.camera_boom.collision_mask
	query.exclude=[player.get_rid()]
	var fraction: float=player.get_world_3d().direct_space_state.cast_motion(query)[0]
	if fraction<1.0:
		_camera.global_position=query.transform.origin+query.motion.normalized()*maxf(0.0,query.motion.length()*fraction-player.camera_boom.margin)
