extends Node3D

## Local, editable presentation of the existing laboratory beats. This node
## never accepts a pact, ends a confrontation, grants power or records progress.
const PactAudio = preload("res://scripts/audio/pact_audio_director.gd")
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
var _suppressed_actor: Node3D
var _actor_was_visible := false
var _signal_material: StandardMaterial3D
var _elapsed := 0.0
var _duration := 0.0
var _kind := ""
var _camera: Camera3D
var _previous: Camera3D
var _overlay: CanvasLayer
var _skip: Button
var audio_director: Node
var _impact := 0.0
var _phase := 0.0
var _return_elapsed := -1.0
var _return_pose := Transform3D.IDENTITY
var _return_fov := 48.0
var _start_pose := Transform3D.IDENTITY
var _end_pose := Transform3D.IDENTITY
var _owned_controls := false
var _quiet_hud: Array[Dictionary] = []
var _clearance_settle_remaining:=0.0
var _clearance_orbit:=Vector3.ZERO
var _clearance_origin:=Vector3.ZERO
var _last_reduced_motion:=false

func _ready() -> void:
	room = get_parent()
	audio_director=PactAudio.new()
	audio_director.name="PactAudioDirector"
	add_child(audio_director)
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
	if restoring and value not in ["revenge","stasis"]:_clearance_settle_remaining=0.0
	if generated_zero: generated_zero.set_stage_hint(restoring)
	_zero.visible = value in ["manifested","accepted"]
	if _shadow_material: _shadow_material.set_shader_parameter("pact_energy",1.0 if value=="accepted" else 0.0)
	if _vein_material: _vein_material.set_shader_parameter("pact_energy",1.0 if value=="accepted" else 0.0)
	for shard in _shards: shard.visible = value in ["revenge","stasis"]
	if _signal_material:
		_signal_material.emission = Color(0.42,0.06,0.71) if value=="stasis" else Color(0.66,0.08,0.22)
	_sync_audio_preferences()
	if audio_director: audio_director.set_stage(value,restoring,bool(room.get("contract_done")))
	if value=="stasis": _impact=0.0

func _sync_audio_preferences() -> void:
	if not audio_director or not room: return
	var deciding:=false
	if is_instance_valid(main) and main.get("hud"):
		var decision: Control=main.hud.find_child("SystemWindow",true,false)
		deciding=is_instance_valid(decision) and decision.visible and bool(decision.get("_modal"))
	audio_director.sync_preferences(bool(room.get("audio_muted")),1.0,deciding)

func impact_feedback(contacts: int) -> void:
	if contacts<1 or contacts>3 or stage=="stasis": return
	_sync_audio_preferences()
	if audio_director: audio_director.contact_confirmed(contacts,bool(room.get("contract_done")))
	_impact=0.0 if room.reduced_motion else 0.38
	for i in _shards.size():
		if i<contacts*4: _shards[i].show()

func begin(kind: String, owner: Node, subject: Node3D = null) -> void:
	finish(true)
	_clearance_settle_remaining=0.0
	main=owner
	actor=subject
	_kind=kind
	# A bounded, socket-validated feather rig belongs in Echo's pact portrait.
	# Keep the prior suppression only for a legacy wing lacking that guarantee;
	# neither branch changes manifestation state or contract authority.
	_suppressed_wing=main.player.find_child("ZeroShadowWing",true,false) as Node3D
	var supports_framing: bool=is_instance_valid(_suppressed_wing) and _suppressed_wing.has_method("supports_cinematic_framing") and bool(_suppressed_wing.call("supports_cinematic_framing"))
	if _suppressed_wing and not supports_framing and kind in ["accepted","revenge"]:
		_wing_was_visible=_suppressed_wing.visible
		_suppressed_wing.hide()
	else:
		_suppressed_wing=null
	# Zero's accepted acknowledgement is an encounter with Echo. Keep the
	# live revenge actor out of this picture until control returns to the lab.
	if kind=="accepted" and is_instance_valid(actor):
		_suppressed_actor=actor
		_actor_was_visible=actor.visible
		actor.hide()
	_previous = get_viewport().get_camera_3d()
	if not _previous or main.reduced_motion:
		_restore_wing()
		_restore_actor()
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
		point=main.player.global_position.lerp(_zero.global_position,0.55)+Vector3.UP*2.18
		_duration=3.6
		if generated_zero.source_player and generated_zero.source_player.has_animation("pact/agree"):
			_duration=maxf(_duration,generated_zero.source_player.get_animation("pact/agree").length+0.35)
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
	if kind=="revenge":
		# A local camera fill reveals the two faces without bleaching the
		# laboratory. It exists only while this optional insert owns the camera.
		var face_fill:=OmniLight3D.new()
		face_fill.name="DialogueFaceFill"
		face_fill.light_color=Color(0.75,0.70,0.77)
		face_fill.light_energy=1.75
		face_fill.omni_range=6.0
		face_fill.omni_attenuation=0.65
		face_fill.shadow_enabled=false
		_camera.add_child(face_fill)
	_start_pose=_camera.global_transform
	_end_pose=_start_pose
	_end_pose.origin+=(_camera.global_basis.z*-0.28)
	active=true
	_elapsed=0.0
	_return_elapsed=-1.0
	_owned_controls=kind=="accepted"
	if _owned_controls: main._on_opening_dialogue_started()
	_camera.make_current()
	_quiet_story_hud()
	_overlay=CanvasLayer.new()
	_overlay.layer=96
	add_child(_overlay)
	_skip=Button.new()
	_skip.name="ReturnToPlay"
	_skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip.offset_left=-225
	_skip.offset_right=-20
	_skip.offset_top=-84
	_skip.offset_bottom=-24
	_skip.pressed.connect(finish)
	_overlay.add_child(_skip)
	_skip.add_theme_font_override("font",preload("res://assets/fonts/NotoSansArabic.ttf"))
	_skip.text="عودة للمشهد" if main.presentation_language=="ar" else "Return to scene"

