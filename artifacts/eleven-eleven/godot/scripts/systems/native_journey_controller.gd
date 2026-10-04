extends Node

## One native route owner. Legacy boss/timer progression stays dormant.
signal progress_changed(completed: Array)
const Checkpoint = preload("res://scripts/systems/native_journey_checkpoint.gd")
const SECURITY_ROOM = preload("res://scenes/environment/security_checkpoint_room.tscn")
const SECURITY_ANCHOR := Vector3(0, 5.5, -31.9)
const SECURITY_ORIGIN := Vector3(0,5.4,-32)
@export var checkpoint_path := Checkpoint.PATH
var main: Node
var maintenance: Node
var security: Node3D
var progress := Checkpoint.initial()
var security_entered := false
var save_succeeded := true
var _loaded := false
var _restored := false
var _retry_after := 0.0
var _language := ""
var _pending_security_completion := false

func _ready() -> void:
	main = get_parent()
	maintenance = main.get_node("SystemJourneyPreview")
	maintenance.stage_changed.connect(_on_maintenance_stage_changed)
	maintenance.room_ready.connect(_on_room_ready)

func _process(delta: float) -> void:
	_retry_after = maxf(0.0, _retry_after - delta)
	if not main.opening_web_handoff.reported_milestones.has("memory_scene_completed"): return
	if not _loaded:
		_loaded = true
		var saved := Checkpoint.load_checkpoint(checkpoint_path)
		if not saved.is_empty(): progress = saved
	if progress.completed.is_empty() and _retry_after <= 0: _commit("opening_completed")
	if not maintenance.room: return
	_ensure_security()
	_restore_anchor()
	if maintenance.stage == 7 and progress.completed.size() == 1 and _retry_after <= 0: _commit("maintenance_completed")
	if security_entered:
		security.set_language(main.presentation_language)
		security.set_audio_muted(main.audio_muted)
		security.reduced_motion = main.reduced_motion
		main.hud.find_child("MobileTouchControls",true,false).set_traversal_active(main.player.traversal.is_climbing())
		if security.get_state() != progress.security and _retry_after <= 0:
			_store(Checkpoint.with_security(progress, security.get_state()))
		if _pending_security_completion and _retry_after <= 0 and security.get_state() == progress.security:
			if _commit("security_completed"): _pending_security_completion = false
	if main.presentation_language != _language or not save_succeeded:
		_language = main.presentation_language
		if maintenance.stage == 7: refresh_objective()

func _physics_process(_delta: float) -> void:
	if not _loaded or not maintenance.room or maintenance.stage != 7 or security_entered: return
	var player: EchoPlayer = main.player
	var local: Vector3 = maintenance.room.to_local(player.global_position)
	if progress.completed.size() == 2 and _retry_after <= 0 and not player.control_locked and player.is_on_floor() and absf(local.x) < 0.7 and local.y > 5.1 and local.y < 5.9 and local.z <= -13.82 and local.z > -14.3:
		if _commit("security_entered"):
			_activate_security()
			refresh_objective()

func _ensure_security() -> void:
	if security: return
	security = SECURITY_ROOM.instantiate()
	security.position = SECURITY_ORIGIN
	main.add_child(security)
	security.passage_ready.connect(func(): _pending_security_completion = true)
	security.discovery_observed.connect(func(_id: String): refresh_objective())
	security.warning_changed.connect(func(_amount: float): refresh_objective())
	security.retry_requested.connect(_retry_security)
	security.restore_state(progress.security)
	_open_maintenance_aperture()

func _open_maintenance_aperture() -> void:
	# The original preview backstop is retained outside a 1.8m service opening.
	# Only this campaign adapter releases it; the isolated maintenance scene stays intact.
	var boundary := maintenance.room.get_node("COLL_FarBoundary") as StaticBody3D
	boundary.get_child(0).set_deferred("disabled",true)
	for spec in [{"x":-2.7,"width":3.6},{"x":3.2,"width":4.6}]:
		var pier := StaticBody3D.new()
		pier.name = "CampaignServiceAperturePier"
		pier.position = Vector3(spec.x,5.3,-14.5)
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(spec.width,10.6,0.4)
		collider.shape = shape
		pier.add_child(collider)
		maintenance.room.add_child(pier)

