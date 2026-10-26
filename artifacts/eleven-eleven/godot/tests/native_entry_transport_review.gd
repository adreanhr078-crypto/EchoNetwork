extends SceneTree

const Gate=preload("res://scripts/systems/native_entry_gate.gd")
var gate: CanvasLayer
var bootstrap: HTTPRequest
var confirmed := false
var failures := 0
var response_seen := false

func _initialize() -> void: _run.call_deferred()
func check(value: bool,message: String) -> void:
	if not value: failures+=1; push_error(message)

func _run() -> void:
	root.size=Vector2i(960,540)
	check(Gate.valid_origin("https://echo.example"),"HTTPS origin rejected")
	for invalid in ["http://echo.example","https://echo.example/path","https://evil@echo.example","https://echo.example?token=x","http://127.0.0.1:8798"]:
		check(not Gate.valid_origin(invalid),"Release accepted invalid origin "+invalid)
	gate=Gate.new()
	gate.origin="http://127.0.0.1:8798"
	root.add_child(gate)
	gate.entry_confirmed.connect(func(receipt: String): confirmed=receipt=="local-review-receipt")
	for i in 4: await process_frame
	check(gate.browser_url().contains("native_challenge=") and not gate.browser_url().contains(gate._verifier),"URL exposed verifier")
	for language in ["ar","en"]:
		gate.language=language
		gate._present()
		for i in 4: await process_frame
		for button in gate.window.stats_box.get_children():
			check(root.get_visible_rect().encloses(button.get_global_rect()),"Entry control clipped: "+button.text)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../audits/evidence/pre-tripo-20261018/cp37/native-entry-"+language+".png")
	gate._submit("malformed")
	check(not gate._busy and not confirmed and gate.window.visible,"Malformed code trapped or granted entry")
	bootstrap=HTTPRequest.new()
	root.add_child(bootstrap)
	bootstrap.timeout=10
	bootstrap.request_completed.connect(_bootstrap)
	var result:=bootstrap.request(gate.origin+"/review/issue",["Content-Type: application/json"],HTTPClient.METHOD_POST,JSON.stringify({"challenge":Gate.encode(gate._verifier.sha256_buffer())}))
	check(result==OK,"Local fixture request failed")
	var deadline:=Time.get_ticks_msec()+15000
	while not response_seen and Time.get_ticks_msec()<deadline: await process_frame
	check(response_seen,"Fixture response timed out")
	while not confirmed and gate._busy and Time.get_ticks_msec()<deadline: await process_frame
	check(confirmed and not gate._busy and gate._verifier.is_empty(),"Real Godot HTTP/SQL exchange did not confirm and clear verifier")
	print("Native entry transport failures=",failures,"; LOCAL fixture issuance; real HTTP + production exchange handler + SQLite; no live Firebase/deployment claim")
	quit(1 if failures else 0)

func _bootstrap(result: int,status: int,_headers: PackedStringArray,body: PackedByteArray) -> void:
	response_seen=true
	var data: Variant=JSON.parse_string(body.get_string_from_utf8())
	check(result==HTTPRequest.RESULT_SUCCESS and status==200 and data is Dictionary and data.has("code"),"Local fixture could not issue grant")
	if data is Dictionary and data.has("code"): gate._submit("\u2066"+data.code+"\u2069\n")
