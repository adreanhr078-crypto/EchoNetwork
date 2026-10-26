extends CanvasLayer

## Entry-only transport. All account rewards remain server-authoritative.
## No code, verifier, receipt or authenticated account token is written to disk.
signal entry_confirmed(receipt_id: String)
var origin := ""
var language := "ar"
var window: Control
var request: HTTPRequest
var _verifier := ""
var _busy := false
var _status := ""

static func valid_origin(value: String, local_review := false) -> bool:
	var pattern := RegEx.new()
	pattern.compile("^https://[A-Za-z0-9][A-Za-z0-9.-]*(?::[0-9]{1,5})?$")
	return pattern.search(value) != null or (local_review and value == "http://127.0.0.1:8798")

static func encode(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+","-").replace("/","_").replace("=","")

func _ready() -> void:
	layer=90
	var background:=ColorRect.new()
	background.color=Color(.012,.009,.014)
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window=preload("res://scenes/ui/system_window.tscn").instantiate()
	add_child(window)
	window.reduced_motion=true
	request=HTTPRequest.new()
	request.timeout=12
	request.body_size_limit=16384
	request.max_redirects=0
	add_child(request)
	request.request_completed.connect(_response)
	_new_connection()

func _text(ar: String,en: String) -> String: return ar if language=="ar" else en

func _new_connection() -> void:
	_verifier=encode(Crypto.new().generate_random_bytes(32))
	_status=""
	_present()

func browser_url() -> String:
	return origin+"/?native_challenge="+encode(_verifier.sha256_buffer())+"#/opening-recovery"

func _present() -> void:
	window.set_presentation_language(language)
	var message:=_text("افتح الموقع وأكمل لغز الغلاف بحسابك. انسخ رمز الربط ثم عُد إلى هنا واضغط «لصق الرمز». لن تحتاج إلى نسخ كلمة مرور أو رمز تسجيل الدخول.","Open the website and complete the cover puzzle with your account. Copy the connection code, return here and choose “Paste code”. You never need to copy a password or sign-in token.")
	if not _status.is_empty(): message+="\n\n"+_status
	window.show_decision(_text("قناة إيكو","Echo's channel"),message,[
		{"id":"OPEN","text":_text("فتح الموقع","Open website")},
		{"id":"PASTE","text":_text("لصق الرمز","Paste code")},
		{"id":"NEW","text":_text("اتصال جديد","New connection")},
		{"id":"LANGUAGE","text":"English" if language=="ar" else "العربية"}
	],_choose)
	window.set_inspection_layout()

func _choose(choice: String) -> void:
	if _busy: return
	if choice=="LANGUAGE": language="en" if language=="ar" else "ar"
	elif choice=="NEW":
		_new_connection()
		return
	elif choice=="OPEN":
		if valid_origin(origin,OS.is_debug_build()):
			if OS.shell_open(browser_url())!=OK: _status=_text("تعذر فتح المتصفح. أعد المحاولة.","The browser could not open. Try again.")
		else: _status=_text("عنوان الخدمة غير مهيأ. يلزم إعداد نسخة الإصدار.","The service address is not configured. This build needs release configuration.")
	elif choice=="PASTE":
		_submit(DisplayServer.clipboard_get().strip_edges())
		return
	_present()

func _submit(code: String) -> void:
	# The displayed code is LTR. Remove only known presentation direction marks
	# from manual clipboard copies; every other unexpected character is rejected.
	for point in [0x200e,0x200f,0x202a,0x202b,0x202c,0x202d,0x202e,0x2066,0x2067,0x2068,0x2069]:
		code=code.replace(String.chr(point),"")
	code=code.strip_edges()
	var pattern:=RegEx.new()
	pattern.compile("^[A-Za-z0-9_-]{43}$")
	if not valid_origin(origin,OS.is_debug_build()) or pattern.search(code)==null:
		_status=_text("انسخ رمز الربط من الموقع بعد إكمال لغز الغلاف، ثم أعد اللصق.","Copy the connection code from the website after completing the cover puzzle, then paste again.")
		_present()
		return
	_busy=true
	window.show_system_window(0,_text("جارٍ الاتصال…","Connecting…"),_text("جارٍ التحقق من القناة. يمكنك إعادة المحاولة إذا تعذر الاتصال.","Verifying the channel. You can retry if the connection fails."),[],0)
	window.confirm_btn.hide()
	var result:=request.request(origin+"/api/player/native-entry/exchange",PackedStringArray(["Content-Type: application/json"]),HTTPClient.METHOD_POST,JSON.stringify({"code":code,"verifier":_verifier}))
	if result!=OK: _response(-1,0,PackedStringArray(),PackedByteArray())

func _response(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy=false
	var data: Variant=JSON.parse_string(body.get_string_from_utf8())
	if result==HTTPRequest.RESULT_SUCCESS and status==200 and data is Dictionary and data.get("scope")=="native-chapter-entry" and data.get("entryConfirmed")==true and data.get("coverReceiptId") is String and not data.coverReceiptId.is_empty():
		_verifier=""
		entry_confirmed.emit(data.coverReceiptId)
		return
	_status=_text("تعذر تثبيت الربط. قد يكون الرمز انتهى أو استُعمل؛ أنشئ رمزًا جديدًا من الموقع. اتصال جديد في اللعبة يحتاج رمزًا جديدًا.","The connection could not be confirmed. The code may have expired or been used; create a new code on the website. A new game connection needs a new code.")
	_present()

func _exit_tree() -> void:
	_verifier=""
	if is_instance_valid(request): request.cancel_request()
