extends Node3D

## Native pre-pact scene, anchored to approved PDF37–44. One atomic story event:
## interruption replays from the neural station; only its ending commits the
## existing confrontation_done flag. Never accepts a pact or grants power.
signal phase_changed(value: String)
const MEMORY_IMAGES = {
	"shizuka": preload("res://assets/textures/lab-memory/shizuka-pdf041.webp"),
	"yuki": preload("res://assets/textures/lab-memory/yuki-pdf041.webp")
}

class MemoryStation extends StaticBody3D:
	var director: Node
	var memory_id := ""
	var prompt_target_name := ""
	var verb := InteractableComponent.InteractionVerb.INSPECT
	func trigger_interaction(interactor: Node = null) -> Dictionary:
		return director.inspect_memory(memory_id, interactor)
	func get_interaction_verb(language: String) -> String:
		return "تذكّر" if language == "ar" else "Remember"

var main: Node
var room: Node3D
var phase := "dormant"
var memories: Array[String] = []
var stations: Array[StaticBody3D] = []
var _plates: Array[Sprite3D] = []
var _frames: Array[Node3D] = []
var _labels: Array[Label3D] = []
var _language := ""
var _generation := 0
var _dialogue_callback := Callable()
var _owned_window_generation := -1
var _owns_dialogue := false
var _abyss: ColorRect
var _abyss_material: ShaderMaterial
var _elapsed := 0.0
var _recognition_camera: Camera3D
var _previous_camera: Camera3D
var _handoff_pending := false
var reflection_space: Node3D
var memory_insert: CanvasLayer
var _hud_before_insert := true

func configure(owner: Node, laboratory: Node3D) -> void:
	main = owner
	room = laboratory
	reflection_space = preload("res://scripts/environment/memory_reflection_space.gd").new()
	reflection_space.name = "MemoryReflectionSpace"
	add_child(reflection_space)
	reflection_space.configure(self,laboratory)
	for id in ["shizuka", "yuki"]:
		_build_memory(id)
	var cinema:=preload("res://scripts/environment/lab_memory_cinema.gd").new()
	cinema.name="IntactMemoryCinema"
	add_child(cinema)
	cinema.configure(room,self)
	for pod in [room._shizuka_pod,room._yuki_pod]:
		var chassis: Node3D = preload("res://assets/props/memory_stasis_frame_clean_v1.glb").instantiate()
		chassis.name = "MemoryStasisFrame"
		pod.add_child(chassis)
		chassis.position = Vector3(0,-1.3,0)
		var glass: StandardMaterial3D = pod.material_override.duplicate()
		glass.albedo_color = Color(.06,.14,.20,.17)
		glass.emission = Color(.08,.25,.32)
		glass.emission_energy_multiplier = .3
		pod.material_override = glass
	main.hud.find_child("DialogueOverlay", true, false).dialogue_completed.connect(_dialogue_finished)
	room.memory_drowning_completed.connect(func():
		if phase == "drowning" and room.confrontation_done: _set_phase("complete"))
	var layer := CanvasLayer.new()
	layer.layer = 0 # World treatment only; all live HUD/dialogue controls remain above it.
	add_child(layer)
	_abyss = ColorRect.new()
	_abyss.name = "SubjectiveMemoryWater"
	_abyss.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_abyss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_abyss_material = ShaderMaterial.new()
	_abyss_material.shader = preload("res://shaders/lab_memory_abyss.gdshader")
	_abyss.material = _abyss_material
	layer.add_child(_abyss)
	_abyss.hide()

func _process(delta: float) -> void:
	if not is_instance_valid(_abyss): return
	if phase in ["abyss","drowning"] and not room.reduced_motion: _elapsed += delta
	sync_preferences()
	if phase == "abyss" and is_instance_valid(memory_insert) and memory_insert._done:
		var window: Node = main.hud.find_child("SystemWindow",true,false)
		if not window.visible and not window._closing: _show_resistance(_generation)

