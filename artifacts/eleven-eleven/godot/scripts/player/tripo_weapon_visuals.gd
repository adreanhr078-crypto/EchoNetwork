class_name TripoWeaponVisuals
extends RefCounted

## Tripo Weapon Visual Integration Helper (2026-10-08)
## Non-destructive visual replacement helper for Echo player katana sockets.
## Strictly enforces combat_available and pact narrative authority:
## Weapons remain completely invisible and inactive until combat_available is true.

const STANDARD_KATANA_SCENE: PackedScene = preload("res://assets/weapons/standard_katana_tripo_20261008.glb")
const SHADOW_KATANA_SCENE: PackedScene = preload("res://assets/weapons/shadow_katana_tripo_20261008.glb")

const TRIPO_VISUAL_NODE_NAME := "TripoVisual"
const META_HIDDEN_WEAPONS := "tripo_hidden_weapon_nodes"

const WEAPON_REGISTRY := {
	"standard_katana": STANDARD_KATANA_SCENE,
	"katana": STANDARD_KATANA_SCENE,
	"standard": STANDARD_KATANA_SCENE,
	"shadow_katana": SHADOW_KATANA_SCENE,
	"shadow": SHADOW_KATANA_SCENE,
	"obsidian_katana": SHADOW_KATANA_SCENE,
}

static func get_weapon_scene(weapon_id: String) -> PackedScene:
	var key := weapon_id.to_lower().strip_edges()
	if WEAPON_REGISTRY.has(key):
		return WEAPON_REGISTRY[key]
	return null

## Applies Tripo replacement models to both KatanaBlade and ShadowKatana under player_node.
## Preserves particle systems, glow lights, and slash arc effects while swapping the physical blade meshes.
static func apply_weapon_visuals(player_node: Node3D) -> Dictionary:
	var result := {
		"applied": false,
		"standard_katana_replaced": false,
		"shadow_katana_replaced": false,
		"combat_available": false
	}

	if not player_node:
		push_error("TripoWeaponVisuals: player_node is null")
		return result

	var combat_available: bool = (player_node.get("combat_available") == true)
	result["combat_available"] = combat_available

	# 1. Apply to standard KatanaBlade
	var katana: Node3D = null
	if player_node.name == "KatanaBlade":
		katana = player_node
	else:
		katana = player_node.find_child("KatanaBlade", true, false) as Node3D
	if katana:
		var rep_katana := _replace_katana_visual(katana)
		if rep_katana:
			result["standard_katana_replaced"] = true

	# 2. Apply to ShadowKatana
	var shadow_katana: Node3D = null
	if player_node.name == "ShadowKatana":
		shadow_katana = player_node
	else:
		shadow_katana = player_node.find_child("ShadowKatana", true, false) as Node3D
	if shadow_katana:
		var rep_shadow := _replace_shadow_katana_visual(shadow_katana)
		if rep_shadow:
			result["shadow_katana_replaced"] = true

	result["applied"] = result["standard_katana_replaced"] or result["shadow_katana_replaced"]

	# 3. Synchronize visibility according to combat_available and pact status
	sync_weapon_visibility(player_node)

	return result

## Replaces procedural mesh parts in KatanaBlade with Tripo GLB, keeping lights, slash arcs, and tassels
static func _replace_katana_visual(katana: Node3D) -> Node3D:
	if not katana:
		return null

	# Remove existing replacement if present
	var existing := katana.get_node_or_null(TRIPO_VISUAL_NODE_NAME)
	if existing:
		katana.remove_child(existing)
		existing.queue_free()

	# Hide original procedural mesh components: Handle, Tsuba, Blade
	# If already recorded from a previous apply, do NOT overwrite with empty list!
	if not katana.has_meta(META_HIDDEN_WEAPONS):
		var hidden_nodes: Array[NodePath] = []
		for part_name in ["Handle", "Tsuba", "Blade"]:
			var part := katana.get_node_or_null(part_name)
			if part and part.get("visible") != null and part.visible:
				part.visible = false
				hidden_nodes.append(katana.get_path_to(part))
		katana.set_meta(META_HIDDEN_WEAPONS, hidden_nodes)

	# Instantiate Tripo standard katana
	var tripo_katana := STANDARD_KATANA_SCENE.instantiate() as Node3D
	if not tripo_katana:
		return null

	tripo_katana.name = TRIPO_VISUAL_NODE_NAME
	katana.add_child(tripo_katana)
	return tripo_katana

