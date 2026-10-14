extends SceneTree

## Comprehensive test suite for Zero entity animation upgrades and visual manifestation.
## Verifies procedural hover/breathing oscillation, wing emergence unfolding motion,
## and accessibility compliance (reduced_motion and audio settings).

const AttachmentScript = preload("res://scripts/player/zero_manifestation_attachment.gd")
const CharacterAttachmentScript = preload("res://scripts/characters/zero_manifestation_attachment.gd")
const WingScene = preload("res://scenes/effects/zero_shadow_wing.tscn")
const EyeScene = preload("res://scenes/effects/zero_eye_singularity.tscn")
const PlayerWingScene = preload("res://scenes/player/zero_shadow_wing.tscn")
const PlayerEyeScene = preload("res://scenes/player/zero_eye_singularity.tscn")
const EchoModel = preload("res://assets/characters/echo_opening_uniform_v13.glb")

var failures: Array[String] = []
var checks := 0

class TestAuthority extends Node3D:
	var contract_with_zero_sealed := false
	var reduced_motion := false
	var audio_muted := false
	var audio_volume := 1.0

func _init() -> void:
	run.call_deferred()

func require(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("FAILURE: " + label)

func run() -> void:
	print("STARTING ZERO ENTITY UPGRADE REVIEW...")

	# 1. Attachment scripts compilation and class hierarchy
	var attach := AttachmentScript.new()
	var char_attach := CharacterAttachmentScript.new()
	require(attach != null, "Player attachment script instantiates cleanly")
	require(char_attach != null, "Character attachment script instantiates cleanly")
	require(char_attach is AttachmentScript, "Character attachment inherits from base attachment")

	# 2. Scene instantiation from effects/ directory
	var effect_wing := WingScene.instantiate() as Node3D
	var effect_eye := EyeScene.instantiate() as Node3D
	require(effect_wing != null, "Effect zero_shadow_wing.tscn instantiates cleanly")
	require(effect_eye != null, "Effect zero_eye_singularity.tscn instantiates cleanly")

	# 3. Mount in scene with avatar to test procedural motion
	var authority := TestAuthority.new()
	root.add_child(authority)
	var model_root := Node3D.new()
	model_root.name = "ModelRoot"
	authority.add_child(model_root)

	var avatar := EchoModel.instantiate() as Node3D
	avatar.name = "EchoAvatar"
	model_root.add_child(avatar)

	model_root.add_child(effect_eye)
	model_root.add_child(effect_wing)

	await process_frame
	require(effect_eye.mount_valid, "Effect eye mounts to avatar")
	require(effect_wing.mount_valid, "Effect wing mounts to avatar")

	# 4. Procedural hover / breathing oscillation math (Attachment)
	attach.is_manifested = true
	var eye_hover_0 := attach.get_eye_hover_offset(0.0)
	var eye_hover_1 := attach.get_eye_hover_offset(1.0)
	require(eye_hover_0.is_equal_approx(Vector3.ZERO), "Eye hover at t=0 is zero (no drift at rest)")
	require(eye_hover_1.length() > 0.00001, "Eye hover oscillates over time")

	var eye_glow_0 := attach.get_eye_glow_pulse(0.0, 1.0)
	var eye_glow_1 := attach.get_eye_glow_pulse(0.7, 1.0)
	require(is_equal_approx(eye_glow_0, 1.0), "Eye glow pulse at t=0 matches base")
	require(not is_equal_approx(eye_glow_0, eye_glow_1), "Eye glow pulses over time")

	var wing_hover_0 := attach.get_wing_hover_offset(0.0)
	var wing_hover_1 := attach.get_wing_hover_offset(1.0)
	require(wing_hover_0.is_equal_approx(Vector3.ZERO), "Wing hover at t=0 is zero")
	require(wing_hover_1.length() > 0.0001, "Wing hover generates levitation wave over time")

	var wing_breath_0 := attach.get_wing_breathing_basis(0.0)
	var wing_breath_1 := attach.get_wing_breathing_basis(1.0)
	require(wing_breath_0.is_equal_approx(Basis.IDENTITY), "Wing breathing rotation at t=0 is Identity")
	require(not wing_breath_1.is_equal_approx(Basis.IDENTITY), "Wing breathing rotation tilts gently over time")

	var wing_glow_0 := attach.get_wing_glow_energy(0.3, 0.0)
	var wing_glow_1 := attach.get_wing_glow_energy(0.3, 1.0)
	require(is_equal_approx(wing_glow_0, 0.3), "Wing glow energy at t=0 matches base")
	require(not is_equal_approx(wing_glow_0, wing_glow_1), "Wing glow pulses with breathing wave")

	# 5. Wing emergence unfolding motion (ominous ease)
	var base_target := Vector3.ONE * 0.8
	var scale_start := attach.get_emergence_scale(0.0, base_target)
	var scale_mid := attach.get_emergence_scale(0.5, base_target)
	var scale_end := attach.get_emergence_scale(1.0, base_target)
	require(scale_start.length() < 0.01, "Emergence scale starts near zero")
	require(scale_mid.length() > scale_start.length() and scale_mid.length() < scale_end.length(), "Emergence scale progresses monotonically")
	require(scale_end.is_equal_approx(base_target), "Emergence scale ends at full spread")

	var rot_start := attach.get_emergence_rotation(0.0)
	var rot_end := attach.get_emergence_rotation(1.0)
	require(rot_start.length() > 0.1, "Emergence rotation starts folded")
	require(rot_end.is_equal_approx(Vector3.ZERO), "Emergence rotation unfolds to full spread (Vector3.ZERO)")

	# Test Tween emergence
	var dummy_wing_mesh := Node3D.new()
	root.add_child(dummy_wing_mesh)
	var tween := attach.animate_wing_emergence(dummy_wing_mesh, base_target, 0.1)
	require(tween != null and tween.is_running(), "Animate wing emergence launches ominous ease Tween")
	dummy_wing_mesh.queue_free()

	# 6. Accessibility: Reduced Motion
	authority.reduced_motion = true
	attach.presentation = authority
	require(attach.motion_is_reduced(), "Reduced motion detected from authority")

	var eye_hover_reduced := attach.get_eye_hover_offset(2.5)
	require(eye_hover_reduced == Vector3.ZERO, "Reduced motion suppresses eye hover oscillation")

	var wing_hover_reduced := attach.get_wing_hover_offset(2.5)
	require(wing_hover_reduced == Vector3.ZERO, "Reduced motion suppresses wing levitation wave")

	var wing_breath_reduced := attach.get_wing_breathing_basis(2.5)
	require(wing_breath_reduced == Basis.IDENTITY, "Reduced motion suppresses wing breathing rotation")

	var eye_glow_reduced := attach.get_eye_glow_pulse(2.5, 0.02)
	require(is_equal_approx(eye_glow_reduced, 0.02), "Reduced motion keeps eye glow steady")

	var scale_reduced := attach.get_emergence_scale(0.0, base_target)
	var rot_reduced := attach.get_emergence_rotation(0.0)
	require(scale_reduced.is_equal_approx(base_target), "Reduced motion immediately gives full spread scale")
	require(rot_reduced.is_equal_approx(Vector3.ZERO), "Reduced motion immediately gives full spread rotation")

	# 7. Accessibility: Audio Settings
	authority.audio_muted = true
	require(attach.is_audio_muted(), "Audio mute setting detected")
	require(not attach.can_play_audio(), "Audio playback suppressed when muted")

	authority.audio_muted = false
	authority.audio_volume = 0.75
	require(not attach.is_audio_muted(), "Audio unmuted detected")
	require(is_equal_approx(attach.get_audio_volume(), 0.75), "Audio volume correctly read")
	require(attach.can_play_audio(), "Audio can play when unmuted with positive volume")

	# 8. Live Wing & Eye integration verification
	authority.reduced_motion = false
	authority.contract_with_zero_sealed = true

	effect_eye.activate_singularity(0.8)
	effect_wing.manifest_wing(0.8)

	require(effect_eye.is_singularity_active and effect_eye.visible, "Eye singularity activates on sealed contract")
	require(effect_wing.is_wing_manifested and effect_wing.visible, "Wing manifests on sealed contract")

	# Step a few frames to verify unfolding and oscillation
	for f in 30:
		effect_eye._process(1.0 / 60.0)
		effect_wing._process(1.0 / 60.0)

	require(effect_wing.reveal > 0.5, "Wing reveal advances during process")
	require(effect_wing.wing_mesh.scale.length() > 0.1, "Wing mesh scales up towards full spread")

	# Dismissal cleanly resets state
	effect_eye.deactivate_singularity()
	effect_wing.dismiss_wing()

	require(not effect_eye.is_singularity_active and not effect_eye.visible, "Eye deactivated")
	require(not effect_wing.is_wing_manifested and not effect_wing.visible, "Wing dismissed")
	require(effect_wing.wing_mesh.scale.length() < 0.01, "Wing scale resets on dismissal")

	authority.queue_free()

	var report := {
		"status": "PASS" if failures.is_empty() else "FAIL",
		"checks": checks,
		"failures": failures
	}
	print("ZERO_ENTITY_UPGRADE_REVIEW ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