func sync_preferences() -> void:
	if not is_instance_valid(_abyss): return
	if is_instance_valid(memory_insert): memory_insert.sync_preferences(main.presentation_language,room.reduced_motion,room.audio_muted)
	if _language != main.presentation_language:
		_refresh_labels()
		var window: Node = main.hud.find_child("SystemWindow",true,false)
		if window.visible and not window._closing and window._window_generation == _owned_window_generation:
			if phase == "refusal": _present_refusal(_generation)
			elif phase == "abyss" and not _handoff_pending: _show_resistance(_generation)
	_abyss.visible = phase in ["abyss","drowning"]
	_abyss_material.set_shader_parameter("elapsed",_elapsed)
	_abyss_material.set_shader_parameter("motion",0.0 if room.reduced_motion else 1.0)

func _text(ar: String, en: String) -> String:
	return main.opening_text(ar, en)

func _set_phase(value: String) -> void:
	phase = value
	if value == "abyss":
		_elapsed = 0.0
		# Reuse the existing non-musical pressure stem without revealing Zero.
		room.story_presentation.audio_director.set_stage("manifested",true,false)
	for plate in _plates: plate.visible = phase in ["memories", "refusal", "abyss"]
	for frame in _frames: frame.visible = phase in ["memories", "refusal", "abyss"]
	_refresh_labels()
	for station in stations:
		_refresh_station(station)
	_refresh_terminal()
	phase_changed.emit(phase)

func _refresh_labels() -> void:
	_language = main.presentation_language
	for i in stations.size():
		var station: StaticBody3D = stations[i]
		var caption := _text("ذكرى شيزوكا", "Shizuka's memory") if station.memory_id == "shizuka" else _text("ذكرى يوكي", "Yuki's memory")
		station.prompt_target_name = caption
		station.set_meta("interaction_label_ar","ذكرى شيزوكا" if i == 0 else "ذكرى يوكي")
		station.set_meta("interaction_label_en","Shizuka's memory" if i == 0 else "Yuki's memory")
		_labels[i].text = caption

func objective() -> String:
	match phase:
		"recognition": return _text("استمع إلى كينجا. يمكنك متابعة كل سطر عندما تكون مستعدًا.", "Listen to Kinja. Continue each line when you are ready.")
		"memories":
			return _text("اقترب من أثرَي يوكي وشيزوكا عند جانبَي المنصة وتفاعل معهما. ", "Approach Yuki's and Shizuka's memories beside the platform and interact. ") + "\u2066%d / 2\u2069" % memories.size()
		"refusal": return _text("هذا الاختبار يطلب منك خسارة أحدهما. أجب كينجا.", "The trial demands that you lose one of them. Answer Kinja.")
		"abyss": return _text("ما زلت هنا. حاول الوصول إلى الضوء.", "You are still here. Try to reach the light.")
	return ""

func begin() -> Dictionary:
	if room.confrontation_done: return {"success": true, "already_confronted": true}
	if phase != "dormant":
		var window: Node = main.hud.find_child("SystemWindow",true,false)
		var dialogue: Node = main.hud.find_child("DialogueOverlay",true,false)
		if not window.visible and not dialogue.is_active and not _handoff_pending:
			if phase == "refusal": _present_refusal(_generation)
			elif phase == "abyss": _show_resistance(_generation)
		return {"success": true, "trial_active": true}
	if not is_instance_valid(room.player) or room.player != main.player: return {"success": false, "reason": "inactive_room"}
	_generation += 1
	memories.clear()
	_set_phase("recognition")
	_frame_father()
	# PDF37 and40: actual father recognition, not an invented lore explanation.
	_dialogue([
		_line("إيكو", "Echo", "أنت… كنت تعرف؟", "You… you knew?"),
		_line("كينجا", "Kinja", "كنت أراقب كل لحظة.", "I was watching every moment."),
		_line("كينجا", "Kinja", "هل يستطيع الإنسان الاستمرار بعد فقدان كل شيء؟", "Can a human keep going after losing everything?"),
		_line("إيكو", "Echo", "لأنني ابنك؟", "Because I am your son?"),
		_line("كينجا", "Kinja", "لا… لأنك الوحيد الذي لم ينهَر بعد.", "No… because you are the only one who has not broken yet.")
	], _begin_memories)
	return {"success": true, "trial_started": true}