## Replaces procedural mesh parts in ShadowKatana with Tripo GLB, keeping dark flame particles and glow
static func _replace_shadow_katana_visual(shadow_katana: Node3D) -> Node3D:
	if not shadow_katana:
		return null

	var blade_root := shadow_katana.get_node_or_null("BladeRoot") as Node3D
	var parent_target: Node3D = blade_root if blade_root else shadow_katana

	# Remove existing replacement if present
	var existing := parent_target.get_node_or_null(TRIPO_VISUAL_NODE_NAME)
	if existing:
		parent_target.remove_child(existing)
		existing.queue_free()

	# Hide original procedural mesh components under BladeRoot: Hilt, Tsuba, BladeMesh
	# If already recorded from a previous apply, do NOT overwrite with empty list!
	if not parent_target.has_meta(META_HIDDEN_WEAPONS):
		var hidden_nodes: Array[NodePath] = []
		for part_name in ["Hilt", "Tsuba", "BladeMesh"]:
			var part := parent_target.get_node_or_null(part_name)
			if part and part.get("visible") != null and part.visible:
				part.visible = false
				hidden_nodes.append(parent_target.get_path_to(part))
		parent_target.set_meta(META_HIDDEN_WEAPONS, hidden_nodes)

	# Instantiate Tripo shadow katana
	var tripo_shadow := SHADOW_KATANA_SCENE.instantiate() as Node3D
	if not tripo_shadow:
		return null

	tripo_shadow.name = TRIPO_VISUAL_NODE_NAME
	parent_target.add_child(tripo_shadow)
	return tripo_shadow

## Restores procedural visuals on standard katana blade
static func restore_katana_visual(katana: Node3D) -> bool:
	if not katana:
		return false

	var visual := katana.get_node_or_null(TRIPO_VISUAL_NODE_NAME)
	if visual:
		katana.remove_child(visual)
		visual.queue_free()

	# Only restore visibility to nodes that were ACTUALLY recorded in the original hidden list
	if katana.has_meta(META_HIDDEN_WEAPONS):
		var hidden_nodes = katana.get_meta(META_HIDDEN_WEAPONS) as Array
		for path in hidden_nodes:
			var part := katana.get_node_or_null(path)
			if part and part.get("visible") != null:
				part.visible = true
		katana.remove_meta(META_HIDDEN_WEAPONS)
	return true

## Restores procedural visuals on shadow katana blade
static func restore_shadow_katana_visual(shadow_katana: Node3D) -> bool:
	if not shadow_katana:
		return false

	var blade_root := shadow_katana.get_node_or_null("BladeRoot") as Node3D
	var parent_target: Node3D = blade_root if blade_root else shadow_katana

	var visual := parent_target.get_node_or_null(TRIPO_VISUAL_NODE_NAME)
	if visual:
		parent_target.remove_child(visual)
		visual.queue_free()

	# Only restore visibility to nodes that were ACTUALLY recorded in the original hidden list
	if parent_target.has_meta(META_HIDDEN_WEAPONS):
		var hidden_nodes = parent_target.get_meta(META_HIDDEN_WEAPONS) as Array
		for path in hidden_nodes:
			var part := parent_target.get_node_or_null(path)
			if part and part.get("visible") != null:
				part.visible = true
		parent_target.remove_meta(META_HIDDEN_WEAPONS)
	return true

## Restores procedural weapon visuals and removes Tripo meshes
static func restore_weapon_visuals(player_node: Node3D) -> Dictionary:
	var result := {
		"restored": false,
		"standard_katana_restored": false,
		"shadow_katana_restored": false
	}

	if not player_node:
		return result

	var katana: Node3D = null
	if player_node.name == "KatanaBlade":
		katana = player_node
	else:
		katana = player_node.find_child("KatanaBlade", true, false) as Node3D

	if katana:
		if restore_katana_visual(katana):
			result["standard_katana_restored"] = true

	var shadow_katana: Node3D = null
	if player_node.name == "ShadowKatana":
		shadow_katana = player_node
	else:
		shadow_katana = player_node.find_child("ShadowKatana", true, false) as Node3D

	if shadow_katana:
		if restore_shadow_katana_visual(shadow_katana):
			result["shadow_katana_restored"] = true

	result["restored"] = result["standard_katana_restored"] or result["shadow_katana_restored"]
	sync_weapon_visibility(player_node)
	return result

## Strictly synchronizes weapon visibility based on player's combat_available and stance
## Guarantees weapons are NEVER visible if combat_available == false (e.g. pre-pact opening).
static func sync_weapon_visibility(player_node: Node3D) -> void:
	if not player_node:
		return

	var combat_available: bool = (player_node.get("combat_available") == true)
	var is_shadow_equipped: bool = (player_node.get("is_shadow_katana_equipped") == true)
	var is_sheathed: bool = (player_node.get("is_sheathed") == true)

	var katana := player_node.find_child("KatanaBlade", true, false) as Node3D
	if katana:
		katana.visible = combat_available and not is_shadow_equipped and not is_sheathed

	var shadow_katana := player_node.find_child("ShadowKatana", true, false) as Node3D
	if shadow_katana:
		shadow_katana.visible = combat_available and is_shadow_equipped and not is_sheathed

	var hip_mesh = player_node.get("_hip_weapon_mesh") as Node3D
	if hip_mesh:
		hip_mesh.visible = combat_available and is_sheathed
