extends Node

## Presentation only. A UV mask follows the authored skin; no guessed hair
## geometry, body bone edits, global material mutation or story events.
const RigProfile = preload("res://scripts/player/echo_rig_profile.gd")
const MASKS := {
	"echo_opening_v13": "res://assets/characters/contract/echo_opening_v13_hair_mask.png",
	"echo_v31_authored_68": "res://assets/characters/contract/echo_v31_authored_68_hair_mask.png",
}
var player: Node
var body: MeshInstance3D
var material: ShaderMaterial
var profile_id := ""
var blend := 0.0
var local_time := 0.0
var _requested := false
var _main: Node
var _base_material: ShaderMaterial

func _ready() -> void:
	player = get_parent()
	_main = player.get_parent()

func reveal(restoring := false) -> void:
	if not is_instance_valid(player) or player.get("contract_with_zero_sealed") != true:
		return
	_requested = true
	if _bind() and restoring:
		blend = 1.0
		_apply()

func _bind() -> bool:
	if is_instance_valid(body) and is_instance_valid(material) and body.get_active_material(0) == material and body.is_visible_in_tree():
		return true
	_release_material()
	var model := player.get_node_or_null("ModelRoot")
	if not model: return false
	var avatar: Node3D
	var profile := {}
	for child in model.get_children():
		if not child is Node3D or not child.is_visible_in_tree(): continue
		var skeleton := child.find_child("Skeleton3D", true, false) as Skeleton3D
		var identified := RigProfile.identify(skeleton)
		if not identified.is_empty():
			avatar = child
			profile = identified
			break
	if profile.is_empty(): return false
	profile_id = profile.id
	var label := "EchoOpeningUniformBody" if profile_id == RigProfile.LEGACY_ID else "EchoV31BodyAndCoat"
	body = avatar.find_child(label, true, false) as MeshInstance3D
	if not body or not body.mesh: return false
	var source := body.get_active_material(0) as ShaderMaterial
	if not source or source.shader != preload("res://shaders/anime_cel.gdshader"):
		return false
	# Bind only after the skin-ink pass has produced the current material.
	_base_material = source
	material = source.duplicate() as ShaderMaterial
	material.set_shader_parameter("contract_hair_mask", load(MASKS[profile_id]))
	material.set_shader_parameter("contract_hair_enabled", true)
	body.set_surface_override_material(0, material)
	_apply()
	return true

func _release_material() -> void:
	# Release our override before its rendering RID is retired. Never overwrite
	# a newer material installed by the character's skin/ink applicator.
	if is_instance_valid(body) and body.get_active_material(0) == material and _base_material:
		body.set_surface_override_material(0, _base_material)
	body = null
	material = null
	_base_material = null

func _exit_tree() -> void:
	set_process(false)
	_release_material()

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	if player.get("contract_with_zero_sealed") != true:
		_requested = false
		blend = 0.0
		local_time = 0.0
		_apply()
		return
	if not _requested or not _bind(): return
	var reduced: bool = is_instance_valid(_main) and _main.get("reduced_motion") == true
	if reduced:
		blend = 1.0
	else:
		blend = move_toward(blend, 1.0, minf(delta, 0.1) / 0.75)
		local_time += minf(delta, 0.1)
	_apply()

func _apply() -> void:
	if not is_instance_valid(material): return
	material.set_shader_parameter("contract_hair_blend", blend)
	material.set_shader_parameter("contract_hair_time", local_time)
