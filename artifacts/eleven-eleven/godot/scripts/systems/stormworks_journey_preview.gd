extends Node

## Room progress follows actual contacts/landings and confirmed local saves.
signal stage_changed(value: int)
signal room_ready
const ROOM = preload("res://scenes/environment/maintenance_stormworks.tscn")
const SERVICE_CINEMATIC = preload("res://scripts/cinematics/maintenance_service_cinematic.gd")
const Route = preload("res://scripts/systems/stormworks_route.gd")
const Checkpoint = preload("res://scripts/systems/stormworks_checkpoint.gd")
@export var checkpoint_path := "user://maintenance_preview_v1.json"
@export var campaign_continuation := true
var main: Node
var room: Node3D
var service_cinematic: Node
var stage := 0
var course_step := 0
var save_succeeded := false
var _save_ready := false
var _retry_anchor := Vector3.ZERO
var _save_retry_after := 0.0
var _pending_landing := -1
var _pending_vault := false
var _language := ""
var _reduced := false

func _ready() -> void:main = get_parent()

func _create_room() -> void:
	room = ROOM.instantiate()
	room.position = Vector3(0,0,-18)
	main.add_child(room)
	var gate = main.find_child("PrimaryBlastGate",true,false)
	gate.keep_collision_when_open = false
	gate.get_collision_shape().set_deferred("disabled",true)
	main.player.surface_traversal_enabled = true
	main.player.surface_motor.mantle_completed.connect(_on_mantle)
	main.player.surface_motor.vault_completed.connect(_on_vault)
	main.player.landing_executed.connect(_on_landing)
	main.player.landing_executed.connect(func(speed: float,_heavy: bool):room.presentation.react_to_landing(main.player.global_position,speed))
	room.service_opened.connect(_on_service_opened)
	room.service_release_started.connect(refresh_objective)
	service_cinematic = SERVICE_CINEMATIC.new()
	service_cinematic.main = main
	service_cinematic.room = room
	add_child(service_cinematic)
	room.service_release_started.connect(service_cinematic.start)
	_retry_anchor = room.to_global(Route.anchor(0,0))
	_restore()
	room_ready.emit()

func _process(delta: float) -> void:
	if not main.opening_web_handoff.reported_milestones.has("memory_scene_completed"):return
	if not room:_create_room()
	_save_retry_after = maxf(0,_save_retry_after-delta)
	if _language != main.presentation_language:
		_language = main.presentation_language
		room.set_language(_language)
		refresh_objective()
	if _reduced != main.reduced_motion:
		_reduced = main.reduced_motion
		room.set_reduced_motion(_reduced)
	room.presentation.set_audio_muted(main.audio_muted)
	var player: EchoPlayer = main.player
	var point: Vector3 = room.to_local(player.global_position)
	room.presentation.set_presence(absf(point.x)<9.3 and point.z<.6 and point.z> -19.8)
	main.hud.find_child("MobileTouchControls",true,false).set_traversal_active(player.traversal.is_climbing())
	if main.companion:
		var at_wheel: bool = player.get_nearest_interactable() == room.service_interaction
		main.companion.float_offset = Vector3(-1.1,1.95,-.6) if at_wheel or room.service_opening or service_cinematic.active else Vector3(.45,1.8,.25)
	if stage == 0 and point.z < -3.2 and player.is_on_floor():_advance(1)
	if stage == 2 and _pending_landing == course_step and player.is_on_floor() and Route.GAP_SAFE[course_step].has_point(point):
		course_step += 1
		_pending_landing = -1
		if course_step == 3:_advance(3)
		else:_checkpoint_here()
	if stage == 3 and _pending_vault and player.is_on_floor() and Route.VAULT_LANDING.has_point(point):
		_pending_vault = false
		_advance(4)
	if stage == 6 and room.service_open and has_confirmed_room_checkpoint() and player.is_on_floor() and Route.EXIT_REGION.has_point(point):_advance(7)
	room.service_allowed = stage == 5 and has_confirmed_room_checkpoint()
	if stage > 0 and (point.y < -.18 or absf(point.x)>9.4 or point.z < -20.2):
		_pending_landing = -1
		_pending_vault = false
		player.surface_motor.reset(player)
		player.global_position = _retry_anchor
		player.velocity = Vector3.ZERO
		player.stamina = player.MAX_STAMINA
		refresh_objective()
	if _save_ready and _save_retry_after <= 0 and player.is_on_floor() and player.global_position.distance_to(_retry_anchor)<1:
		save_succeeded = _save()
		_save_ready = not save_succeeded
		_save_retry_after = 0 if save_succeeded else 1
		refresh_objective()

func _on_landing(_speed: float,_heavy: bool) -> void:
	if stage != 2:return
	var point: Vector3 = room.to_local(main.player.global_position)
	if Route.GAP_BROAD[course_step].has_point(point):_pending_landing = course_step

