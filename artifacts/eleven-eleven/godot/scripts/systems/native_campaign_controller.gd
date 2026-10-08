extends Node

## Physical continuation of the native security route. Only the currently
## traversed room owns interactions; authored doorway origins stay distinct.
const Checkpoint = preload("res://scripts/systems/native_campaign_checkpoint.gd")
const HOSPITAL_FILM=preload("res://assets/cinematics/hospital-awakening-v1.ogv")
const IDS := ["specimen","archive","reactor","decon","mirror","lab"]
const FILES := ["specimen_containment_wing","memory_archive_wing","core_reactor_room","decontamination_quarantine_wing","mirror_chamber_room","dr_kinja_lab_room"]
const ORIGINS := [Vector3(2.5,5.4,-71),Vector3(-41.5,5.4,-83),Vector3(-52.5,9.4,-112),Vector3(-52.5,9.4,-172),Vector3(-52.5,9.4,-220),Vector3(-52.5,9.4,-272)]
const EXITS := [Vector3(-30,0,-12),Vector3(-11,0,-14),Vector3(0,0,-44),Vector3(0,0,-32),Vector3(0,0,-36),Vector3(0,0,-40)]
const ANCHORS := [Vector3(-2.5,0.1,2),Vector3(-2,0.1,0),Vector3(0,-3.9,-2.5),Vector3(0,0.1,-2),Vector3(0,0.1,-2),Vector3(0,0.1,-2)]
const CONDUITS := ["archive_to_reactor_conduit","specimen_to_archive_conduit","archive_to_reactor_conduit","reactor_to_decon_conduit","decon_to_surveillance_conduit","surveillance_to_lab_conduit"]
@export var checkpoint_path := Checkpoint.PATH
var main: Node
var native_owner: Node
var rooms: Array[Node3D]=[]
var conduits: Array[Node3D]=[]
var progress := Checkpoint.initial()
var active := false
var built := false
var current := 0
var save_succeeded := true
var _retry := 0.0
var _ui_signature := ""
var kinja: CharacterBody3D
var hospital: Node3D
var _movie: CanvasLayer
var _movie_finished := false
var _mark_inspection:Node3D
var _transfer_running := false
var patient: Node3D
var _bed_camera: Camera3D
var _patient_avatar: Node3D
var _avatar_parent: Node3D
var _avatar_transform: Transform3D
var _patient_modifiers: Dictionary={}

func _ready() -> void:
	main=get_parent()
	native_owner=main.get_node("NativeJourneyController")

func _process(delta: float) -> void:
	_retry=maxf(0,_retry-delta)
	if not native_owner.security or not native_owner._loaded: return
	if not built: _build()
	if not active and native_owner.progress.completed.size()==4: _activate()
	if not active: return
	if current<rooms.size():
		var room: Node3D=rooms[current]
		room.reduced_motion=main.reduced_motion
		if room.has_method("set_presentation_language") and room.presentation_language!=main.presentation_language: room.set_presentation_language(main.presentation_language)
		if "audio_muted" in room: room.audio_muted=main.audio_muted
		_capture_progress()
		var p: Vector3=room.to_local(main.player.global_position)
		var exit: Vector3=EXITS[current]
		var crossed: bool=p.x<exit.x-0.25 and absf(p.z-exit.z)<0.8 if current==0 else p.z<exit.z-0.25 and absf(p.x-exit.x)<0.8
		if current==5: crossed=p.z<-39.3 and absf(p.x)<0.8
		if room.get("breach_open" if current==5 else "gate_open") and crossed and main.player.is_on_floor() and not main.player.control_locked:
			var next:=Checkpoint.advance(progress,IDS[current])
			if not next.is_empty() and _store(next):
				current+=1
				if current==rooms.size(): _begin_hospital()
				else: _set_active_rooms()
	else:
		_capture_progress()
	_refresh_objective()

