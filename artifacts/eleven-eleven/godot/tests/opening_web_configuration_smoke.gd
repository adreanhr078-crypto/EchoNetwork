extends SceneTree

const Handoff = preload("res://scripts/systems/opening_web_handoff.gd")
const Main = preload("res://scripts/main.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	# Instantiate the real localization owner without starting a game scene.
	var main = Main.new()
	var handoff = Handoff.new()
	main.add_child(handoff)
	var configuration = {"source": "11-11-web", "type": "configure", "bridgeVersion": 1, "nonce": "configuration-review", "coverVerified": true, "locale": "en"}
	handoff._apply_configuration(configuration)
	assert(main.presentation_language == "en", "Configured English did not reach the real localization owner")
	assert(main.opening_text("عربي", "English") == "English")
	assert(handoff._session_nonce == "configuration-review")
	configuration.locale = "ar"
	handoff._apply_configuration(configuration)
	assert(main.presentation_language == "ar", "Live Arabic reconfiguration did not reach the localization owner")
	assert(main.opening_text("عربي", "English") == "عربي")
	for invalid_language in ["fr", "", 7, null, ["en"]]:
		configuration.locale = invalid_language
		handoff._apply_configuration(configuration)
		assert(main.presentation_language == "ar", "Unsupported locale changed presentation")
	configuration.erase("locale")
	handoff._apply_configuration(configuration)
	assert(main.presentation_language == "ar", "Legacy configure without locale changed presentation")
	configuration.locale = "en"
	for invalid_field in [{"source": "foreign"}, {"type": "milestone"}, {"bridgeVersion": 2}, {"nonce": ""}, {"coverVerified": false}]:
		var rejected = configuration.duplicate()
		rejected.merge(invalid_field, true)
		handoff._apply_configuration(rejected)
		assert(main.presentation_language == "ar", "Invalid configuration changed presentation")
	main.free()
	print("PASS opening web configuration: real ar/en localization, live switch, unsupported/missing locale, protocol/receipt/nonce rejection")
	quit(0)
