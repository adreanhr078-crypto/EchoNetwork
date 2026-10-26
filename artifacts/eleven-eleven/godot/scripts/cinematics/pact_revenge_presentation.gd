extends Node3D

signal encounter_changed
signal encounter_choice_requested(choice: String)
signal encounter_completed

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
var encounter_started := false
var encounter_live := false
var _encounter_power_staged := false
var contract_cinematic_shot:="mark"
var _contract_camera_shape:SphereShape3D
var encounter_step := 0
var encounter_questions := 0
var encounter_deferred := false
var encounter_answer := -1
var encounter_look := Vector2.ZERO
var _encounter_generation := 0
var _encounter_window_generation := -1
var _encounter_language := ""
var _encounter_layer: CanvasLayer
var _encounter_skip: Button
var _encounter_power: Button
var _encounter_look_hint: Label
var _encounter_base := Transform3D.IDENTITY
var _encounter_model_visible := true
var _encounter_model_hidden := false
var _encounter_mark: Node3D
var _encounter_power_observed := false
var _encounter_power_elapsed := 0.0
var _encounter_save_failed := false

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
	var architecture:=preload("res://scripts/environment/clinical_lab_architecture.gd").new()
	architecture.name="ClinicalLabArchitecture"
	add_child(architecture)
	architecture.build(room)
	# Existing story state still owns these warning colors and animations.
	_signal_material=_material(Color(.66,.08,.22),.5)

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
	if encounter_live:
		_tick_encounter(delta)
		return
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

func restore_presentation_clock(value: float) -> void:
	# A cursor can resume framing only. Gameplay flags and choice callbacks
	# remain owned by the room/campaign, never by elapsed presentation time.
	if active and is_finite(value):
		_elapsed = clampf(value, 0.0, _duration)

func finish(immediate := false) -> void:
	if encounter_started: _cancel_encounter()
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

func _ensure_gameplay_return_clearance(combat_action:=false) -> void:
	# A close confrontation can leave the old orbit against the other actor,
	# retracting the gameplay lens into Echo. Resolve only this encounter's
	# return; preserve a clear orbit and every world/actor collision mask.
	if (not combat_action and _kind!="revenge") or not is_instance_valid(main):return
	var player:EchoPlayer=main.player
	if not is_instance_valid(player) or (not combat_action and _previous!=player.player_camera) or not player.camera_boom:return
	if combat_action and (get_tree().paused or player.control_locked or not player.player_camera.current or player._camera_suspended or player._camera_look_cooldown>0.0):return
	player.force_update_transform()
	player.camera_boom.force_update_transform()
	if is_instance_valid(actor):actor.force_update_transform()
	var preferred:Vector3=player.camera_target_rotation
	if _handoff_clearance(player,preferred)>=1.0:return
	var fallback:=preferred
	var fallback_clearance:=0.0
	var readable_length:=2.4 if combat_action else 1.0
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
		if best_clearance>fallback_clearance:
			fallback=best
			fallback_clearance=best_clearance
		if best_clearance>=readable_length:
			player.set_gameplay_orbit(best)
			player._update_camera_distance(1.0)
			return
	# A genuinely tight space retains the widest measured safe fallback;
	# normal confrontation space should show both bodies rather than stop at
	# the first one-metre ray that barely clears the other actor's capsule.
	if combat_action and fallback_clearance>=1.0:
		player.set_gameplay_orbit(fallback)
		player._update_camera_distance(1.0)

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

func encounter_snapshot() -> Dictionary:
	if not encounter_started: return {}
	return {"step": encounter_step, "questions": encounter_questions, "deferred": encounter_deferred, "look": [encounter_look.x, encounter_look.y], "answer": encounter_answer}

func awaits_encounter_consent() -> bool:
	return encounter_live and encounter_step == 5 and encounter_questions == 7 and not room.contract_done

func retain_encounter_consent() -> void:
	if not awaits_encounter_consent(): return
	_encounter_save_failed = true
	_refresh_encounter_window()