func _build() -> void:
	built=true
	# The isolated security preview had a closed recovery backstop. The native
	# continuation replaces it with a real 2.6m passage and matching wall piers.
	var backstop:=native_owner.security.get_node("ExitRecoveryBoundary") as StaticBody3D
	backstop.hide()
	(backstop.find_child("CollisionShape3D",true,false) as CollisionShape3D).set_deferred("disabled",true)
	for x in [-2.85,2.85]:
		var pier:=StaticBody3D.new()
		pier.position=Vector3(x,2.2,-18.22)
		var col:=CollisionShape3D.new()
		col.shape=BoxShape3D.new()
		col.shape.size=Vector3(3.1,4.4,0.12)
		pier.add_child(col)
		var visual:=MeshInstance3D.new()
		visual.mesh=BoxMesh.new()
		visual.mesh.size=col.shape.size
		visual.material_override=backstop.get_child(0).material_override
		pier.add_child(visual)
		native_owner.security.add_child(pier)
	var saved:=Checkpoint.load_checkpoint(checkpoint_path)
	if not saved.is_empty(): progress=saved
	for index in IDS.size():
		var room: Node3D=load("res://scenes/environment/"+FILES[index]+".tscn").instantiate()
		room.position=ORIGINS[index]
		room.name="Campaign_"+IDS[index]
		main.add_child(room)
		rooms.append(room)
		if room.has_method("set_presentation_language"): room.set_presentation_language(main.presentation_language)
		if room.has_signal("retry_requested"): room.retry_requested.connect(_retry_room.bind(index))
		_restore_room(index)
		var conduit: Node3D=load("res://scenes/environment/"+CONDUITS[index]+".tscn").instantiate()
		conduit.position=Vector3(0,5.4,-50) if index==0 else ORIGINS[index-1]+EXITS[index-1]
		conduit.name="CampaignBuffer_"+str(index)
		main.add_child(conduit)
		conduits.append(conduit)
	rooms[5].campaign_decisions=true
	rooms[5].contract_decision_requested.connect(_show_pact)
	rooms[5].zero_manifested.connect(_show_pact)
	rooms[5].zero_contract_accepted.connect(_start_revenge)
	rooms[5].wish_decision_requested.connect(_show_wish)
	rooms[1].memory_shard_collected.connect(_show_memory_shard)
	_set_active_rooms()

func _show_memory_shard(id:String) -> void:
	if not active or current!=1: return
	var shard:Area3D=rooms[1]._shard_nodes.get(id)
	if not shard: return
	var config:Dictionary=shard.get_meta("shard_config",{})
	var language:String=main.presentation_language
	var count:String=str(rooms[1].collected_shards.size())+" / 3"
	_window().show_system_window(0,String(config.get("title_"+language,"EX-011")),String(config.get("text_"+language,"")),[count],4.0)

func _activate() -> void:
	active=true
	current=progress.completed.size()
	native_owner.set_process(false)
	native_owner.set_physics_process(false)
	main.player.set_combat_available(false)
	if current>0 and current<rooms.size():
		main.player.surface_motor.reset(main.player)
		main.player.global_position=ORIGINS[current]+ANCHORS[current]
		main.player.velocity=Vector3.ZERO
	if current>=rooms.size(): _begin_hospital(false)
	else:
		_set_active_rooms()
		if current==5 and rooms[5].contract_done and not rooms[5].revenge_done: _start_revenge()
		elif current==5 and rooms[5].revenge_done and not rooms[5].wish_done: _show_wish()
	_refresh_objective()

func _set_active_rooms() -> void:
	for index in rooms.size():
		var show_room: bool=index==current or index==current+1 or index==current-1
		rooms[index].visible=show_room
		rooms[index].process_mode=Node.PROCESS_MODE_INHERIT if index==current and active else Node.PROCESS_MODE_DISABLED
		rooms[index].player=main.player if index==current and active else null
		conduits[index].visible=index==current or index==current+1
		conduits[index].process_mode=Node.PROCESS_MODE_INHERIT if active and (index==current or index==current+1) else Node.PROCESS_MODE_DISABLED
		conduits[index].player=main.player if active and (index==current or index==current+1) else null
	if current>=1:
		native_owner.security.hide()
		native_owner.security.process_mode=Node.PROCESS_MODE_DISABLED
		if native_owner.maintenance.room: native_owner.maintenance.room.hide()
		var opening:=main.get_node_or_null("OpeningNativeRoom") as Node3D
		if opening: opening.hide()

