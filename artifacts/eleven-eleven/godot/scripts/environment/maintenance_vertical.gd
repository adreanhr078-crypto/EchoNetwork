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
		if row.climbable: body.add_to_group("climbable")
	for position in [Vector3(-3, 4.8, -2), Vector3(1, 6.3, -6), Vector3(4, 6.8, -10)]:
		var light := OmniLight3D.new()
		light.position = position
		light.light_color = Color(0.72, 0.83, 1)
		light.light_energy = 1.1
		light.omni_range = 8.0
		add_child(light)
	var animation := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation:
		# A still rest pose is valid for reduced motion; director owns playback.
		animation.stop()
	_gate = find_child("ServiceGateRoot", true, false)
	_valve = find_child("ServiceValveRoot", true, false)
	if not _gate or not _valve:
		push_error("Maintenance service hierarchy missing")
		return
	_closed_gate = _gate.position
	_closed_valve = _valve.rotation
	var body := StaticBody3D.new()
	body.name = "ServiceGateCollision"
	body.position = Vector3(0, 6.36, -12.94)
	_gate_collider = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.75, 1.9, 0.16)
	_gate_collider.shape = shape
	body.add_child(_gate_collider)
	add_child(body)
	var station := Node3D.new()
	station.name = "ServiceOverride"
	station.set_script(OVERRIDE)
	station.position = Vector3(1.25, 5.4, -12.1)
	service_interaction = InteractableComponent.new()
	service_interaction.name = "InteractionArea"
	service_interaction.verb = InteractableComponent.InteractionVerb.OPEN
	service_interaction.position.y = 0.9
	var area_shape := CollisionShape3D.new()
	var range_shape := SphereShape3D.new()
	range_shape.radius = 0.85
	area_shape.shape = range_shape
	service_interaction.add_child(area_shape)
	station.add_child(service_interaction)
	add_child(station)
	set_language("ar")
	_release_audio = AudioStreamPlayer3D.new()
	_release_audio.name = "ServiceReleaseSound"
	_release_audio.stream = RELEASE_SOUND
	_release_audio.position = Vector3(0,6.4,-12.9)
	_release_audio.volume_db = -18
	_release_audio.max_distance = 12
	add_child(_release_audio)
	var destination_light := OmniLight3D.new()
	destination_light.position = Vector3(0,6.8,-11.5)
	destination_light.light_color = Color(0.8,0.9,1)
	destination_light.light_energy = 1.25
	destination_light.omni_range = 5
	add_child(destination_light)

func set_language(language: String) -> void:
	if service_interaction:
		service_interaction.prompt_target_name = "عجلة تنفيس الضغط" if language == "ar" else "Pressure relief wheel"

func request_service_release(interactor: Node3D) -> Dictionary:
	var floor_anchor := to_global(Vector3(1.25,5.4,-12.1))
	if not service_allowed or service_open or service_opening:
		return {"released":false, "reason":"not_ready"}
	if not interactor is EchoPlayer or service_interaction.current_interactor != interactor or interactor.control_locked or not interactor.is_on_floor() or interactor.global_position.distance_to(floor_anchor) > 1.15:
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