func _line(ar_name: String, en_name: String, ar: String, en: String) -> Dictionary:
	return {"speaker_ar":ar_name,"speaker_en":en_name,"text_ar":ar,"text_en":en,"speaker_color": Color(.82,.76,.94) if en_name == "Kinja" else Color(.72,.9,.95)}

func _dialogue(lines: Array, next: Callable) -> void:
	_dialogue_callback = next.bind(_generation)
	_owns_dialogue = true
	main.hud.start_dialogue(lines)

func _dialogue_finished() -> void:
	if not _dialogue_callback.is_valid(): return
	_owns_dialogue = false
	var next := _dialogue_callback
	_dialogue_callback = Callable()
	_handoff_pending = true
	main.player.control_locked = true
	main.player.clear_traversal_input()
	_continue_dialogue.call_deferred(next,_generation)

func _continue_dialogue(next: Callable, generation: int) -> void:
	if generation != _generation: return
	_handoff_pending = false
	next.call()
	main._release_gameplay_modal_controls()

func _begin_memories(generation: int) -> void:
	if generation != _generation or phase != "recognition": return
	_release_camera()
	_set_phase("memories")

func _frame_father() -> void:
	var controller: Node = main.get_node("NativeCampaignController")
	if not is_instance_valid(controller.kinja): return
	_previous_camera = get_viewport().get_camera_3d()
	_recognition_camera = Camera3D.new()
	_recognition_camera.name = "FatherRecognitionCamera"
	_recognition_camera.fov = 36.0
	_recognition_camera.near = .07
	if is_instance_valid(_previous_camera): _recognition_camera.environment = _previous_camera.environment
	add_child(_recognition_camera)
	_recognition_camera.global_position = controller.kinja.global_position + Vector3(.65,1.78,1.55)
	_recognition_camera.look_at(controller.kinja.global_position + Vector3.UP * 1.48)
	_recognition_camera.make_current()

func _release_camera() -> void:
	if is_instance_valid(_previous_camera): _previous_camera.make_current()
	if is_instance_valid(_recognition_camera): _recognition_camera.queue_free()
	_recognition_camera = null
	_previous_camera = null

func _frame_memory(id: String) -> void:
	# Keep the actual approved face above the dialogue instead of hiding most
	# of the projection behind the lower third from the player's rear camera.
	_release_camera()
	var plate: Sprite3D = _plates[0] if id == "shizuka" else _plates[1]
	_previous_camera = get_viewport().get_camera_3d()
	_recognition_camera = Camera3D.new()
	_recognition_camera.name = "MemoryInspectionCamera"
	_recognition_camera.fov = 38.0
	_recognition_camera.near = .07
	if is_instance_valid(_previous_camera): _recognition_camera.environment = _previous_camera.environment
	add_child(_recognition_camera)
	_recognition_camera.global_position = plate.global_position + Vector3(0,.4,2.6)
	_recognition_camera.look_at(plate.global_position - Vector3(0,.45,0))
	_recognition_camera.make_current()