func _retry_room(anchor: Vector3,index: int) -> void:
	if not active or index!=current: return
	main.player.surface_motor.reset(main.player)
	main.player.global_position=rooms[index].to_global(anchor)
	main.player.velocity=Vector3.ZERO
	main.player.stamina=main.player.MAX_STAMINA

func _capture_progress() -> void:
	if not active or _retry>0: return
	var next:=progress.duplicate(true)
	var id: String=IDS[current] if current<IDS.size() else "hospital"
	var room: Node3D=rooms[current] if current<rooms.size() else hospital
	if not room: return
	var state: Dictionary=room.get_state()
	var flags: Dictionary={}
	for key in Checkpoint.FLAGS[id]:
		var observed:bool=state.collected_shards.has(key) if id=="archive" and key.begins_with("shard_") else state.get(key,false)
		flags[key]=observed or progress.flags.get(id,{}).get(key,false)
	if next.flags.get(id,{})==flags: return
	next.flags[id]=flags
	_store(next)

func save_now() -> bool:
	if not active: return true
	_capture_progress()
	return save_succeeded and Checkpoint.save_checkpoint(progress,checkpoint_path)

func _store(next: Dictionary) -> bool:
	if Checkpoint.validate(next).is_empty(): return false
	save_succeeded=Checkpoint.save_checkpoint(next,checkpoint_path)
	if not save_succeeded:
		_retry=1.0
		return false
	progress=next
	return true

func _restore_room(index: int) -> void:
	var flags: Dictionary=progress.flags.get(IDS[index],{})
	if flags.is_empty(): return
	var room: Node3D=rooms[index]
	var state: Dictionary=flags.duplicate()
	var opened:=false
	match index:
		0: opened=state.get("terminal_read",false)
		1:
			state.collected_shards=[]
			for key in ["shard_shizuka","shard_yuki","shard_sector11"]:
				if state.get(key,false): state.collected_shards.append(key)
			opened=state.get("archive_decoded",false)
		2:
			opened=state.get("breaker_a_done",false) and state.get("breaker_b_done",false)
			state.bridge_extended=opened
			state.bridge_pos_y=0.0 if opened else -3.5
		3,4: opened=state.get("override_done",false)
		5:
			opened=state.get("wish_done",false)
			state.breach_open=opened
			state.breach_pos_y=5.2 if opened else 1.4
			state.breach_col_disabled=opened
			state.state=6 if opened else (4 if state.get("contract_done",false) else (3 if state.get("confrontation_done",false) else 0))
	state.gate_open=opened
	state.gate_pos_y=4.8 if opened else 1.4
	state.gate_col_disabled=opened
	room.restore_state(state)

func _window() -> Node:
	return main.hud.find_child("SystemWindow",true,false)

func _show_pact() -> void:
	if current!=5 or not active or rooms[5].contract_done: return
	rooms[5].story_presentation.begin("manifested",main)
	_window().show_decision(main.opening_text("عقد زيرو","Zero's pact"),main.opening_text("لن أسكن داخلك إلا إذا سمحت لي. ستحصل على القوة… لكنني سأبقى داخلك، إلى النهاية.","I will not inhabit you unless you allow it. You will gain power… but I will remain within you, until the end."),[
		{"id":"CONFIRM_ZERO_PACT","text":main.opening_text("أعطني ما أحتاجه. لا يهم.","Give me what I need. It does not matter.")},
		{"id":"DEFER_ZERO_PACT","text":main.opening_text("ليس الآن","Not yet")}],_accept_pact)
	_window().set_inspection_layout()

func _accept_pact(choice: String) -> void:
	if current==5: rooms[5].story_presentation.finish(true)
	if current==5 and choice=="CONFIRM_ZERO_PACT":
		rooms[5].accept_zero_contract()
		_capture_progress()