func _activate_security() -> void:
	security_entered = true
	maintenance.set_process(false)
	security.player = main.player
	main.player.surface_traversal_enabled = true
	if main.companion: main.companion.float_offset = Vector3(1.1,1.8,0.9)

func _retry_security(anchor: Vector3) -> void:
	if not security_entered: return
	main.player.surface_motor.reset(main.player)
	main.player.global_position = anchor
	main.player.velocity = Vector3.ZERO
	main.player.stamina = main.player.MAX_STAMINA
	refresh_objective()

func _on_room_ready() -> void: _restore_anchor()

func _restore_anchor() -> void:
	if not _loaded or _restored or not maintenance.room: return
	_ensure_security()
	_restored = true
	if progress.completed.size() < 2: return
	maintenance.stage = 7
	maintenance.room.restore_service_open()
	maintenance.save_succeeded = true
	maintenance._save_ready = false
	security_entered = progress.completed.size() >= 3
	maintenance._retry_anchor = SECURITY_ANCHOR if security_entered else Vector3(0, 5.5, -31.6)
	main.player.surface_motor.reset(main.player)
	main.player.global_position = SECURITY_ORIGIN + Vector3(0,0.1,-17.4) if progress.completed.size() >= 4 else maintenance._retry_anchor
	main.player.velocity = Vector3.ZERO
	main.player.stamina = main.player.MAX_STAMINA
	if security_entered: _activate_security()
	refresh_objective()

func _on_maintenance_stage_changed(value: int) -> void:
	if value == 7:
		if _loaded and progress.completed.size() == 1: _commit("maintenance_completed")
		refresh_objective()

func _commit(event: String) -> bool:
	if not _loaded or not main.opening_web_handoff.reported_milestones.has("memory_scene_completed"): return false
	if event == "maintenance_completed" and (not maintenance.room or maintenance.stage != 7 or not maintenance.room.service_open): return false
	if event == "security_completed":
		if not security or not security_entered or not security.gate_open or not main.player.is_on_floor(): return false
		var local: Vector3 = security.to_local(main.player.global_position)
		if local.z >= -17 or absf(local.x) >= 0.8 or main.player.control_locked: return false
	return _store(Checkpoint.advance(progress, event))

func _store(next: Dictionary) -> bool:
	if next.is_empty(): return false
	if next == progress: return true
	save_succeeded = Checkpoint.save_checkpoint(next, checkpoint_path)
	if not save_succeeded:
		_retry_after = 1.0
		refresh_objective()
		return false
	progress = next
	security_entered = progress.completed.size() >= 3
	progress_changed.emit(progress.completed.duplicate())
	refresh_objective()
	return true

func refresh_objective() -> void:
	if not main or not main.hud or not maintenance or maintenance.stage != 7: return
	var title: String = main.opening_text("خلف منفذ الخدمة", "Beyond service access")
	var hint: String = main.opening_text("اعبر فسحة الخدمة نحو الحاجز الأمني.", "Cross the service landing toward the security barrier.")
	if security_entered and security:
		title = main.opening_text("اعبر المراقبة", "Pass surveillance")
		hint = main.opening_text("حوّل الإشارة يسار المدخل واتبع الحواجز، أو تسلق طريق الخدمة يميناً. القفل اليدوي عند الحاجز.", "Divert the signal by the left entrance and use cover, or climb the service path on the right. Release the manual latch at the barrier.")
		if security.warning > 0.2:
			hint = main.opening_text("المراقبة ترصدك. احتمِ خلف حاجز أو اخرج من شعاعها.", "Surveillance sees you. Move behind cover or out of its beam.")
		elif security.gate_open:
			hint = main.opening_text("الحاجز مفتوح. اعبر نحو غرف التجارب.", "The barrier is open. Cross toward the experiment rooms.")
		if progress.completed.size() >= 4:
			title = main.opening_text("خلف المراقبة", "Beyond surveillance")
			hint = main.opening_text("أتممت طريق الأمن. غرف التجارب أمامك؛ المدخل التالي قيد التجهيز.", "Security route completed. The experiment rooms are ahead; the next entry is being prepared.")
	if not save_succeeded: hint += main.opening_text(" لم يُؤكد الحفظ؛ نقطة الاستعادة السابقة محفوظة.", " Saving is not confirmed; the previous recovery point is retained.")
	main.hud.set_directive(title, hint)