func _build_memory(id: String) -> void:
	var station := MemoryStation.new()
	station.name = "Memory_" + id
	station.memory_id = id
	station.director = self
	station.position = Vector3(-4.8 if id == "shizuka" else 4.8, 1.2, -20)
	station.collision_layer = 0
	station.collision_mask = 0
	add_child(station)
	stations.append(station)
	var area := Area3D.new()
	area.name = "InteractionArea"
	var col := CollisionShape3D.new()
	col.shape = SphereShape3D.new()
	col.shape.radius = 1.65
	col.position.y = .8
	area.add_child(col)
	station.add_child(area)
	area.body_entered.connect(func(_body: Node3D): _refresh_station(station))
	area.body_exited.connect(func(body: Node3D):
		if body.has_method("unregister_nearby_interactable"): body.unregister_nearby_interactable(station))
	var plate := Sprite3D.new()
	plate.name = "ApprovedMemory_" + id
	plate.texture = MEMORY_IMAGES[id]
	plate.pixel_size = .0021
	plate.position = Vector3(-7.0 if id == "shizuka" else 7.0, 1.5, -19.82)
	plate.shaded = false
	plate.no_depth_test = false
	plate.hide()
	add_child(plate)
	_plates.append(plate)
	var frame := MeshInstance3D.new()
	frame.name = "MemoryProjectionFrame_"+id
	frame.mesh = BoxMesh.new()
	frame.mesh.size = Vector3(1.42,.82,.04)
	var graphite := StandardMaterial3D.new()
	graphite.albedo_color = Color(.024,.035,.055)
	graphite.roughness = .48
	graphite.metallic = .4
	frame.material_override = graphite
	frame.position = plate.position - Vector3(0,.025,.05)
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(frame)
	_frames.append(frame)
	frame.hide()
	var label := Label3D.new()
	label.font = preload("res://assets/fonts/NotoSansArabic.ttf")
	label.font_size = 25
	label.pixel_size = .003
	label.position = Vector3(0,-.33,.04)
	label.modulate = Color(.68,.84,.91)
	frame.add_child(label)
	_labels.append(label)

func _refresh_station(station: StaticBody3D) -> void:
	if not is_instance_valid(main) or not is_instance_valid(main.player): return
	var available := phase == "memories" and not memories.has(station.memory_id)
	var area := station.get_node("InteractionArea") as Area3D
	if available and area.get_overlapping_bodies().has(main.player): main.player.register_nearby_interactable(station)
	else: main.player.unregister_nearby_interactable(station)

func terminal_available() -> bool:
	return phase in ["dormant","refusal","abyss"] and not room.confrontation_done

func _refresh_terminal() -> void:
	if not is_instance_valid(main) or not is_instance_valid(main.player): return
	var terminal: Node = room._neural_terminal
	if terminal_available() and terminal.get_node("InteractionArea").get_overlapping_bodies().has(main.player): main.player.register_nearby_interactable(terminal)
	else: main.player.unregister_nearby_interactable(terminal)

func inspect_memory(id: String, interactor: Node) -> Dictionary:
	if phase != "memories" or interactor != main.player or memories.has(id): return {"success": false, "reason": "inactive_memory"}
	var station: StaticBody3D = stations[0] if id == "shizuka" else stations[1]
	if id not in ["shizuka","yuki"] or not station.get_node("InteractionArea").get_overlapping_bodies().has(interactor): return {"success": false, "reason": "not_in_range"}
	memories.append(id)
	_refresh_station(station)
	_frame_memory(id)
	var line := _line("شيزوكا", "Shizuka", "لا تتركنا.", "Do not leave us.") if id == "shizuka" else _line("يوكي", "Yuki", "إيكو…", "Echo…")
	_dialogue([line], _memory_finished)
	return {"success": true, "memory_examined": id}

func _memory_finished(generation: int) -> void:
	if generation != _generation or phase != "memories": return
	_release_camera()
	if memories.size() < 2: return
	_set_phase("refusal")
	_present_refusal(generation)

func _present_refusal(generation: int) -> void:
	if generation != _generation or phase != "refusal": return
	var window: Node = main.hud.find_child("SystemWindow", true, false)
	# PDF42 has Echo reject the demand. Never invent a sacrifice branch.
	window.show_decision(_text("كينجا", "Kinja"), _text("اختر واحدًا.", "Choose one."), [
		{"id":"REFUSE_MEMORY_SACRIFICE", "text":_text("لا!", "No!")},
		{"id":"RETURN_TO_MEMORIES", "text":_text("انظر إليهما مرة أخرى", "Look at them again")}
	], _answer_refusal.bind(generation))
	window.set_inspection_layout()
	_owned_window_generation = window._window_generation

func _answer_refusal(choice: String, generation: int) -> void:
	if generation != _generation or phase != "refusal": return
	_owned_window_generation = -1
	if choice == "RETURN_TO_MEMORIES":
		memories.clear()
		_set_phase("memories")
		return
	if choice != "REFUSE_MEMORY_SACRIFICE": return
	_set_phase("abyss")
	_dialogue([
		_line("كينجا", "Kinja", "حتى الآن… أنت تختار الوهم.", "Even now… you choose the illusion.")
	], _begin_memory_insert)