func _start_revenge() -> void:
	if current!=5 or not rooms[5].contract_done or rooms[5].revenge_done: return
	if not kinja:
		kinja=load("res://scenes/characters/dr_kinga.tscn").instantiate()
		kinja.set_script(preload("res://scripts/characters/kinja_revenge_actor.gd"))
		kinja.position=Vector3(0,0.1,-27)
		rooms[5].add_child(kinja)
		kinja.player=main.player
		kinja.pressure_changed.connect(func(count: int):
			_ui_signature=""
			rooms[5].story_presentation.impact_feedback(count))
		kinja.collar_requested.connect(_collar_confrontation)
	kinja.active=true
	main.player.set_combat_available(true)
	main.player.awaken_zero_pact(0.65)
	main.player.unsheath_weapon()
	# The optional insert is presentation only; reduced motion immediately
	# retains the same explicit decision and controlled confrontation.
	rooms[5].story_presentation.begin("accepted",main,kinja)

func _collar_confrontation() -> void:
	if current!=5 or not kinja or kinja.contacts<3 or not rooms[5].contract_done: return
	rooms[5].story_presentation.begin("revenge",main,kinja)
	_window().show_decision(main.opening_text("إيكو","Echo"),main.opening_text("الآن تريد أن تتكلم؟ بعد كل شيء؟","Now you want to talk? After everything?"),[{"id":"RELEASE_KINJA","text":main.opening_text("أنا أتذكر كل شيء.","I remember everything.")}],func(choice: String):
		if choice!="RELEASE_KINJA" or current!=5: return
		rooms[5].story_presentation.finish(true)
		kinja.completed=true
		kinja.active=false
		main.player.set_combat_available(false)
		rooms[5].complete_revenge()
		_capture_progress())
	_window().set_inspection_layout()

func _show_wish() -> void:
	if current!=5 or not rooms[5].revenge_done or rooms[5].wish_done: return
	_window().show_solo_leveling_glitch_prompt(_accept_wish)

func _accept_wish(choice: String) -> void:
	if current==5 and rooms[5].confirm_escape_wish(choice): _capture_progress()

func _begin_hospital(play_movie:=true) -> void:
	if _transfer_running: return
	_transfer_running=true
	_set_active_rooms()
	for room in rooms: room.hide()
	for conduit in conduits: conduit.hide()
	main.player.clear_traversal_input()
	main.player.set_combat_available(false)
	main.player.dismiss_zero_wing()
	main.player.set_zero_eye_active(false)
	main.player.control_locked=true
	main.player.velocity=Vector3.ZERO
	hospital=load("res://scenes/environment/hospital_bedside_room.tscn").instantiate()
	hospital.position=Vector3(100,0,0)
	main.add_child(hospital)
	hospital.player=main.player
	hospital.reduced_motion=main.reduced_motion
	hospital.audio_muted=main.audio_muted
	# A camera override gives the ward its authored exposure even when the
	# facility's WorldEnvironment still owns the shared world.
	main.player.player_camera.environment=hospital.get_node("HospitalWorldEnvironment").environment
	main.player.surface_motor.reset(main.player)
	main.player.global_position=hospital.to_global(hospital.SAFE_ANCHOR_BEDSIDE+Vector3.UP*0.1)
	main.player.set_gameplay_orbit(Vector3(0,PI/2,0))
	var flags: Dictionary=progress.flags.get("hospital",{})
	if flags.get("bed_awakened",false): hospital.wake_up_from_bed()
	if flags.get("mark_revealed",false): hospital.execute_mirror_inspection(main.player)
	hospital.ex011_mark_revealed.connect(_hospital_mark)
	# Owner requires Golden evidence before any bedside skeletal staging.
	if play_movie and not main.reduced_motion and DisplayServer.get_name()!="headless":
		main._on_opening_dialogue_started()
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		_movie=CanvasLayer.new()
		_movie.layer=88
		main.add_child(_movie)
		var bg:=ColorRect.new()
		bg.color=Color.BLACK
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_movie.add_child(bg)
		var frame:=AspectRatioContainer.new()
		frame.name="FilmFrame"
		frame.ratio=864.0/496.0
		frame.stretch_mode=AspectRatioContainer.STRETCH_FIT
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
		_movie.add_child(frame)
		var video:=VideoStreamPlayer.new()
		video.name="AwakeningFilm"
		video.expand=true
		video.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		video.size_flags_vertical=Control.SIZE_EXPAND_FILL
		video.stream=HOSPITAL_FILM
		frame.add_child(video)
		var skip:=Button.new()
		skip.text=main.opening_text("تخطي المشهد","Skip scene")
		skip.position=Vector2(24,24)
		skip.custom_minimum_size=Vector2(150,48)
		_movie.add_child(skip)
		skip.pressed.connect(_finish_hospital_movie)
		video.finished.connect(_finish_hospital_movie)
		video.play()
	else: _finish_hospital_movie()

