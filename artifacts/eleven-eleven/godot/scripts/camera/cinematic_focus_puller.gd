class_name CinematicFocusPuller
extends Node

## AAA Cinematic Depth-of-Field (DoF) & Dynamic Focus Puller
## Delivers Genshin / Anime cinematic camera framing:
## - Conversation Mode: Focus pulled tight onto NPC speaker with creamy background Bokeh blur
## - Combat Finisher Mode: Macro intimacy with dramatic shallow depth of field
## - Exploration Mode: Deep focus for panoramic Japanese coastal town vista

signal focus_mode_changed(mode: int, mode_name: String)
signal focus_pulled(distance: float, target: Node3D)

enum FocusMode {
	EXPLORATION,
	CONVERSATION,
	COMBAT_FINISHER
}

@export var current_mode: FocusMode = FocusMode.EXPLORATION
@export var focus_distance: float = 100.0
@export var target_focus_distance: float = 100.0
@export var focus_pull_speed: float = 8.0

@export var dof_blur_far_enabled: bool = false
@export var dof_blur_near_enabled: bool = false
@export var dof_far_distance: float = 100.0
@export var dof_far_transition: float = 5.0
@export var bokeh_shape: String = "CIRCULAR_BOKEH"

var tracked_target: Node3D = null

func _process(delta: float) -> void:
	update_focus(delta)

func update_focus(delta: float) -> void:
	if not is_equal_approx(focus_distance, target_focus_distance):
		focus_distance = move_toward(focus_distance, target_focus_distance, focus_pull_speed * delta)
		dof_far_distance = focus_distance + 1.5

## Pulls focus tight onto an NPC speaker with creamy background Bokeh blur
func engage_conversation_focus(target: Node3D = null, custom_dist: float = 2.2) -> Dictionary:
	current_mode = FocusMode.CONVERSATION
	tracked_target = target
	target_focus_distance = custom_dist
	focus_distance = custom_dist
	dof_blur_far_enabled = true
	dof_blur_near_enabled = true
	dof_far_distance = custom_dist + 1.2
	dof_far_transition = 2.0

	emit_signal("focus_mode_changed", current_mode, "CONVERSATION")
	emit_signal("focus_pulled", focus_distance, tracked_target)

	return {
		"success": true,
		"mode": "CONVERSATION",
		"focus_distance": focus_distance,
		"bokeh_active": is_bokeh_active(),
		"bokeh_shape": bokeh_shape
	}

## Tight cinematic focus pull for visceral execution and anime burst cuts
func engage_finisher_focus(target: Node3D = null, custom_dist: float = 1.2) -> Dictionary:
	current_mode = FocusMode.COMBAT_FINISHER
	tracked_target = target
	target_focus_distance = custom_dist
	focus_distance = custom_dist
	dof_blur_far_enabled = true
	dof_blur_near_enabled = true
	dof_far_distance = custom_dist + 0.8
	dof_far_transition = 1.0

	emit_signal("focus_mode_changed", current_mode, "COMBAT_FINISHER")
	emit_signal("focus_pulled", focus_distance, tracked_target)

	return {
		"success": true,
		"mode": "COMBAT_FINISHER",
		"focus_distance": focus_distance,
		"bokeh_active": is_bokeh_active()
	}

## Restores deep exploration focus for navigating town streets and coastal views
func disengage_conversation_focus() -> Dictionary:
	current_mode = FocusMode.EXPLORATION
	tracked_target = null
	target_focus_distance = 100.0
	focus_distance = 100.0
	dof_blur_far_enabled = false
	dof_blur_near_enabled = false
	dof_far_distance = 100.0

	emit_signal("focus_mode_changed", current_mode, "EXPLORATION")
	emit_signal("focus_pulled", focus_distance, null)

	return {
		"success": true,
		"mode": "EXPLORATION",
		"focus_distance": focus_distance,
		"bokeh_active": false
	}

func get_focus_distance() -> float:
	return focus_distance

func is_bokeh_active() -> bool:
	return current_mode != FocusMode.EXPLORATION and dof_blur_far_enabled