func _process(delta: float) -> void:
	if is_instance_valid(room):
		var reduced:bool=room.reduced_motion
		if reduced!=_last_reduced_motion:
			_last_reduced_motion=reduced
			# Accessibility changes the shoulder origin after a natural return.
			# Recheck this encounter's handoff without controlling manual look.
			if not active and _kind=="revenge" and stage in ["revenge","stasis"] and is_instance_valid(main):
				_clearance_origin=main.player.camera_target_rotation
				_clearance_orbit=_clearance_origin
				_clearance_settle_remaining=.4
	_settle_return_clearance(delta)
	if not room: return
	_sync_audio_preferences()
	if active: _hold_story_hud_quiet()
	var still: bool=room.reduced_motion or stage=="stasis"
	if not still: _phase+=delta
	if generated_zero: generated_zero.tick(_phase,still,stage,delta)
	for mat in [_shadow_material,_vein_material]:
		if mat:
			mat.set_shader_parameter("motion",0.0 if still else 1.0)
			mat.set_shader_parameter("phase",_phase)
	for i in _splinters.size():
		_splinters[i].position=_splinter_positions[i] if still else _splinter_positions[i]+Vector3(0.015*sin(_phase*.42+i),0.06*sin(_phase*.65+i),0)
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
	if _kind=="revenge" and is_instance_valid(main) and _return_elapsed<0.0 and _clearance_settle_remaining<=0.0:
		_clearance_origin=main.player.camera_target_rotation
	_ensure_gameplay_return_clearance()
	# Returning from a camera insert never cancels the story-owned stage or
	# its ambience. Only a still-playing transient belongs to this return.
	if audio_director: audio_director.stop_transients()
	if not immediate and is_instance_valid(_camera) and is_instance_valid(_previous) and not room.reduced_motion:
		if _return_elapsed<0.0:
			_return_elapsed=0.0
			_return_pose=_camera.global_transform
			_return_fov=_camera.fov
			if _skip: _skip.hide()
		return
	active=false
	if is_instance_valid(_previous): _previous.make_current()
	if _kind=="revenge" and is_instance_valid(main):
		_clearance_settle_remaining=.4
		_clearance_orbit=main.player.camera_target_rotation
	if is_instance_valid(_camera): _camera.queue_free()
	if is_instance_valid(_overlay): _overlay.queue_free()
	_camera=null
	_overlay=null
	_restore_wing()
	_restore_actor()
	_restore_story_hud()
	# Re-evaluate the existing modal owner even for a shot behind a decision.
	# Other accessibility finish hooks may run first and release old ownership.
	if is_instance_valid(main) and not main.is_queued_for_deletion(): main._release_gameplay_modal_controls()
	_owned_controls=false

func _exit_tree() -> void:
	finish(true)
	if audio_director: audio_director.cancel()

func _restore_wing() -> void:
	if is_instance_valid(_suppressed_wing) and _wing_was_visible: _suppressed_wing.show()
	_suppressed_wing=null
	_wing_was_visible=false

func _restore_actor() -> void:
	if is_instance_valid(_suppressed_actor): _suppressed_actor.visible=_actor_was_visible
	_suppressed_actor=null
	_actor_was_visible=false

func _quiet_story_hud() -> void:
	# Preserve gameplay-owned visibility and choices. Only passive readouts
	# fade from the picture; pause, consent and the return control stay usable.
	for label in ["CompassRadarBar","QuestContainer","ComboContainer","InteractionPromptHUD","TutorialToastSystem"]:
		var item:=main.hud.find_child(label,true,false) as CanvasItem
		if not item: continue
		_quiet_hud.append({"node":item,"alpha":item.modulate.a,"visible":item.visible})
		if label=="TutorialToastSystem": _quiet_hud[-1]["toast_id"]=String(item.get("active_toast_id"))
		item.modulate.a=0.0
		# Gameplay colour tweens run after _process and can restore alpha in
		# the same frame. Visibility keeps those updates out of the shot.
		item.hide()