func _finish_hospital_movie() -> void:
	if _movie_finished: return
	_movie_finished=true
	if _movie:
		_movie.queue_free()
		_movie=null
	if not hospital.bed_awakened_done:
		_window().show_decision(main.opening_text("المستشفى","Hospital"),main.opening_text("لا تتحرك. الراحة مهمة.","Do not move. Rest is important."),[{"id":"WAKE","text":main.opening_text("افتح عينيك","Open your eyes")}],func(choice: String):
			if choice=="WAKE":
				_finish_bedside_without_unverified_pose())
	else: main._release_gameplay_modal_controls()

func is_hospital_input_blocked() -> bool:
	# Main's existing modal release hook also covers the bounded pact insert.
	# A focus pause/resume must not release movement while it owns the camera.
	if current==5 and rooms.size()>5:
		var insert=rooms[5].story_presentation
		if insert and insert.active and insert._owned_controls: return true
	return is_instance_valid(hospital) and (_movie!=null or _mark_inspection!=null or not hospital.bed_awakened_done)

func _finish_bedside_without_unverified_pose() -> void:
	hospital.wake_up_from_bed()
	main._release_gameplay_modal_controls()
	main.player.player_camera.current=true
	_capture_progress()

func _prepare_bedside_pose() -> void:
	_patient_avatar=main.player.get_node("ModelRoot/EchoOpeningUniform")
	_avatar_parent=_patient_avatar.get_parent()
	_avatar_transform=_patient_avatar.transform
	var space:=Node3D.new()
	space.position=Vector3(-1,0,0)
	hospital.add_child(space)
	_patient_avatar.reparent(space,false)
	patient=preload("res://scripts/environment/hospital_patient_recovery.gd").new()
	space.add_child(patient)
	patient.bind_existing_actor(_patient_avatar,hospital)
	for modifier in _patient_avatar.find_children("*","SkeletonModifier3D",true,false):
		_patient_modifiers[modifier]=modifier.active
		modifier.active=false
	main.player.set_physics_process(false)
	patient.begin_recovery({"pact_confirmed":true,"revenge_completed":true,"wish_confirmed":true,"transfer_completed":true,"stage":"hospital_bedside"})
	_bed_camera=Camera3D.new()
	_bed_camera.fov=43
	hospital.add_child(_bed_camera)
	_bed_camera.position=Vector3(0.8,1.8,2.4)
	_bed_camera.look_at(hospital.to_global(Vector3(-1,0.9,0)))
	_bed_camera.current=true

func _show_bedside_action(action: String) -> void:
	var message: String=main.opening_text("انهض ببطء.","Sit up slowly.") if action=="sit" else main.opening_text("تحسس عنقك. أثر التجربة لم يختفِ.","Feel your neck. The experiment's trace remains.")
	var label: String=main.opening_text("اجلس","Sit up") if action=="sit" else (main.opening_text("تحسس عنقك","Feel your neck") if action=="inspect_mark" else main.opening_text("قف بجانب السرير","Stand beside the bed"))
	_window().show_decision(main.opening_text("الاستيقاظ","Awakening"),message,[{"id":action,"text":label}],func(choice: String):
		if choice!=action or not patient or not patient.request_action(action): return
		if action=="sit":
			_bed_camera.position=Vector3(0.5,1.7,2.1)
			_bed_camera.look_at(hospital.to_global(Vector3(-1,1.0,0.4)))
			_show_bedside_action("inspect_mark")
		elif action=="inspect_mark": _show_bedside_action("stand")
		else:
			patient.restore_scope()
			_patient_avatar.reparent(_avatar_parent,false)
			_patient_avatar.transform=_avatar_transform
			for modifier in _patient_modifiers:
				if is_instance_valid(modifier): modifier.active=_patient_modifiers[modifier]
			_patient_modifiers.clear()
			main.player.set_physics_process(true)
			main.player.control_locked=false
			main.player.player_camera.current=true
			_bed_camera.queue_free()
			patient.queue_free()
			patient=null
			hospital.wake_up_from_bed()
			_capture_progress())

