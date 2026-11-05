extends SceneTree
## Confirm cold lab construction and idempotent, hidden native asset preparation.

const LAB = preload("res://scripts/environment/dr_kinja_lab_room.gd")
const PROFILE_PATH := "res://assets/characters/zero_manifestation_profile_v1.json"
const PRESENTATION_PATH := "res://scripts/cinematics/pact_revenge_presentation.gd"
const CAMPAIGN_PATH := "res://scripts/systems/native_campaign_controller.gd"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		quit(2)
		return
	root.unfocusable = true
	root.size = Vector2i(1280, 720)
	var room := LAB.new()
	room.audio_muted = true
	room.reduced_motion = true
	root.add_child(room)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(3.2, 3.2, -16)
	camera.look_at(Vector3(0, 2.1, -20))
	camera.make_current()
	await _settle()
	var presentation = room.story_presentation
	var profile = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	var asset_path: String = profile.scene_path
	var cold := not is_instance_valid(presentation.generated_zero.model_root) and not ResourceLoader.has_cached(asset_path)
	var before := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
	var started := Time.get_ticks_usec()
	presentation.prepare_zero_source()
	var requested := Time.get_ticks_usec()
	var returned_before_attachment := not is_instance_valid(presentation.generated_zero.model_root)
	var max_wait_frame_ms := 0.0
	var previous := requested
	while not is_instance_valid(presentation.generated_zero.model_root) and Time.get_ticks_usec() - requested < 5000000:
		await process_frame
		var now := Time.get_ticks_usec()
		max_wait_frame_ms = maxf(max_wait_frame_ms, float(now - previous) / 1000.0)
		previous = now
	await _settle()
	var after := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
	var model: Node3D = presentation.generated_zero.model_root
	var player: AnimationPlayer = presentation.generated_zero.source_player
	var source_ready: bool = is_instance_valid(model) and is_instance_valid(player) and player.has_animation("pact/agree") and is_instance_valid(presentation.generated_zero.skeleton) and presentation.generated_zero.skeleton.get_bone_count() == 41
	var hidden_after_prewarm: bool = not presentation._zero.is_visible_in_tree() and not presentation._zero_fallback.visible
	presentation.prepare_zero_source()
	var idempotent: bool = presentation.generated_zero.model_root == model
	presentation.set_stage("manifested", true)
	var visible_after_manifestation: bool = presentation._zero.is_visible_in_tree() and presentation.generated_zero.model_root == model
	var flags_clear := not room.confrontation_done and not room.contract_done and not room.revenge_done and not room.wish_done
	var passed := cold and returned_before_attachment and source_ready and hidden_after_prewarm and idempotent and visible_after_manifestation and flags_clear
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if not file:
		quit(2)
		return
	file.store_string(JSON.stringify({
		"status": "PASS_SCOPED_ZERO_PREWARM" if passed else "FAIL_ZERO_PREWARM",
		"cold_lab_has_no_loaded_model": cold,
		"exact_source_loaded": source_ready,
		"hidden_during_prewarm": hidden_after_prewarm,
		"visible_only_on_manifestation": visible_after_manifestation,
		"idempotent": idempotent, "story_flags_clear": flags_clear,
		"renderer": RenderingServer.get_current_rendering_method(),
		"display": DisplayServer.get_name(),
		"request_return_ms": float(requested - started) / 1000.0,
		"returned_before_attachment": returned_before_attachment,
		"ready_wall_ms": float(previous - started) / 1000.0,
		"max_wait_frame_ms": max_wait_frame_ms,
		"engine_texture_counter_before": before,
		"engine_texture_counter_after": after, "engine_texture_counter_delta": after - before,
		"scope": "Single cold room and camera; threaded resource request and one main-thread attachment; engine counters are not GPU residency.",
		"source_sha256": FileAccess.get_sha256(asset_path),
		"presentation_sha256": FileAccess.get_sha256(PRESENTATION_PATH),
		"campaign_sha256": FileAccess.get_sha256(CAMPAIGN_PATH),
		"review_sha256": FileAccess.get_sha256(get_script().resource_path)
	}, "\t") + "\n")
	file.close()
	room.queue_free()
	await process_frame
	quit(0 if passed else 1)

func _settle() -> void:
	for frame in 8:
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