func begin_encounter(owner: Node, cursor: Dictionary = {}, restoring := false) -> void:
	if encounter_live:
		_refresh_encounter_window()
		return
	if not encounter_started:
		finish(true)
		_encounter_power_staged = false
		main = owner
		encounter_started = true
		encounter_step = 6 if room.contract_done else 0
		encounter_questions = 7 if room.contract_done else 0
		encounter_deferred = false
		encounter_answer = -1
		encounter_look = Vector2.ZERO
		if preload("res://scripts/systems/native_campaign_checkpoint.gd").valid_encounter_cursor(cursor, room.contract_done):
			encounter_step = int(cursor.step)
			encounter_questions = int(cursor.questions)
			encounter_deferred = cursor.deferred
			encounter_look = Vector2(cursor.look[0], cursor.look[1])
			encounter_answer = int(cursor.get("answer", -1))
		_encounter_model_visible = main.player.get_node("ModelRoot").visible
		if not main.player.combat_action_started.is_connected(_observe_encounter_power): main.player.combat_action_started.connect(_observe_encounter_power)
	if encounter_step == 8:
		_apply_encounter_stage(true)
		return
	if restoring and encounter_deferred:
		_apply_encounter_stage(true)
		return
	encounter_deferred = false
	encounter_live = true
	_encounter_power_observed = false
	_encounter_power_elapsed = 0
	_encounter_generation += 1
	_previous = get_viewport().get_camera_3d()
	_camera = Camera3D.new()
	_camera.name = "ZeroEncounterCamera"
	_camera.near = .035
	if is_instance_valid(_previous): _camera.environment = _previous.environment
	add_child(_camera)
	_encounter_layer = CanvasLayer.new()
	_encounter_layer.layer = 96
	add_child(_encounter_layer)
	_encounter_skip = _encounter_button("SkipEncounterPresentation", _skip_encounter)
	_encounter_power = _encounter_button("TryPactPower", Callable())
	_encounter_power.button_down.connect(_begin_encounter_power)
	_encounter_power.button_up.connect(_release_encounter_power)
	_encounter_look_hint = Label.new()
	_encounter_look_hint.name = "EncounterLookHint"
	_encounter_look_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_encounter_look_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_encounter_look_hint.offset_left = 24
	_encounter_look_hint.offset_right = -24
	_encounter_look_hint.offset_top = 84
	_encounter_look_hint.offset_bottom = 132
	_encounter_look_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_encounter_look_hint.add_theme_font_override("font", preload("res://assets/fonts/NotoSansArabic.ttf"))
	_encounter_look_hint.add_theme_font_size_override("font_size", 24)
	_encounter_layer.add_child(_encounter_look_hint)
	_elapsed = 0
	_quiet_story_hud()
	_apply_encounter_stage(restoring)
	_refresh_encounter_window()
	encounter_changed.emit()

