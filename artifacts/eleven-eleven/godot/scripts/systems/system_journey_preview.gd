extends Node

## Native opt-in connected traversal proof, never an accepted campaign release.
const ROOM = preload("res://scenes/environment/maintenance_vertical.tscn")
const SAVE_SCHEMA := "echo-maintenance-preview-v1"
@export var checkpoint_path := "user://maintenance_preview_v1.json"
var main: Node
var room: Node3D
var stage := 0
var _language := ""
var _reduced := false
var _retry_anchor := Vector3(0, 0.1, -20)
var _save_ready := false
var save_succeeded := false

func _ready() -> void:
	main = get_parent()

func _process(_delta: float) -> void:
	if not main.opening_web_handoff.reported_milestones.has("memory_scene_completed"): return
	if not room:
		room = ROOM.instantiate()
		room.position = Vector3(0, 0, -18)
		main.add_child(room)
		# The opening deliberately retains its end boundary. Only this opt-in
		# continuation releases it, after the authored ending has completed.
		var gate = main.find_child("PrimaryBlastGate", true, false)
		gate.keep_collision_when_open = false
		gate.get_collision_shape().set_deferred("disabled", true)
		room.set_reduced_motion(main.reduced_motion)
		main.player.surface_traversal_enabled = true
		main.player.surface_motor.mantle_completed.connect(_on_mantle)
		_restore()
		_language = ""
	if main.presentation_language != _language:
		_language = main.presentation_language
		refresh_objective()
	if main.reduced_motion != _reduced:
		_reduced = main.reduced_motion
		room.set_reduced_motion(_reduced)
	var player: EchoPlayer = main.player
	if main.companion:
		# Keep the guide clear of the wrist/ledge contact and the climbing camera.
		main.companion.float_offset = Vector3(1.1,1.45,0.9) if player.traversal.is_climbing() else Vector3(0.45,1.8,0.25)
	var local: Vector3 = room.to_local(player.global_position)
	if stage == 0 and local.z < -2.0:
		_advance(1, Vector3(0, 0.1, -20))
	elif stage == 2 and player.is_on_floor() and local.x > 3.0 and local.y > 3.1 and local.z < -6.0:
		_advance(3, Vector3(4, 3.5, -25))
	elif stage == 4 and player.is_on_floor() and local.z < -11.7 and local.y > 5.1:
		_advance(5, Vector3(2.3, 5.5, -30.3))
	if stage > 0 and (local.y < -1.0 or absf(local.x) > 6.0 or local.z < -15.0 or (stage >= 2 and local.y < 0.6)):
		player.surface_motor.reset(player)
		player.global_position = _retry_anchor
		player.velocity = Vector3.ZERO
		player.stamina = player.MAX_STAMINA
		refresh_objective()
	if _save_ready and player.is_on_floor() and player.global_position.distance_to(_retry_anchor) < 1.0:
		_save_ready = false
		save_succeeded = _save()
		if stage == 5: refresh_objective()

func _on_mantle() -> void:
	var local: Vector3 = room.to_local(main.player.global_position)
	if stage == 1 and local.y > 3.2 and local.z < -5.5:
		_advance(2, Vector3(0, 3.5, -24.5))
	elif stage == 3 and local.y > 5.2 and local.x > 3.0:
		_advance(4, Vector3(4, 5.5, -28.4))

func _advance(next: int, anchor: Vector3) -> void:
	stage = next
	_retry_anchor = anchor
	_save_ready = true
	refresh_objective()

func refresh_objective() -> void:
	var titles := ["طريق الصيانة", "الجدار الأول", "اعبر الفجوة", "الصعود الثاني", "الممر المرتفع", "وصلت إلى منفذ الخدمة"]
	var titles_en := ["Maintenance route", "First climb", "Cross the gap", "Second ascent", "Upper passage", "Service access reached"]
	var hints := ["اعبر البوابة المفتوحة واتبع العلامات نحو جدار الصيانة.", "تقدم نحو السطح ذي المقابض واضغط القفز للتسلق. عند الحافة: تقدم مع القفز للصعود، أو المراوغة للإفلات.", "اتجه يميناً. اركض واقفز إلى المنصة المقابلة؛ السقوط يعيدك إلى الاستراحة.", "تقدم نحو المقابض وتسلق الجدار إلى الاستراحة الثانية.", "اتبع الممر العلوي إلى المنفذ. يمكنك التوقف لاستعادة التحمل.", "أتممت طريق الصيانة. حُفظت نقطة الاستراحة."]
	var hints_en := ["Cross the open gate and follow the markers to the maintenance wall.", "Move toward the grips and press Jump to climb. At the ledge: forward + Jump to mantle, Dodge to drop.", "Turn right. Run and jump to the opposite platform; a fall returns you to the rest ledge.", "Move toward the grips and climb to the second rest ledge.", "Follow the upper passage to service access. Rest to recover stamina.", "Maintenance route completed. Rest checkpoint saved."]
	if stage == 5 and not save_succeeded:
		hints[5] = "وصلت إلى منفذ الخدمة. تعذر تأكيد حفظ التقدم."
		hints_en[5] = "Service access reached. Checkpoint saving could not be confirmed."
	main.hud.set_directive(main.opening_text(titles[stage], titles_en[stage]), main.opening_text(hints[stage], hints_en[stage]))

func _save() -> bool:
	var data := {"schema": SAVE_SCHEMA, "stage": stage}
	var temporary := checkpoint_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if not file: return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	# Recovery copy is promoted only from a validated previous checkpoint.
	if _read(checkpoint_path) >= 0:
		DirAccess.copy_absolute(checkpoint_path, checkpoint_path + ".bak")
	return DirAccess.rename_absolute(temporary, checkpoint_path) == OK

func _read(path: String) -> int:
	if not FileAccess.file_exists(path): return -1
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return -1
	var data = parser.data
	if not data is Dictionary or data.get("schema") != SAVE_SCHEMA: return -1
	var value = data.get("stage")
	if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)) or value < 0 or value > 5: return -1
	return int(value)

func _restore() -> void:
	var saved := _read(checkpoint_path)
	if saved < 0: saved = _read(checkpoint_path + ".bak")
	if saved < 1: return
	stage = saved
	save_succeeded = true
	var anchors := [Vector3(0,0.1,-20), Vector3(0,0.1,-20), Vector3(0,3.5,-24.5), Vector3(4,3.5,-25), Vector3(4,5.5,-28.4), Vector3(2.3,5.5,-30.3)]
	_retry_anchor = anchors[stage]
	main.player.surface_motor.reset(main.player)
	main.player.global_position = _retry_anchor
	main.player.velocity = Vector3.ZERO
	main.player.stamina = main.player.MAX_STAMINA
