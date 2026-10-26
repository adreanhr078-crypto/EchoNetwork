extends SceneTree

const Save = preload("res://scripts/systems/native_campaign_checkpoint.gd")
var checks := 0

func _check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		push_error(label)
		quit(1)
	return value

func _initialize() -> void:
	var completed := ["specimen", "archive", "reactor", "decon", "mirror"]
	var flags := {"lab": {"confrontation_done": true, "contract_done": false}}
	var cursor := {"step": 0, "questions": 0, "deferred": false, "look": [0.0, 0.0]}
	if not _check(Save.valid_presentation({"beat": "pact", "elapsed": 0}, completed, flags), "Old pre-pact cursor lost compatibility"): return
	for step in 6:
		cursor.step = step
		cursor.questions = 7 if step >= 5 else 0
		if not _check(Save.valid_presentation({"beat": "pact", "elapsed": 90, "encounter": cursor}, completed, flags), "Valid pre-pact step rejected"): return
	var deferred := cursor.duplicate(true)
	deferred.deferred = true
	if not _check(Save.valid_encounter_cursor(deferred, false), "Explicit deferral did not serialize"): return
	for mutation in [{"step": 6}, {"step": -1}, {"step": 1.5}, {"questions": 8}, {"questions": 0}, {"deferred": 1}, {"look": [NAN, 0]}, {"look": [0, INF]}, {"look": [.6, 0]}, {"look": [0, .31]}, {"look": [0]}, {"unknown": true}]:
		var bad := cursor.duplicate(true)
		bad.merge(mutation, true)
		if not _check(not Save.valid_encounter_cursor(bad, false), "Invalid or power-skipping cursor accepted: " + str(mutation)): return
	flags.lab.contract_done = true
	if not _check(Save.valid_presentation({"beat": "accepted", "elapsed": 0}, completed, flags), "Old accepted cursor lost compatibility"): return
	for step in [6, 7, 8]:
		cursor.step = step
		if not _check(Save.valid_presentation({"beat": "accepted", "elapsed": 0, "encounter": cursor}, completed, flags), "Accepted step rejected"): return
		var roundtrip: Variant = JSON.parse_string(JSON.stringify(cursor))
		if not _check(Save.valid_encounter_cursor(roundtrip, true), "JSON numeric cursor failed roundtrip"): return
	if not _check(not Save.valid_encounter_cursor(deferred, true), "Accepted authority regressed into unaccepted presentation"): return
	if not _check(not Save.valid_presentation({"beat": "wish", "elapsed": 0, "encounter": cursor}, completed, flags), "Wish reused an encounter cursor"): return
	var answer := {"step": 4, "questions": 1, "deferred": false, "look": [0, 0], "answer": 0}
	if not _check(Save.valid_encounter_cursor(answer, false), "Open question answer could not resume"): return
	for mutation in [{"answer": 3}, {"answer": .5}, {"questions": 0}, {"step": 3}]:
		var bad := answer.duplicate(true)
		bad.merge(mutation, true)
		if not _check(not Save.valid_encounter_cursor(bad, false), "Unasked or invalid answer cursor accepted"): return
	print("PASS Zero encounter checkpoint: ", checks, " strict cursor, consent boundary, bounded look, deferral and old-v1 compatibility checks")
	quit(0)