func _encounter_button(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = label
	button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	button.offset_left = -290
	button.offset_right = -24
	button.offset_top = -102
	button.offset_bottom = -38
	button.add_theme_font_override("font", preload("res://assets/fonts/NotoSansArabic.ttf"))
	if callback.is_valid(): button.pressed.connect(callback)
	_encounter_layer.add_child(button)
	return button

func _encounter_window() -> Node:
	return main.hud.find_child("SystemWindow", true, false)

func _encounter_text(ar: String, en: String) -> String:
	return ar if main.presentation_language == "ar" else en

func _refresh_encounter_window() -> void:
	if not encounter_live: return
	_encounter_language = main.presentation_language
	_encounter_skip.text = _encounter_text("تجاوز العرض", "Skip presentation")
	_encounter_skip.visible = encounter_step < 5 or encounter_step == 6
	_encounter_power.text = _encounter_text("اضغط ثم ارفع: اختبار السحب", "Hold, then release: test the draw")
	_encounter_power.visible = encounter_step == 7
	_encounter_look_hint.visible = encounter_step < 6
	_encounter_look_hint.text = _encounter_text("للنظر: اسحب خارج البطاقة؛ بالفأرة اضغط الزر الأيمن أثناء السحب.", "Look: right-drag with the mouse, or touch-drag outside the card.")
	if encounter_step == 7: return
	var titles := ["في القاع", "…", "الصوت", "زيرو", "قبل القرار", "عقد زيرو", "EX-011"]
	var titles_en := ["At the bottom", "…", "The voice", "Zero", "Before the choice", "Zero's pact", "EX-011"]
	var messages := ["ما زلت هنا.", "…", "أنت كنت تحاول أن تبقى إنسانًا.", "هذا شكلي الحقيقي. أنا لست إنسانًا… ولا ذكرى.", "اسأل قبل أن تختار.", "لن أحتل جسدك… إلا إذا تركتني. الثمن هو أن أكون معك… إلى النهاية.", "حين لامسته… اختفى الشكل، وبقيت اللعنة. العلامة ما زالت على الجلد."]
	var messages_en := ["You are still here.", "…", "You were trying to remain human.", "This is my true form. I am neither human… nor a memory.", "Ask before you choose.", "I will not inhabit your body… unless you let me. The price is that I remain with you… until the end.", "When he touched it… the form vanished, and the curse remained. The mark is still on the skin."]
	var choices: Array = []
	var title: String = _encounter_text(titles[encounter_step], titles_en[encounter_step])
	var message: String = _encounter_text(messages[encounter_step], messages_en[encounter_step])
	if encounter_step == 5 and _encounter_save_failed: message += "\n\n" + _encounter_text("تعذر الحفظ. لم يُقبل العقد؛ يمكنك إعادة المحاولة.", "Saving failed. The pact was not accepted; you may retry.")
	if encounter_step == 4:
		if encounter_answer >= 0:
			var replies := ["الثمن هو أن أكون معك… إلى النهاية.", "أنا لم آخذ منك شيئًا. أنا فقط… أعطيك ما بقي.", "أنا لن أحتل جسدك… إلا إذا تركتني. وإذا ضعفت… سأكمل أنا الطريق."]
			var replies_en := ["The price is that I remain with you… until the end.", "I took nothing from you. I am only… giving you what remains.", "I will not inhabit your body… unless you let me. If you weaken… I will finish the journey."]
			message = _encounter_text(replies[encounter_answer], replies_en[encounter_answer])
			choices.append({"id": "QUESTIONS", "text": _encounter_text("متابعة", "Continue")})
		else:
			var questions := ["ما الثمن؟", "لماذا أنا؟", "كيف أثق بك؟"]
			var questions_en := ["What is the price?", "Why me?", "How can I trust you?"]
			for index in 3:
				choices.append({"id": "QUESTION_%d" % index, "text": ("✓ " if encounter_questions & (1 << index) else "") + _encounter_text(questions[index], questions_en[index])})
			if encounter_questions == 7: choices.append({"id": "NEXT", "text": _encounter_text("إلى القرار", "Make the choice")})
	elif encounter_step == 5:
		choices = [{"id": "CONFIRM_ZERO_PACT", "text": _encounter_text("أعطني ما أحتاجه. لا يهم.", "Give me what I need. It does not matter.")}, {"id": "DEFER_ZERO_PACT", "text": _encounter_text("ليس الآن", "Not yet")}]
	else:
		choices.append({"id": "NEXT", "text": _encounter_text("متابعة", "Continue")})
	_encounter_generation += 1
	var window := _encounter_window()
	window.show_decision(title, message, choices, _choose_encounter.bind(_encounter_generation))
	window.set_inspection_layout()
	_encounter_window_generation = window._window_generation
	main._on_opening_dialogue_started()

func _choose_encounter(choice: String, generation: int) -> void:
	if not encounter_live or generation != _encounter_generation or get_tree().paused: return
	_encounter_window_generation = -1
	if encounter_step == 4:
		if choice.begins_with("QUESTION_") and encounter_answer < 0:
			var index := int(choice.trim_prefix("QUESTION_"))
			if index < 0 or index > 2 or choice != "QUESTION_%d" % index: return
			encounter_questions |= 1 << index
			encounter_answer = index
		elif choice == "QUESTIONS" and encounter_answer >= 0: encounter_answer = -1
		elif choice == "NEXT" and encounter_questions == 7 and encounter_answer < 0:
			_set_encounter_step(5)
			return
		else: return
		_refresh_encounter_window()
		encounter_changed.emit()
		return
	if encounter_step == 5:
		if choice in ["CONFIRM_ZERO_PACT", "DEFER_ZERO_PACT"]: encounter_choice_requested.emit(choice)
		return
	if choice == "NEXT" and encounter_step in [0, 1, 2, 3, 6]: _set_encounter_step(encounter_step + 1)

func _set_encounter_step(value: int) -> void:
	encounter_step = value
	_encounter_save_failed = false
	encounter_answer = -1
	_elapsed = 0
	_encounter_generation += 1
	_apply_encounter_stage(false)
	_refresh_encounter_window()
	encounter_changed.emit()

func confirm_encounter_contract() -> void:
	if encounter_live and encounter_step == 5 and room.contract_done: _set_encounter_step(6)

func defer_encounter() -> void:
	if not encounter_live or encounter_step != 5 or room.contract_done: return
	encounter_deferred = true
	_close_encounter_view()
	encounter_changed.emit()

func _skip_encounter() -> void:
	if not encounter_live or get_tree().paused: return
	if encounter_step < 5: _set_encounter_step(4)
	elif encounter_step == 6: _set_encounter_step(7)

func _apply_encounter_stage(restoring: bool) -> void:
	if is_instance_valid(room.narrative_trial): room.narrative_trial.reflection_space.pact_view_active = encounter_live and encounter_step < 7
	set_stage("accepted" if encounter_step >= 6 else ("manifested" if encounter_step >= 3 else "dormant"), restoring)
	if encounter_step == 1 and audio_director: audio_director.set_stage("dormant", true, false)
	elif encounter_step == 2 and audio_director: audio_director.set_stage("manifested", restoring, false)
	if encounter_step >= 7: _zero.hide()
	var model: Node3D = main.player.get_node("ModelRoot")
	if encounter_live and encounter_step < 3:
		model.hide()
		_encounter_model_hidden = true
	elif _encounter_model_hidden:
		model.visible = _encounter_model_visible
		_encounter_model_hidden = false
	if not encounter_live: return
	_clear_encounter_mark()
	if encounter_step == 6:
		_encounter_mark = preload("res://scripts/cinematics/skin_mark_inspection_camera.gd").new()
		add_child(_encounter_mark)
		if not _encounter_mark.begin(model, _previous):
			_encounter_mark.queue_free()
			_encounter_mark = null
		contract_cinematic_shot="mark"
		var wing:Node=main.player.find_child("ZeroShadowWing",true,false)
		if wing:
			if restoring or room.reduced_motion:wing.complete_cinematic_emergence()
			else:wing.restart_cinematic_emergence()
	if encounter_step == 7:
		_close_encounter_window()
		_encounter_window().dismiss_task_assignments()
		_restore_encounter_camera()
		if not _encounter_power_staged:
			# The altar view leaves Echo facing the near exit wall. Stage the
			# first playable draw down the lab lane, with the orbit behind him;
			# the ordinary swept capsule and camera collision remain authoritative.
			var direction: Vector3=room.global_basis*Vector3.FORWARD
			direction.y=0
			direction=direction.normalized()
			main.player.visual_root.rotation.y=atan2(direction.x,direction.z)+main.player.model_forward_yaw_offset
			var orbit: Vector3=main.player.camera_target_rotation
			orbit.y=atan2(-direction.x,-direction.z)
			main.player.set_gameplay_orbit(orbit)
			_encounter_power_staged=true
		var wing:Node=main.player.find_child("ZeroShadowWing",true,false)
		if wing:wing.complete_cinematic_emergence()
		_restore_story_hud()
		main._release_gameplay_modal_controls()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	main._on_opening_dialogue_started()
	_camera.fov = 48 if encounter_step < 4 else 40
	if encounter_step < 3:
		_camera.global_position = main.player.global_position + Vector3.UP * [.55, .7, .9][encounter_step]
		_camera.look_at(room.to_global(Vector3(0, 2.3, -35.5)))
	elif encounter_step < 5:
		_camera.global_position = room.to_global(Vector3(2.1, 1.35, -29.5))
		_camera.look_at(room.to_global(Vector3(0, 3.35, -35.5)))
	elif encounter_step == 5:
		var center: Vector3 = main.player.global_position.lerp(_zero.global_position, .55) + Vector3.UP * 1.6
		_camera.global_position = center + Vector3(7, 2.4, 4)
		_camera.look_at(center + Vector3.UP * .5)
	else:
		_camera.global_position = main.player.global_position + Vector3(-.65, 1.78, .9)
		_camera.look_at(main.player.global_position + Vector3.UP * 1.5)
	_encounter_base = _camera.global_transform
	if not is_instance_valid(_encounter_mark): _camera.make_current()

func _tick_encounter(delta: float) -> void:
	_elapsed += minf(delta,.1) if encounter_step==6 else delta
	sync_encounter_preferences()
	if encounter_step < 7:
		main.player.control_locked = true
		_hold_story_hud_quiet()
		if not _encounter_window().visible: _refresh_encounter_window()
		if not is_instance_valid(_encounter_mark):
			_camera.global_transform = _encounter_base
			if encounter_step == 0 and not room.reduced_motion: _camera.global_position.y += .18 * (1 - smoothstep(0, 1, minf(_elapsed / .9, 1)))
			_camera.rotate_object_local(Vector3.UP, -encounter_look.x)
			_camera.rotate_object_local(Vector3.RIGHT, -encounter_look.y)
	if encounter_step == 6 and (room.reduced_motion or _elapsed >= 1.8): _zero.hide()
	if encounter_step == 6:_tick_contract_cinematic()
	if encounter_step == 7 and _encounter_power_observed:
		_encounter_power_elapsed += delta
		_encounter_power.disabled = true
		if _encounter_power_elapsed >= .8 and not main.player.is_attacking:
			encounter_step = 8
			_close_encounter_view()
			encounter_changed.emit()
			encounter_completed.emit()

func _tick_contract_cinematic() -> void:
	if not is_instance_valid(_camera) or not is_instance_valid(_encounter_mark):return
	var owns:bool=_camera.current or _encounter_mark.camera.current
	if not owns:return
	if room.reduced_motion or _elapsed<.65:
		contract_cinematic_shot="mark"
		_encounter_mark.camera.make_current()
		return
	var wing:Node=main.player.find_child("ZeroShadowWing",true,false)
	var eye:Node=main.player.find_child("ZeroEyeSingularity",true,false)
	if not wing or not eye or not wing.mount_valid or not eye.mount_valid:return
	var rig:Skeleton3D=wing.attachment.skeleton
	for name in ["LeftShoulder","RightShoulder","LeftHand"]:
		if rig.find_bone(name)<0:return
	var left:Vector3=(rig.to_global(rig.get_bone_global_pose(rig.find_bone("LeftShoulder")).origin)-rig.to_global(rig.get_bone_global_pose(rig.find_bone("RightShoulder")).origin)).normalized()
	var forward:Vector3=(main.player.visual_root.global_basis*main.player.model_local_forward).normalized()
	var center:Vector3=main.player.global_position+Vector3.UP*1.25+left*.25
	var desired:Vector3
	if _elapsed<1.9:
		contract_cinematic_shot="wing"
		desired=center-forward*3.0+left*2.0+Vector3.UP*.65
		_camera.fov=42
	elif _elapsed<2.75:
		contract_cinematic_shot="eye"
		center=eye.global_position
		desired=center+forward*.40+left*.055+Vector3.UP*.015
		_camera.fov=28
	elif _elapsed<3.6:
		contract_cinematic_shot="hand"
		center=rig.to_global(rig.get_bone_global_pose(rig.find_bone("LeftHand")).origin)
		desired=center+forward*.48+left*.26+Vector3.UP*.17
		_camera.fov=36
	else:
		contract_cinematic_shot="portrait"
		desired=center+forward*2.9+left*1.7+Vector3.UP*.40
		_camera.fov=42
	desired=center+Basis(Vector3.UP,-encounter_look.x)*(desired-center)
	center+=Vector3.UP*encounter_look.y*.08
	var probe:=PhysicsShapeQueryParameters3D.new()
	if not _contract_camera_shape:
		_contract_camera_shape=SphereShape3D.new();_contract_camera_shape.radius=.08
	probe.shape=_contract_camera_shape;probe.transform=Transform3D(Basis.IDENTITY,center);probe.motion=desired-center
	probe.collision_mask=main.player.collision_mask;probe.exclude=[main.player.get_rid()]
	var fractions:PackedFloat32Array=main.player.get_world_3d().direct_space_state.cast_motion(probe)
	_camera.global_position=center+(desired-center)*maxf(0.0,fractions[0]-.015)
	if _camera.global_position.distance_to(center)<.2:
		_encounter_mark.camera.make_current()
		return
	_camera.look_at(center)
	_camera.make_current()

func sync_encounter_preferences() -> void:
	if not encounter_live: return
	_sync_audio_preferences()
	if _encounter_language != main.presentation_language: _refresh_encounter_window()
	if encounter_step == 0 and room.reduced_motion and is_instance_valid(_camera): _camera.global_transform = _encounter_base

func _input(event: InputEvent) -> void:
	if not encounter_live or encounter_step >= 6 or get_tree().paused: return
	var relative := Vector2.ZERO
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): relative = event.relative
	elif event is InputEventScreenDrag:
		if _encounter_window().panel.get_global_rect().has_point(event.position): return
		relative = event.relative
	if relative == Vector2.ZERO: return
	encounter_look.x = clampf(encounter_look.x + relative.x * .0018, -.5, .5)
	encounter_look.y = clampf(encounter_look.y + relative.y * .0018, -.3, .3)
	get_viewport().set_input_as_handled()

