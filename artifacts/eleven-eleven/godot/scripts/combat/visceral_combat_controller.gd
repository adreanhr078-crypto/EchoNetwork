class_name VisceralCombatController
extends Node

## AAA Visceral Combat Execution & Stagger Finisher System
## Manages Genshin/ZZZ-tier execution strikes against posture-broken and staggered foes.
## Coordinates elemental blade infusion, slow-mo cinematic framing, directional trauma, and Japanese yells.

signal visceral_execution_available(target: Node)
signal visceral_execution_cleared()
signal visceral_execution_started(target: Node, element: String)
signal visceral_execution_completed(target: Node, damage: int)
signal blade_infused(element: String, aura_color: Color)

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")
const ImpactSpawner = preload("res://scripts/combat/impact_spawner.gd")

enum BladeElement {
	PHYSICAL,
	SHADOW,
	CYAN_RESONANCE,
	CRIMSON_VOID
}

var current_element: BladeElement = BladeElement.SHADOW
var execution_range: float = 4.5
var execution_damage: int = 350
var is_executing: bool = false
var execution_cooldown: float = 0.0

# Elemental Visual Metadata
const ELEMENT_PROFILES: Dictionary = {
	BladeElement.PHYSICAL: {
		"name": "PHYSICAL",
		"color": Color(0.9, 0.9, 0.95, 1.0),
		"energy": 1.5,
		"crit_mult": 1.0
	},
	BladeElement.SHADOW: {
		"name": "SHADOW",
		"color": Color(0.18, 0.02, 0.38, 1.0),
		"energy": 4.5,
		"crit_mult": 1.25
	},
	BladeElement.CYAN_RESONANCE: {
		"name": "CYAN_RESONANCE",
		"color": Color(0.0, 0.94, 1.0, 1.0),
		"energy": 4.0,
		"crit_mult": 1.2
	},
	BladeElement.CRIMSON_VOID: {
		"name": "CRIMSON_VOID",
		"color": Color(1.0, 0.08, 0.22, 1.0),
		"energy": 5.0,
		"crit_mult": 1.35
	}
}

func _process(delta: float) -> void:
	if execution_cooldown > 0.0:
		execution_cooldown = maxf(0.0, execution_cooldown - delta)

## Changes active blade element and flares elemental light
func infuse_blade(element: BladeElement) -> Dictionary:
	current_element = element
	var profile = ELEMENT_PROFILES.get(element, ELEMENT_PROFILES[BladeElement.SHADOW])
	emit_signal("blade_infused", profile["name"], profile["color"])
	return profile

## Checks whether target is in staggered state within range
func can_execute(player: Node, target: Node) -> bool:
	if not is_instance_valid(target) or not is_instance_valid(player):
		return false
	if is_executing or execution_cooldown > 0.0:
		return false
	var target_staggered: bool = target.get("is_staggered") == true
	if not target_staggered:
		return false

	var p_pos: Vector3 = player.global_position if player.is_inside_tree() else player.position
	var t_pos: Vector3 = target.global_position if target.is_inside_tree() else target.position
	var dist: float = (t_pos - p_pos).length()
	return dist <= execution_range

## Triggers the Visceral Execution cinematic strike
func execute_visceral_strike(player: Node, target: Node, cine_camera_director: CineCameraDirector = null) -> Dictionary:
	if not can_execute(player, target):
		return {"success": false, "reason": "conditions_not_met"}

	is_executing = true
	execution_cooldown = 1.8
	var profile = ELEMENT_PROFILES.get(current_element, ELEMENT_PROFILES[BladeElement.SHADOW])
	emit_signal("visceral_execution_started", target, profile["name"])

	var p_pos: Vector3 = player.global_position if player.is_inside_tree() else player.position
	var t_pos: Vector3 = target.global_position if target.is_inside_tree() else target.position
	var forward_dir: Vector3 = (t_pos - p_pos).normalized()
	forward_dir.y = 0.0
	if forward_dir.length() < 0.1:
		forward_dir = Vector3.FORWARD

	# 1. Seamless dash warp to strike distance (1.4m before target)
	var strike_pos: Vector3 = t_pos - forward_dir * 1.4
	strike_pos.y = p_pos.y
	if player.is_inside_tree():
		player.global_position = strike_pos
	else:
		player.position = strike_pos

	# Align player facing towards target
	if player.get("visual_root"):
		var vr = player.get("visual_root") as Node3D
		if vr:
			vr.rotation.y = atan2(forward_dir.x, forward_dir.z)

	# 2. Blade Elemental Flare & Audio Synthesis
	var parent = player.get_parent()
	if parent:
		# Spawn elemental shockwave / sparks
		var impact_center: Vector3 = (strike_pos + t_pos) * 0.5 + Vector3(0, 1.2, 0)
		ImpactSpawner.spawn_katana_sparks(parent, impact_center, Vector3.UP, true)
		ImpactSpawner.spawn_deflect_burst(parent, impact_center)

	# Play Visceral Execution SFX
	var exec_sfx = ProceduralCinematicAudio.create_visceral_execution_sfx()
	if player.is_inside_tree():
		var audio_player = AudioStreamPlayer.new()
		player.add_child(audio_player)
		audio_player.stream = exec_sfx
		audio_player.play()
		audio_player.finished.connect(func(): audio_player.queue_free())

	# 3. Japanese Combat Voice Yell ("「これで終わりだ！」")
	if player.get("spatial_voice_manager"):
		var svm = player.get("spatial_voice_manager")
		if svm and svm.has_method("play_voice"):
			svm.play_voice("visceral_strike", strike_pos)

	# 4. Inflict Massive Visceral Damage
	var total_dmg: int = int(round(execution_damage * profile["crit_mult"]))
	if target.has_method("take_damage"):
		target.take_damage(total_dmg, strike_pos)
	if player.has_method("register_hit_landed"):
		player.register_hit_landed(total_dmg)

	# 5. Cinematic Camera Director: Finisher zoom cut & bullet time
	if cine_camera_director:
		cine_camera_director.preset_combat_finisher(t_pos, forward_dir)
	elif player.get("player_camera"):
		var cam = player.get("player_camera") as Camera3D
		if cam:
			ImpactSpawner.trigger_screen_shake(cam, 0.35, 0.45)

	# 6. Deep Hit-Stop (0.12s freeze frame)
	if player.has_method("trigger_hit_stop"):
		player.trigger_hit_stop(0.12)
	else:
		Engine.time_scale = 0.05
		var tree = player.get_tree() if player.is_inside_tree() else null
		if tree:
			tree.create_timer(0.12 * 0.05).timeout.connect(func(): Engine.time_scale = 1.0)

	# 7. Un-stagger target after taking execution blow
	if "is_staggered" in target:
		target.is_staggered = false
	if "stagger_timer" in target:
		target.stagger_timer = 0.0

	is_executing = false
	emit_signal("visceral_execution_completed", target, total_dmg)
	return {
		"success": true,
		"damage": total_dmg,
		"element": profile["name"],
		"strike_pos": strike_pos
	}