func _on_vault() -> void:
	if stage == 3:_pending_vault = true

func _on_mantle() -> void:
	var point: Vector3 = room.to_local(main.player.global_position)
	if stage == 1 and Route.FIRST_MANTLE.has_point(point):_advance(2)
	elif stage == 4 and Route.FINAL_MANTLE.has_point(point):_advance(5)

func _on_service_opened() -> void:
	if stage == 5:_advance(6)

func _advance(next: int) -> void:
	stage = next
	_checkpoint_here()
	stage_changed.emit(stage)

func _checkpoint_here() -> void:
	_retry_anchor = room.to_global(Route.anchor(stage,course_step))
	_save_ready = true
	save_succeeded = false
	refresh_objective()

func _save() -> bool:
	return Checkpoint.save_checkpoint({"schema":Checkpoint.SCHEMA,"layout_revision":Route.REVISION,"stage":stage,"course_step":course_step},checkpoint_path)

func _restore() -> void:
	var state := Checkpoint.load_checkpoint(checkpoint_path)
	if state.is_empty() or state.stage == 0:return
	stage = state.stage
	course_step = state.course_step
	_retry_anchor = room.to_global(Route.anchor(stage,course_step))
	main.player.surface_motor.reset(main.player)
	main.player.global_position = _retry_anchor
	main.player.velocity = Vector3.ZERO
	main.player.stamina = main.player.MAX_STAMINA
	save_succeeded = true
	if stage >= 6:room.restore_service_open()

func restore_completed_route() -> void:
	stage = 7
	course_step = 3
	save_succeeded = true
	_save_ready = false
	_retry_anchor = room.to_global(Route.anchor(7,3))
	room.restore_service_open()

func has_confirmed_room_checkpoint() -> bool:return save_succeeded and not _save_ready
func get_security_origin() -> Vector3:return Route.SECURITY_LOCAL_ORIGIN
func get_completed_room_anchor() -> Vector3:return room.to_global(Route.anchor(7,3))
func is_security_handoff_ready(player: EchoPlayer) -> bool:
	return stage == 7 and has_confirmed_room_checkpoint() and not player.control_locked and player.is_on_floor() and Route.HANDOFF_REGION.has_point(room.to_local(player.global_position))

func refresh_objective() -> void:
	if not room:return
	room.presentation.set_route_stage(stage)
	var titles := ["حوض الضغط","القبضة الأولى","اعبر المنصات","حاجز الصيانة","القبضة الأخيرة","نفّس الضغط","اعبر منفذ الخدمة","نحو المراقبة"]
	var english := ["Pressure chamber","First grip","Cross the platforms","Maintenance vault","Final grip","Vent the pressure","Cross service access","Toward surveillance"]
	var hints := ["اتبع منصة الدخول نحو الحافة ذات القضبان.","اقفز نحو الوجه المعدني؛ عند التعلق اضغط القفز للصعود.","اكتسب سرعة على المنصة ثم وجّه قفزتك للمنصة التالية.","اتجه إلى امتداد المنصة أمام الحاجز، واجهه ثم اضغط القفز لتجاوزه.","اتبع القضبان على وجه الجسر واصعد بقبضة قصيرة.","تفاعل مع عجلة الضغط يمين الباب.","ابتعد عن العجلة واعبر الباب المفتوح.","تقدم نحو ممر المراقبة."]
	var hints_en := ["Follow the entry deck toward the marked grip.","Jump toward the metal face;press Jump while hanging to mantle.","Build speed on the platform,then aim your jump toward the next landing.","Use the front apron,face the obstacle,and press Jump to vault it.","Follow the bridge-face rails and make the final short climb.","Interact with the pressure wheel to the right of the door.","Leave the wheel and cross the open door.","Continue toward the surveillance passage."]
	if stage == 2:
		hints[2] = ["اقفز قطريًا إلى المنصة اليسرى.","اقفز إلى المنصة التالية للأمام.","اقفز صعودًا إلى يمين الاستراحة الكبيرة."][course_step]
		hints_en[2] = ["Jump diagonally to the left platform.","Jump forward to the next platform.","Make the rising jump to the right side of the large deck."][course_step]
	if not has_confirmed_room_checkpoint() and stage >= 5:
		hints[stage] += " انتظر تأكيد نقطة الحفظ قبل متابعة المنفذ."
		hints_en[stage] += " Wait for checkpoint confirmation before continuing through the access."
	if room.service_opening:
		hints[5] = "جارٍ تنفيس الضغط ورفع الحاجز…"
		hints_en[5] = "Venting pressure and lifting the barrier…"
	main.hud.set_directive(main.opening_text(titles[stage],english[stage]),main.opening_text(hints[stage],hints_en[stage]))