func _begin_encounter_power() -> void:
	if not encounter_live or encounter_step != 7 or not room.contract_done or get_tree().paused: return
	main.player.sheath_weapon()
	main.player.start_iai_charge()

func _release_encounter_power() -> void:
	if encounter_live and encounter_step == 7 and room.contract_done and not get_tree().paused: main.player.execute_iai_slash()

func _observe_encounter_power(action_name: String) -> void:
	if action_name=="melee" and encounter_step==8 and not encounter_live and room.contract_done and not room.revenge_done:
		# The power lane can leave the approach orbit behind Kinja. At an
		# actual attack only, reuse the existing bounded clearance solver if
		# the actor would retract the lens into Echo. Clear/manual views keep
		# their owner; no collision masks or gameplay flags are changed.
		_clearance_origin=main.player.camera_target_rotation
		_ensure_gameplay_return_clearance(true)
		return
	if action_name not in ["melee", "iai"] or not encounter_live or encounter_step != 7 or not room.contract_done: return
	_encounter_power_observed = true
	_encounter_power_elapsed = 0

func _close_encounter_window() -> void:
	if not is_instance_valid(main) or main.is_queued_for_deletion(): return
	var window := _encounter_window()
	if window._window_generation == _encounter_window_generation and window.visible: window.close_window()
	_encounter_window_generation = -1