func _restore_story_hud() -> void:
	for saved in _quiet_hud:
		if is_instance_valid(saved.node):
			saved.node.modulate.a=saved.alpha
			saved.node.visible=saved.visible
			if saved.has("toast_id") and String(saved.node.get("active_toast_id"))!=saved.toast_id:
				# A timed hint may have expired while this shot was active.
				# Restoring the snapshot must not revive its old text.
				saved.node.hide()
	_quiet_hud.clear()

func _hold_story_hud_quiet() -> void:
	# The campaign refreshes objective colours when its stage changes. Hold
	# only the saved passive alphas while the shot owns presentation, so a
	# same-frame gameplay refresh cannot put a readout back over the actors.
	for saved in _quiet_hud:
		if is_instance_valid(saved.node):
			saved.node.modulate.a=0.0
			saved.node.hide()

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

func _return_clearance(player:EchoPlayer, rotation:Vector3, settled_shoulder:=false) -> float:
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=player.camera_boom.shape
	query.collision_mask=player.camera_boom.collision_mask
	query.exclude=[player.get_rid()]
	var basis:Basis=(player.global_basis*Basis.from_euler(rotation)).orthonormalized()
	query.transform=Transform3D(basis,player.camera_boom.global_position)
	if settled_shoulder:
		# The current shoulder is still easing after a yaw/accessibility change.
		# Qualify the final origin too, so a clear present sample cannot choose
		# an orbit that will become obstructed as that existing easing completes.
		var anchor:=Vector3(player.global_position.x,player.camera_boom.global_position.y,player.global_position.z)
		var shoulder:=Vector3.ZERO if player.reduced_camera_motion else basis.x*.22
		shoulder.y=0.0
		query.transform=Transform3D(Basis.IDENTITY,anchor)
		query.motion=shoulder
		shoulder*=player.get_world_3d().direct_space_state.cast_motion(query)[0]
		query.transform=Transform3D(basis,anchor+shoulder)
	query.motion=basis.z*3.0
	var space:=player.get_world_3d().direct_space_state
	if not space.intersect_shape(query,1).is_empty():return 0.0
	var fraction:float=space.cast_motion(query)[0]
	return maxf(0.0,fraction*3.0-(player.camera_boom.margin if fraction<1.0 else 0.0))

func _handoff_clearance(player:EchoPlayer, rotation:Vector3) -> float:
	return minf(_return_clearance(player,rotation),_return_clearance(player,rotation,true))

func _ensure_gameplay_return_clearance() -> void:
	# A close confrontation can leave the old orbit against the other actor,
	# retracting the gameplay lens into Echo. Resolve only this encounter's
	# return; preserve a clear orbit and every world/actor collision mask.
	if _kind!="revenge" or not is_instance_valid(main):return
	var player:EchoPlayer=main.player
	if not is_instance_valid(player) or _previous!=player.player_camera or not player.camera_boom:return
	player.force_update_transform()
	player.camera_boom.force_update_transform()
	if is_instance_valid(actor):actor.force_update_transform()
	var preferred:Vector3=player.camera_target_rotation
	if _handoff_clearance(player,preferred)>=1.0:return
	for degrees in [15.0,30.0,45.0,60.0,75.0,90.0]:
		var best:Vector3=preferred
		var best_clearance:=0.0
		for side in [-1.0,1.0]:
			var candidate:=Vector3(preferred.x,preferred.y+deg_to_rad(degrees)*side,0)
			if absf(angle_difference(_clearance_origin.y,candidate.y))>PI/2+.001:continue
			var clearance:=_handoff_clearance(player,candidate)
			if clearance>best_clearance:
				best=candidate
				best_clearance=clearance
		if best_clearance>=1.0:
			player.set_gameplay_orbit(best)
			player._update_camera_distance(1.0)
			return

func _settle_return_clearance(delta:float) -> void:
	if _clearance_settle_remaining<=0.0 or active:return
	_clearance_settle_remaining=maxf(0.0,_clearance_settle_remaining-delta)
	if not is_instance_valid(main) or not is_instance_valid(main.player):
		_clearance_settle_remaining=0.0
		return
	var player:EchoPlayer=main.player
	# Stop immediately on a deliberate look or another cinematic owner. This
	# short handoff window covers the next physics samples, not live orbit input.
	if not player.camera_target_rotation.is_equal_approx(_clearance_orbit) or not player.player_camera.current:
		_clearance_settle_remaining=0.0
		return
	_ensure_gameplay_return_clearance()
	_clearance_orbit=player.camera_target_rotation
