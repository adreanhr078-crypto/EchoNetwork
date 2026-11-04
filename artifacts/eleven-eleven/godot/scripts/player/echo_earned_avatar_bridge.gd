extends Node

## Presentation of the existing explicit contract only. This node never grants
## a pact, combat, a checkpoint or progress. Hidden source skins are reused locally.
const Profile = preload("res://scripts/player/echo_rig_profile.gd")
const PACT_SCENE := "res://scenes/characters/echo_pact_candidate.tscn"
var body: EchoPlayer
var detached: Dictionary = {}
var active_pact := false
var packed: PackedScene

func configure(player: EchoPlayer) -> void:
	body=player
	if ResourceLoader.exists(PACT_SCENE): packed=load(PACT_SCENE)

func set_earned_presentation(enabled: bool) -> bool:
	if not is_instance_valid(body) or (enabled and not body.contract_with_zero_sealed):return false
	if enabled==active_pact:return true
	if body.rig_profile.get("id") not in [Profile.SCHOOL65_ID,Profile.PACT72_ID]:return false
	var key := "pact" if enabled else "normal"
	var replacement: Node3D=detached.get(key)
	if not is_instance_valid(replacement):
		if not enabled:return false
		if not packed and ResourceLoader.exists(PACT_SCENE):packed=load(PACT_SCENE)
		if not packed:return false
		replacement=packed.instantiate()
	var rig := replacement.find_child("Skeleton3D",true,false) as Skeleton3D
	var expected := Profile.PACT72_ID if enabled else Profile.SCHOOL65_ID
	var sources_ready: bool=not enabled or (replacement.has_method("source_libraries") and replacement.source_libraries().size()==9)
	if not sources_ready or Profile.identify(rig).get("id")!=expected or not replacement.find_child("AnimationPlayer",true,false):
		if replacement.get_parent()==null and not detached.has(key):replacement.free()
		return false
	var old := body.visual_root.get_node_or_null("EchoOpeningUniform") as Node3D
	if not old:return false
	if body.visual_root.get("placement_report") is Dictionary:
		old.set_meta("identifier_state",{"report":body.visual_root.get("placement_report"),"records":body.visual_root.get("projection_records")})
	body._cancel_attack()
	body.cancel_roll()
	body.locomotion_controller.cancel_root_motion()
	body.is_charging_iai=false
	body.iai_charge=0.0
	body._keyboard_charge_owned=false
	body.animation_player.stop()
	# Preserve the actual story-equipped blades and scabbard across skeletons.
	for label in ["KatanaBlade","ShadowKatana","KatanaHipScabbard"]:
		var weapon:=body.find_child(label,true,false) as Node3D
		if weapon and old.is_ancestor_of(weapon):weapon.reparent(body.visual_root)
	# Keep both source skins attached to their existing RenderingServer RIDs.
	# Visibility/process ownership switches; no live GPU skeleton is detached
	# during the hospital handoff. Active avatar stays first for existing users.
	old.hide()
	old.process_mode=Node.PROCESS_MODE_DISABLED
	old.name="CachedPactAvatar" if active_pact else "CachedSchoolAvatar"
	detached["pact" if active_pact else "normal"]=old
	detached.erase(key)
	replacement.name="EchoOpeningUniform"
	if replacement.get_parent()==null:body.visual_root.add_child(replacement)
	body.visual_root.move_child(replacement,0)
	replacement.process_mode=Node.PROCESS_MODE_INHERIT
	replacement.show()
	var presentation_owner:=body.get_parent()
	if enabled and presentation_owner.has_method("apply_player_avatar_style"):
		presentation_owner.apply_player_avatar_style(replacement)
	body.animation_player=replacement.find_child("AnimationPlayer",true,false)
	body._recovery_skeleton=rig
	body._skeleton_ref=null
	body.rig_profile=Profile.identify(rig)
	body.model_forward_yaw_offset=body.rig_profile.yaw_offset
	body.model_local_forward=body.rig_profile.local_forward
	body._recovery_left_toe=rig.find_bone(Profile.bone(rig,"left_toe"))
	body._recovery_right_toe=rig.find_bone(Profile.bone(rig,"right_toe"))
	body._hand_weapon_socket=null
	body._hip_weapon_socket=null
	body._setup_weapon_attachment()
	if is_instance_valid(body.footstep_system):
		body.footstep_system.anim_player=body.animation_player
		body.footstep_system._last_animation=""
		body.footstep_system._last_phase=0.0
	body.current_anim=""
	body.play_anim("IDLE",0.0)
	body.animation_player.advance(0.0)
	if body.visual_root.has_method("_attach_identifier"):
		var ink: Dictionary=replacement.get_meta("identifier_state",{})
		body.visual_root.set("placement_report",ink.get("report",{}))
		body.visual_root.set("projection_records",ink.get("records",[]))
		if ink.is_empty():body.visual_root.call_deferred("_attach_identifier")
	active_pact=enabled
	return true

func _exit_tree() -> void:
	for avatar in detached.values():
		if is_instance_valid(avatar) and avatar.get_parent()==null:avatar.queue_free()
	detached.clear()