func _clear_encounter_mark() -> void:
	if not is_instance_valid(_encounter_mark): return
	if is_instance_valid(_encounter_mark.camera) and _encounter_mark.camera.current: _encounter_mark.restore_camera()
	_encounter_mark.queue_free()
	_encounter_mark = null

func _close_encounter_view() -> void:
	var owned_camera: bool = (is_instance_valid(_camera) and _camera.current) or (is_instance_valid(_encounter_mark) and is_instance_valid(_encounter_mark.camera) and _encounter_mark.camera.current)
	encounter_live = false
	if is_instance_valid(room) and is_instance_valid(room.narrative_trial): room.narrative_trial.reflection_space.pact_view_active = false
	_encounter_generation += 1
	_close_encounter_window()
	_clear_encounter_mark()
	if owned_camera: _restore_encounter_camera()
	if is_instance_valid(_camera):
		_camera.queue_free()
	_camera = null
	_previous = null
	if is_instance_valid(_encounter_layer): _encounter_layer.queue_free()
	_encounter_layer = null
	_encounter_skip = null
	_encounter_power = null
	_encounter_look_hint = null
	if is_instance_valid(main) and not main.is_queued_for_deletion():
		if _encounter_model_hidden: main.player.get_node("ModelRoot").visible = _encounter_model_visible
		_encounter_model_hidden = false
		_restore_story_hud()
		main._release_gameplay_modal_controls()

func _restore_encounter_camera() -> void:
	if is_instance_valid(_previous) and not _previous.is_queued_for_deletion():
		_previous.make_current()
	elif is_instance_valid(main) and is_instance_valid(main.player) and is_instance_valid(main.player.player_camera):
		main.player.player_camera.make_current()

func _cancel_encounter() -> void:
	_close_encounter_view()
	encounter_started = false
