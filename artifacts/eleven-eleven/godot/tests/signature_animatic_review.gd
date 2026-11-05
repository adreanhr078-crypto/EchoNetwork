extends SceneTree

const Preview = preload("res://scripts/cinematics/signature_animatic_preview.gd")
var checks := 0
var failures: Array[String] = []
var evidence := "res://../audits/evidence/signature-slice-20261104"

func _init() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition: failures.append(description)
	print("PASS " if condition else "FAIL ", description)

func frames(count: int) -> void:
	for i in count: await process_frame

func capture(name_value: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var rendered := root.get_texture().get_image()
	if name_value.begins_with("shot-"):
		rendered.save_jpg(evidence.path_join(name_value + ".jpg"), 0.86)
	else:
		rendered.save_png(evidence.path_join(name_value + ".png"))

func click_button(button: Button) -> void:
	var center := button.get_global_rect().get_center()
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = center
		event.global_position = center
		event.pressed = down
		root.push_input(event, true)
		await frames(1)

func _run() -> void:
	evidence = ProjectSettings.globalize_path(evidence)
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	var preview = Preview.new()
	root.add_child(preview)
	preview.set_process(false)
	await frames(3)
	check(preview.shots.size() == 23 and preview.error_text == "", "23 source-locked editorial shots load")
	check(preview.paused and preview.reduced_motion and not preview.preview_consent, "safe initial state;static and no preview consent")
	check(preview.art.texture != null, "current source panel decodes natively")
	await capture("native-opening")
	await capture("shot-SH01")
	await click_button(preview.pause_button)
	check(not preview.paused, "public mouse input starts preview")
	preview.advance_clock(1.0)
	var elapsed: float = preview.elapsed
	await click_button(preview.pause_button)
	preview.advance_clock(99.0)
	check(preview.elapsed == elapsed and preview.index == 0, "pause freezes local editorial clock")
	check(preview.art.scale == Vector2.ONE, "Reduced Motion has no push or scale")
	preview.toggle_motion()
	preview.toggle_pause()
	preview.advance_clock(0.5)
	check(preview.art.scale.x > 1.0 and preview.art.scale.x <= 1.02, "optional motion bounded to two percent")
	preview.toggle_motion()
	check(preview.art.scale == Vector2.ONE, "Reduced Motion immediately clears motion")
	preview.restart()
	preview.paused = false
	var visited: Array[int] = [0]
	for i in preview.decision_index:
		preview.advance_clock(float(preview.shots[preview.index].duration_seconds) + 0.2)
		visited.append(preview.index)
		await capture("shot-" + String(preview.shots[preview.index].id))
	check(visited.size() == 13 and preview.index == preview.decision_index, "all pre-consent cuts reach decision in order")
	preview.advance_clock(3600.0)
	check(preview.index == preview.decision_index and not preview.preview_consent, "unlimited decision time cannot accept")
	preview.next_shot()
	preview.seek_shot(22)
	check(preview.index == preview.decision_index and not preview.preview_consent, "next and direct seek cannot bypass consent")
	await capture("native-explicit-decision")
	preview.defer_preview()
	preview.advance_clock(1000.0)
	check(preview.paused and preview.choices.visible and not preview.preview_consent, "deferral remains at decision without countdown")
	preview.reject_preview()
	preview.accept_preview()
	check(preview.finished and not preview.preview_consent, "rejection stops preview;late accept ignored")
	preview.restart()
	preview.seek_shot(22)
	preview.skip_preview()
	check(preview.finished and not preview.preview_consent, "skip at decision does not grant even preview consent")
	preview.restart()
	preview.accept_preview()
	check(preview.index == 0 and not preview.preview_consent, "out-of-order acceptance is ignored")
	preview.seek_shot(preview.decision_index)
	await frames(2)
	await click_button(preview.choices.get_child(0))
	check(preview.index == preview.decision_index + 1 and preview.preview_consent, "explicit mouse choice alone opens earned preview")
	await capture("shot-" + String(preview.shots[preview.index].id))
	var first_earned: int = preview.index
	preview.accept_preview()
	check(preview.index == first_earned, "duplicate acceptance cannot jump another shot")
	preview.paused = false
	for i in range(first_earned, preview.shots.size() - 1):
		preview.advance_clock(float(preview.shots[preview.index].duration_seconds) + 0.1)
		await capture("shot-" + String(preview.shots[preview.index].id))
	check(preview.index == 22 and preview.shots[22].gate == "gameplay_handoff", "post-choice montage ends at actual gameplay dependency")
	preview.advance_clock(1000.0)
	check(preview.index == 22, "handoff slate cannot fabricate playable combat")
	await capture("native-gameplay-handoff")
	preview.previous_shot()
	preview.seek_shot(preview.decision_index)
	check(not preview.preview_consent, "returning before choice clears volatile consent")
	preview.restart()
	var path_value: String = preview.shots[0].page_path
	var valid_hash: String = preview.locks[path_value]
	preview.locks[path_value] = "invalid"
	preview.seek_shot(0)
	check(preview.finished and preview.error_text != "" and preview.art.texture == null and not preview.preview_consent, "changed source fails closed with no retained image or consent")
	preview.locks[path_value] = valid_hash
	preview.restart()
	var valid_crop: Array = preview.shots[0].crop_normalized.duplicate()
	preview.shots[0].crop_normalized = [0.8, 0.2, 0.1, 0.9]
	preview.seek_shot(0)
	check(preview.finished and preview.error_text != "", "invalid source crop is rejected")
	preview.shots[0].crop_normalized = valid_crop
	preview.restart()
	check(preview.error_text == "" and preview.index == 0 and not preview.preview_consent, "retry recovers after a corrected source")
	await frames(2)
	var overflow: Array[String] = []
	var controls: Array[Node] = preview.find_children("*", "Button", true, false)
	for button in controls:
		if button.is_visible_in_tree() and not Rect2(Vector2.ZERO, Vector2(root.size)).encloses(button.get_global_rect()):
			overflow.append(button.text)
	check(overflow.is_empty(), "all visible controls stay inside native 1280x720 viewport")
	var data := {"checks": checks, "failures": failures, "renderer": RenderingServer.get_current_rendering_method(),
		"display": DisplayServer.get_name(), "scope": "editorial reference tool;not final art,voice,animation,contact,fun or gameplay", "production_state_mutated": false}
	data["source_hashes"] = {}
	for relative in ["godot/scripts/cinematics/signature_animatic_preview.gd", "godot/tests/signature_animatic_review.gd", "art/production/signature-slice-20261104/editorial-timeline.json", "art/production/signature-slice-20261104/source-lock.json"]:
		data.source_hashes[relative] = FileAccess.get_sha256(ProjectSettings.globalize_path("res://../" + relative))
	var file := FileAccess.open(evidence.path_join("native-review-" + DisplayServer.get_name() + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  ") + "\n")
	preview.queue_free()
	await frames(2)
	print("SIGNATURE_REVIEW ", checks, " checks; failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
