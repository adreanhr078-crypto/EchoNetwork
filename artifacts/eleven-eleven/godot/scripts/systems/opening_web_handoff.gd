extends Node
class_name OpeningWebHandoff

## Presentation telemetry only. Server receipts are never created in Godot.
signal milestone_recorded(milestone_id: String)

const BRIDGE_VERSION := 1
const SOURCE := "11-11-godot"
const WEB_SOURCE := "11-11-web"
# Browser identity must be checked on the native JS objects, not Godot wrappers.
const PARENT_EVENT_PREDICATE := "return event.source === window.parent;"
const ALLOWED_MILESTONES := [
	"wake_completed",
	"terminal_aligned",
	"conduit_energized",
	"gate_revealed",
	"chapter_boundary_seen",
	"room_entered",
	"clock_inspected",
	"photo_inspected",
	"memory_recovered",
	"puzzle_solved",
	"door_unlocked",
	"memory_scene_completed",
]

var reported_milestones: Array[String] = []
var _window = null
var _message_callback = null
var _parent_event_predicate = null
var _session_nonce := ""

func _ready() -> void:
	if not OS.has_feature("web"):
		return
	_window = JavaScriptBridge.get_interface("window")
	if _window == null:
		return
	_parent_event_predicate = JavaScriptBridge.create_object("Function", "event", PARENT_EVENT_PREDICATE)
	if _parent_event_predicate == null:
		return
	_message_callback = JavaScriptBridge.create_callback(_on_browser_message)
	_window.addEventListener("message", _message_callback)
	_post_event("ready", {})

func _exit_tree() -> void:
	if _window != null and _message_callback != null:
		_window.removeEventListener("message", _message_callback)
	_message_callback = null
	_parent_event_predicate = null
	_window = null

func report_milestone(milestone_id: String) -> bool:
	if not ALLOWED_MILESTONES.has(milestone_id) or reported_milestones.has(milestone_id):
		return false
	reported_milestones.append(milestone_id)
	milestone_recorded.emit(milestone_id)
	_post_event("milestone", {"milestoneId": milestone_id})
	return true

func _on_browser_message(args: Array) -> void:
	if args.is_empty() or _window == null:
		return
	var event = args[0]
	if _parent_event_predicate == null or _parent_event_predicate.call(null, event) != true:
		return
	if str(event.origin) != str(_window.location.origin) or not (event.data is String):
		return
	var data = JSON.parse_string(event.data)
	if not (data is Dictionary):
		return
	_apply_configuration(data)

func _apply_configuration(data: Dictionary) -> void:
	if data.get("source") != WEB_SOURCE or data.get("type") != "configure" or data.get("bridgeVersion") != BRIDGE_VERSION:
		return
	var nonce = data.get("nonce", "")
	if not (nonce is String) or nonce.is_empty() or data.get("coverVerified") != true:
		return
	var main = get_parent()
	var language = data.get("locale")
	if main and main.has_method("is_web_configuration_pending") and main.is_web_configuration_pending():
		if not (language is String) or language not in ["ar", "en"] or not (data.get("muted") is bool) or not (data.get("reducedMotion") is bool):
			return
	_session_nonce = nonce
	if main and language is String and language in ["ar", "en"] and main.has_method("set_presentation_language"):
		main.set_presentation_language(language)
	if main and data.get("muted") is bool and main.has_method("set_audio_muted"):
		main.set_audio_muted(data.muted)
	if main and data.get("reducedMotion") is bool and main.has_method("set_reduced_motion"):
		main.set_reduced_motion(data.reducedMotion)
	if main and main.has_method("complete_web_configuration"):
		main.complete_web_configuration()
	_post_event("configured", {"milestones": reported_milestones.duplicate()})

func _post_event(event_type: String, details: Dictionary) -> void:
	if _window == null or (event_type != "ready" and _session_nonce.is_empty()):
		return
	var payload := {
		"source": SOURCE,
		"bridgeVersion": BRIDGE_VERSION,
		"type": event_type,
		"nonce": _session_nonce,
	}
	payload.merge(details)
	var encoded: String = JSON.stringify(payload)
	JavaScriptBridge.eval("window.parent.postMessage(" + JSON.stringify(encoded) + ", " + JSON.stringify(str(_window.location.origin)) + ")", true)