func _begin_memory_insert(generation: int) -> void:
	if generation != _generation or phase != "abyss": return
	_handoff_pending = true
	main.player.control_locked = true
	main.player.clear_traversal_input()
	_hud_before_insert = main.hud.visible
	main.hud.hide()
	reflection_space.presentation_covered = true
	memory_insert = preload("res://scripts/ui/opening_memory_film.gd").new()
	memory_insert.film_path = "res://assets/cinematics/lab-memory-collapse-v1.ogv"
	memory_insert.poster_texture = preload("res://assets/cinematics/lab-memory-bottom-v1.webp")
	memory_insert.ambient_path = "res://assets/cinematics/lab-memory-water-v1.ogg"
	memory_insert.show_fracture = false
	memory_insert.hold_poster = true
	# World presentation below HUD/SystemWindow, including the paused decision.
	memory_insert.presentation_layer = 0
	memory_insert.language = main.presentation_language
	memory_insert.reduced_motion = room.reduced_motion
	memory_insert.audio_muted = room.audio_muted
	memory_insert.cue_ar = "أحتاج… أعلى…"
	memory_insert.cue_en = "I need… to go up…"
	memory_insert.continue_ar = "متابعة"
	memory_insert.continue_en = "Continue"
	add_child(memory_insert)
	memory_insert.finished.connect(_memory_insert_finished.bind(generation),CONNECT_ONE_SHOT)

func _memory_insert_finished(generation: int) -> void:
	if generation != _generation or phase != "abyss": return
	_handoff_pending = false
	if _hud_before_insert: main.hud.show()
	_show_resistance(generation)
	main._release_gameplay_modal_controls()

func _clear_memory_insert() -> void:
	if is_instance_valid(memory_insert):
		memory_insert.cancel()
		memory_insert.hide()
		memory_insert.queue_free()
		if is_instance_valid(main) and not main.is_queued_for_deletion() and _hud_before_insert: main.hud.show()
	memory_insert = null
	if is_instance_valid(reflection_space): reflection_space.presentation_covered = false

func _show_resistance(generation: int) -> void:
	if generation != _generation or phase != "abyss": return
	var window: Node = main.hud.find_child("SystemWindow", true, false)
	window.show_decision(_text("في القاع", "At the bottom"), _text("الماء هنا… أثقل من أي شيء عشته.", "The water here… is heavier than anything I have lived through."), [
		{"id":"REACH_FOR_LIGHT", "text":_text("حاول الصعود", "Try to reach the light")}
	], _resist.bind(generation))
	window.set_inspection_layout()
	_owned_window_generation = window._window_generation

func _resist(choice: String, generation: int) -> void:
	if generation != _generation or phase != "abyss" or choice != "REACH_FOR_LIGHT" or _handoff_pending: return
	_owned_window_generation = -1
	_clear_memory_insert()
	_set_phase("drowning")
	room.initiate_memory_confrontation()

func reset_trial() -> void:
	_generation += 1
	_clear_memory_insert()
	_dialogue_callback = Callable()
	_handoff_pending = false
	_release_camera()
	if is_instance_valid(main) and main.get("hud"):
		var dialogue: Node = main.hud.find_child("DialogueOverlay", true, false)
		if _owns_dialogue and dialogue.is_active: dialogue.close_dialogue()
		var window: Node = main.hud.find_child("SystemWindow", true, false)
		if _owned_window_generation == window._window_generation and window.visible: window.close_window()
	_owned_window_generation = -1
	_owns_dialogue = false
	memories.clear()
	if is_instance_valid(room):
		room.story_presentation.audio_director.set_stage("dormant",true,false)
	_set_phase("dormant")
	if is_instance_valid(main) and not main.is_queued_for_deletion(): main._release_gameplay_modal_controls()

func _exit_tree() -> void:
	_generation += 1
	_clear_memory_insert()
	_dialogue_callback = Callable()
	_release_camera()
