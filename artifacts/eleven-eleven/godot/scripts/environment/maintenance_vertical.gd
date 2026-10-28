extends Node3D

## Runtime physics adapter for the portable Blender room; no story authority.
signal service_opened
signal service_release_started
const OVERRIDE = preload("res://scripts/environment/maintenance_service_override.gd")
const RELEASE_SOUND = preload("res://assets/audio/maintenance_service_release_v1.ogg")
const HAND_CONTACT = preload("res://scripts/player/service_hand_contact.gd")
var hand_contact: Node3D
var service_allowed := false
var service_open := false
var service_opening := false
var service_interaction: InteractableComponent
var _gate: Node3D
var _valve: Node3D
var _closed_gate: Vector3
var _closed_valve: Vector3
var _gate_collider: CollisionShape3D
var _release_audio: AudioStreamPlayer3D
var _motion_reduced := false
var _service_tween: Tween
var _valve_tween: Tween
var service_floor_anchor := Vector3(1.25,5.4,-12.1)
var service_hand_anchor := Vector3(1.25,5.4,-12.18)
var service_wheel_center := Vector3(1.25,6.35,-12.34)
var service_gate_anchor := Vector3(0,6.36,-12.94)
var service_camera_position := Vector3(2.8,6.9,-10.85)
var service_camera_target := Vector3(.4,6.4,-12.75)
var presentation: Node3D

func _ready() -> void:
	var spec = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environments/maintenance_collision_v1.json"))
	if not spec is Dictionary or spec.get("schema") != "echo-maintenance-collision-v1":
		push_error("Maintenance collision contract unavailable")
		return
	for row in spec.bodies:
		var body := StaticBody3D.new()
		body.name = row.name
		body.position = Vector3(row.position[0], row.position[1], row.position[2])
		var shape := BoxShape3D.new()
		shape.size = Vector3(row.size[0], row.size[1], row.size[2])
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		add_child(body)
		if row.climbable:
			body.add_to_group("climbable")
			_add_climbable_visual_cues(body, shape.size)
	for lighting in [[Vector3(-3, 4.8, -2), Color(0.58, 0.78, 1), 1.4, 8.0], [Vector3(0.5, 5.6, -4.1), Color(1, 0.65, 0.4), 1.35, 10.5], [Vector3(4, 6.8, -10), Color(0.58, 0.84, 0.94), 1.3, 8.0]]:
		var light := OmniLight3D.new()
		light.position = lighting[0]
		light.light_color = lighting[1]
		light.light_energy = lighting[2]
		light.omni_range = lighting[3]
		add_child(light)
	var animation := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation:
		# A still rest pose is valid for reduced motion; director owns playback.
		animation.stop()
	_build_service()
	presentation = preload("res://scripts/environment/maintenance_room_presentation.gd").new()
	add_child(presentation)
	set_reduced_motion(_motion_reduced)
	preload("res://scripts/environment/maintenance_mechanical_dressing.gd").install(self)

func _build_service() -> void:
	_gate = find_child("ServiceGateRoot", true, false)
	_valve = find_child("ServiceValveRoot", true, false)
	if not _gate or not _valve:
		push_error("Maintenance service hierarchy missing")
		return
	_closed_gate = _gate.position
	_closed_valve = _valve.rotation
	var body := StaticBody3D.new()
	body.name = "ServiceGateCollision"
	body.position = service_gate_anchor
	_gate_collider = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.75, 1.9, 0.16)
	_gate_collider.shape = shape
	body.add_child(_gate_collider)
	add_child(body)
	var station := Node3D.new()
	station.name = "ServiceOverride"
	station.set_script(OVERRIDE)
	station.position = service_floor_anchor
	service_interaction = InteractableComponent.new()
	service_interaction.name = "InteractionArea"
	service_interaction.verb = InteractableComponent.InteractionVerb.OPEN
	service_interaction.position.y = 0.9
	var area_shape := CollisionShape3D.new()
	var range_shape := SphereShape3D.new()
	range_shape.radius = 1.35
	area_shape.shape = range_shape
	service_interaction.add_child(area_shape)
	station.add_child(service_interaction)
	add_child(station)
	set_language("ar")
	_release_audio = AudioStreamPlayer3D.new()
	_release_audio.name = "ServiceReleaseSound"
	_release_audio.stream = RELEASE_SOUND
	_release_audio.position = service_gate_anchor
	_release_audio.volume_db = -18
	_release_audio.max_distance = 12
	add_child(_release_audio)
	var destination_light := OmniLight3D.new()
	destination_light.position = service_floor_anchor + Vector3(-.75,1.3,.8)
	destination_light.light_color = Color(0.8,0.9,1)
	destination_light.light_energy = 1.35
	destination_light.omni_range = 8.5
	add_child(destination_light)