func _hospital_mark() -> void:
	_capture_progress()
	var next:=Checkpoint.advance(progress,"hospital")
	if not next.is_empty(): _store(next)
	_mark_inspection=preload("res://scripts/cinematics/skin_mark_inspection_camera.gd").new()
	add_child(_mark_inspection)
	if not _mark_inspection.begin(main.player.get_node("ModelRoot"),main.player.player_camera):
		_mark_inspection.queue_free()
		_mark_inspection=null
	var window:=_window()
	window.show_system_window(0,"EX-011",main.opening_text("العلامة ما زالت على عنقك.","The mark remains on your neck."),[],0)
	window.set_inspection_layout()
	window.system_window_closed.connect(_end_mark_inspection,CONNECT_ONE_SHOT)

func _end_mark_inspection(_kind:int) -> void:
	if _mark_inspection:
		_mark_inspection.restore_camera()
		_mark_inspection.queue_free()
		_mark_inspection=null
	main._release_gameplay_modal_controls()

func _refresh_objective() -> void:
	var title: String=""
	var hint: String=""
	match current:
		0:
			title=main.opening_text("غرف التجارب","Specimen wing")
			hint=main.opening_text("اعبر الممر. احتمِ من المراقبة وافحص سجل EX-011 عند الطرف الآخر.","Cross the passage. Use cover and inspect the EX-011 record at the far end.")
		1:
			title=main.opening_text("شظايا الذاكرة","Memory fragments")
			hint=main.opening_text("استعد الشظايا الثلاث على الأرض والممشى العلوي، ثم استخدم وحدة الأرشيف.","Recover the three fragments on the floor and upper walkway, then use the archive console.")
			hint+="  "+str(rooms[1].collected_shards.size())+" / 3"
		2:
			title=main.opening_text("الطاقة الاحتياطية","Reserve power")
			hint=main.opening_text("انتظر انطفاء مناطق التفريغ. اتبع ممشى الخدمة إلى القاطعين ثم الجسر.","Wait for the discharge zones to clear. Follow the service walkway to both breakers, then the bridge.")
		3:
			title=main.opening_text("الحجر الصحي","Quarantine")
			hint=main.opening_text("اصعد السلم يسار المدخل للوصول إلى وحدة تجاوز الحجر.","Use the stairs left of the entrance to reach the quarantine override.")
		4:
			title=main.opening_text("المراقبة","Surveillance")
			hint=main.opening_text("افحص المرآة. اصعد ممشى الخدمة وافتح بوابة المختبر.","Inspect the mirror. Climb the service walkway and release the laboratory gate.")
		5:
			title=main.opening_text("مختبر كينجا","Kinja's laboratory")
			hint=main.opening_text("اصعد إلى منصة الفحص واستعد ما حدث.","Reach the examination platform and recover what happened.")
			if rooms[5].confrontation_done: hint=main.opening_text("اقترب من زيرو. العقد يحتاج إلى قرارك.","Approach Zero. The pact needs your decision.")
			if rooms[5].contract_done: hint=main.opening_text("واجه كينجا؛ بعد ثلاث ضربات اقترب واقبض عليه.","Confront Kinja; after three contacts, approach and seize him.")
			if rooms[5].wish_done: hint=main.opening_text("تم قبول الأمنية. اعبر الشق المضيء.","The wish is accepted. Cross the illuminated breach.")
		_:
			title=main.opening_text("الاستيقاظ","Awakening")
			hint=main.opening_text("افحص عنقك عند المرآة.","Inspect your neck at the mirror.")
	if not save_succeeded: hint+=main.opening_text(" لم يُؤكد الحفظ."," Saving is not confirmed.")
	var signature: String=title+hint+main.presentation_language
	if signature==_ui_signature: return
	_ui_signature=signature
	main.hud.set_directive(title,hint)