func set_language(language: String) -> void:
	if is_instance_valid(presentation): presentation.set_language(language)
	if service_interaction:
		service_interaction.prompt_target_name = "عجلة تنفيس الضغط" if language == "ar" else "Pressure relief wheel"

func request_service_release(interactor: Node3D) -> Dictionary:
	var floor_anchor := to_global(service_floor_anchor)
	if not service_allowed or service_open or service_opening:
		return {"released":false, "reason":"not_ready"}
	if not interactor is EchoPlayer or service_interaction.current_interactor != interactor or interactor.control_locked or not interactor.is_on_floor() or interactor.global_position.distance_to(floor_anchor) > 1.45:
		return {"released":false, "reason":"out_of_reach"}
	service_opening = true
	_disable_interaction()
	service_release_started.emit()
	hand_contact = HAND_CONTACT.new()
	add_child(hand_contact)
	if not hand_contact.begin(interactor,self): hand_contact.stop()
	_release_audio.play()
	_service_tween = create_tween()
	if not _motion_reduced:
		_valve_tween = create_tween()
		_valve_tween.tween_interval(0.65)
		_valve_tween.tween_property(_valve,"rotation:z",_closed_valve.z + PI*0.18,0.6).set_trans(Tween.TRANS_SINE)
	_service_tween.tween_interval(1.25)
	_service_tween.tween_property(_gate,"position:y",_closed_gate.y+2.1,1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_service_tween.tween_callback(func():
		_gate_collider.set_deferred("disabled",true)
		service_open = true
		service_opening = false
		service_opened.emit()
	)
	return {"released":true}

func restore_service_open() -> void:
	end_service_contact()
	if _service_tween: _service_tween.kill()
	if _valve_tween: _valve_tween.kill()
	service_opening = false
	service_open = true
	_gate.position = _closed_gate + Vector3(0,2.1,0)
	_valve.rotation = _closed_valve
	_gate_collider.set_deferred("disabled",true)
	_release_audio.stop()
	_disable_interaction()
	if is_instance_valid(presentation): presentation.set_route_stage(6)

func end_service_contact() -> void:
	if is_instance_valid(hand_contact): hand_contact.stop()

func _disable_interaction() -> void:
	service_interaction.is_enabled = false
	var interactor = service_interaction.current_interactor
	if is_instance_valid(interactor): interactor.unregister_nearby_interactable(service_interaction)
	service_interaction.current_interactor = null
	service_interaction.is_focused = false

func set_reduced_motion(reduced: bool) -> void:
	_motion_reduced = reduced
	if is_instance_valid(presentation): presentation.set_reduced_motion(reduced)
	if reduced and _valve_tween:
		_valve_tween.kill()
		_valve.rotation = _closed_valve
	var animation := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not animation: return
	for clip in animation.get_animation_list():
		if "Maintenance_Signal_Cycle" in clip:
			if reduced:
				animation.play(clip)
				animation.seek(0, true)
				animation.stop()
			else:
				animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
				animation.play(clip)
			break

func _add_climbable_visual_cues(body: StaticBody3D, size: Vector3) -> void:
	var rung_mat := StandardMaterial3D.new()
	rung_mat.albedo_color = Color(0.12, 0.15, 0.18)
	rung_mat.metallic = 0.85
	rung_mat.roughness = 0.25
	rung_mat.emission_enabled = true
	rung_mat.emission = Color(0.05, 0.35, 0.4)
	rung_mat.emission_energy_multiplier = 0.2

	var rung_count := clampi(int(size.y / 0.55), 3, 7)
	var y_step := (size.y * 0.8) / float(rung_count)
	var start_y := -size.y * 0.38
	for i in range(rung_count):
		var rung := MeshInstance3D.new()
		rung.name = "ClimbRung_%d" % i
		var mesh := BoxMesh.new()
		mesh.size = Vector3(size.x * 0.82, 0.04, 0.06)
		rung.mesh = mesh
		rung.material_override = rung_mat
		rung.position = Vector3(0.0, start_y + i * y_step, size.z * 0.5 + 0.03)
		body.add_child(rung)

	var lip := MeshInstance3D.new()
	lip.name = "ClimbLedgeLip"
	var lip_mesh := BoxMesh.new()
	lip_mesh.size = Vector3(size.x * 0.9, 0.03, 0.06)
	lip.mesh = lip_mesh
	var lip_mat := StandardMaterial3D.new()
	lip_mat.albedo_color = Color(0.1, 0.6, 0.68)
	lip_mat.emission_enabled = true
	lip_mat.emission = Color(0.1, 0.6, 0.68)
	lip_mat.emission_energy_multiplier = 1.0
	lip.material_override = lip_mat
	lip.position = Vector3(0.0, size.y * 0.5, size.z * 0.5 + 0.02)
	body.add_child(lip)
