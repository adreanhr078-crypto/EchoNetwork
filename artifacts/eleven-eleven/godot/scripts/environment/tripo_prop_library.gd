class_name TripoPropLibrary
extends RefCounted

## Tripo Prop Visual Integration Library (2026-10-08)
## Non-destructive visual replacement API for EchoNetwork environment props.
## Strictly preserves all collision physics (StaticBody3D, CollisionShape3D),
## interaction areas (Area3D), and trigger components (InteractableComponent).

const DIAGNOSTIC_CART_SCENE: PackedScene = preload("res://assets/props/diagnostic_cart_tripo_20261008.glb")
const SECURITY_TERMINAL_SCENE: PackedScene = preload("res://assets/props/security_terminal_tripo_20261008.glb")
const OBSERVATION_SERVER_SCENE: PackedScene = preload("res://assets/props/observation_server_tripo_20261008.glb")
const MEDICAL_WALL_UNIT_SCENE: PackedScene = preload("res://assets/props/medical_wall_unit_tripo_20261008.glb")

const TRIPO_VISUAL_NODE_NAME := "TripoVisual"
const META_HIDDEN_VISUALS := "tripo_hidden_nodes"
const META_PROP_ID := "tripo_prop_id"

const PROP_REGISTRY := {
	"diagnostic_cart": DIAGNOSTIC_CART_SCENE,
	"cart": DIAGNOSTIC_CART_SCENE,
	"mobile_cart": DIAGNOSTIC_CART_SCENE,
	"trolley": DIAGNOSTIC_CART_SCENE,
	"security_terminal": SECURITY_TERMINAL_SCENE,
	"terminal": SECURITY_TERMINAL_SCENE,
	"console": SECURITY_TERMINAL_SCENE,
	"substation_terminal": SECURITY_TERMINAL_SCENE,
	"observation_server": OBSERVATION_SERVER_SCENE,
	"server": OBSERVATION_SERVER_SCENE,
	"server_rack": OBSERVATION_SERVER_SCENE,
	"medical_wall_unit": MEDICAL_WALL_UNIT_SCENE,
	"wall_unit": MEDICAL_WALL_UNIT_SCENE,
	"medical_unit": MEDICAL_WALL_UNIT_SCENE,
}

static func get_available_prop_ids() -> Array[String]:
	return [
		"diagnostic_cart",
		"security_terminal",
		"observation_server",
		"medical_wall_unit"
	]

static func has_prop(prop_id: String) -> bool:
	return PROP_REGISTRY.has(prop_id.to_lower().strip_edges())

static func get_prop_scene(prop_id: String) -> PackedScene:
	var key := prop_id.to_lower().strip_edges()
	if PROP_REGISTRY.has(key):
		return PROP_REGISTRY[key]
	return null

static func _is_protected_node(node: Node) -> bool:
	if not node:
		return false
	if node.name == TRIPO_VISUAL_NODE_NAME:
		return true
	if node is Light3D:
		return true
	if node is Label3D:
		return true
	if node is CollisionShape3D or node is CollisionPolygon3D or node is CollisionObject3D or node is Area3D:
		return true
	var lower_name := node.name.to_lower()
	var clean_name := lower_name.replace("_", "")
	if clean_name.begins_with("screenreadout") or clean_name.begins_with("terminalscreen"):
		return true
	if clean_name.begins_with("screenmesh") or clean_name.ends_with("screenmesh") or clean_name == "screen":
		return true
	return false

static func _has_protected_descendants(node: Node) -> bool:
	if not node:
		return false
	for child in node.get_children():
		if _is_protected_node(child):
			return true
		if _has_protected_descendants(child):
			return true
	return false

static func _process_visual_candidate(node: Node, target_node: Node3D, hidden_paths: Array[NodePath]) -> void:
	if not node or _is_protected_node(node):
		return

	# If the candidate has NO protected descendants:
	if not _has_protected_descendants(node):
		if node.get("visible") != null and node.visible:
			node.visible = false
			hidden_paths.append(target_node.get_path_to(node))
		return

	# If it DOES have protected descendants:
	# Ensure the container itself is NOT hidden, so descendant lights, labels,
	# screen readouts, and interaction shapes remain visible and active in the scene tree.
	# We recursively inspect and hide only non-protected visual meshes.
	for child in node.get_children():
		if _is_protected_node(child):
			continue
		if child is MeshInstance3D or child is CSGShape3D or child.name.to_lower().contains("visual") or child.name.to_lower().contains("mesh") or child.name.to_lower().contains("container") or child.name.to_lower().contains("prop"):
			_process_visual_candidate(child, target_node, hidden_paths)

## Non-destructively replaces the visual mesh of target_node with the specified Tripo model.
## Existing colliders, interaction triggers, lights, and UI readouts remain intact.
static func replace_prop_visual(target_node: Node3D, prop_id: String) -> Node3D:
	if not target_node:
		push_error("TripoPropLibrary: target_node is null")
		return null

	var scene := get_prop_scene(prop_id)
	if not scene:
		push_error("TripoPropLibrary: Unknown prop_id '%s'" % prop_id)
		return null

	# Remove any existing TripoVisual on this node
	var existing_visual := target_node.get_node_or_null(TRIPO_VISUAL_NODE_NAME)
	if existing_visual:
		target_node.remove_child(existing_visual)
		existing_visual.queue_free()

	# Identify original visual child nodes to hide without touching collision shapes,
	# interaction areas, lights, labels, or screen readouts.
	# If target_node already has META_HIDDEN_VISUALS from a prior replacement, do NOT overwrite it!
	if not target_node.has_meta(META_HIDDEN_VISUALS):
		var hidden_paths: Array[NodePath] = []
		for child in target_node.get_children():
			if _is_protected_node(child):
				continue

			# Candidate visual containers (e.g. ConsoleVisual, server_rack, MeshInstance3D, CSGShape3D)
			if child.name == "ConsoleVisual" or child.name == "server_rack" or child is MeshInstance3D or child is CSGShape3D or child.name.to_lower().contains("visual") or child.name.to_lower().contains("mesh") or child.name.to_lower().contains("container") or child.name.to_lower().contains("prop"):
				_process_visual_candidate(child, target_node, hidden_paths)

		target_node.set_meta(META_HIDDEN_VISUALS, hidden_paths)

	target_node.set_meta(META_PROP_ID, prop_id)

	# Instantiate Tripo visual model
	var visual_instance := scene.instantiate() as Node3D
	if not visual_instance:
		push_error("TripoPropLibrary: Failed to instantiate prop scene '%s'" % prop_id)
		return null

	visual_instance.name = TRIPO_VISUAL_NODE_NAME
	target_node.add_child(visual_instance)
	return visual_instance

## Restores the original visual node(s) and removes the TripoVisual node.
static func restore_prop_visual(target_node: Node3D) -> bool:
	if not target_node:
		return false

	var visual_node := target_node.get_node_or_null(TRIPO_VISUAL_NODE_NAME)
	if visual_node:
		target_node.remove_child(visual_node)
		visual_node.queue_free()

	# Only restore visibility to nodes that were ACTUALLY recorded in the original hidden list
	if target_node.has_meta(META_HIDDEN_VISUALS):
		var hidden_paths = target_node.get_meta(META_HIDDEN_VISUALS) as Array
		for path in hidden_paths:
			var node := target_node.get_node_or_null(path)
			if node and node.get("visible") != null:
				node.visible = true
		target_node.remove_meta(META_HIDDEN_VISUALS)

	if target_node.has_meta(META_PROP_ID):
		target_node.remove_meta(META_PROP_ID)

	return true

## Recursively inspects a room/environment node and replaces known props with Tripo visuals.
static func apply_prop_visuals(room_node: Node3D) -> Dictionary:
	var result := {
		"success": true,
		"replaced_count": 0,
		"replaced_paths": []
	}

	if not room_node:
		result["success"] = false
		return result

	_apply_to_node_recursive(room_node, room_node, result)
	return result

static func _apply_to_node_recursive(current: Node, room_root: Node3D, result: Dictionary) -> void:
	if current is Node3D:
		var node_name := current.name.to_lower()
		var replaced := false

		# Check 1: Terminal / Console
		if current.has_node("ConsoleVisual") or node_name.contains("terminal") or node_name.contains("substation"):
			if not current.has_node(TRIPO_VISUAL_NODE_NAME):
				var vis := replace_prop_visual(current as Node3D, "security_terminal")
				if vis:
					result["replaced_count"] += 1
					result["replaced_paths"].append(str(room_root.get_path_to(current)))
					replaced = true

		# Check 2: Server Rack / Observation Server
		elif current.has_node("server_rack") or (node_name.contains("server") and not node_name.contains("manager")):
			if not current.has_node(TRIPO_VISUAL_NODE_NAME):
				var vis := replace_prop_visual(current as Node3D, "observation_server")
				if vis:
					result["replaced_count"] += 1
					result["replaced_paths"].append(str(room_root.get_path_to(current)))
					replaced = true

		# Check 3: Diagnostic Cart / Mobile Cart
		elif node_name.contains("cart") or node_name.contains("trolley"):
			if not current.has_node(TRIPO_VISUAL_NODE_NAME):
				var vis := replace_prop_visual(current as Node3D, "diagnostic_cart")
				if vis:
					result["replaced_count"] += 1
					result["replaced_paths"].append(str(room_root.get_path_to(current)))
					replaced = true

		# Check 4: Medical Wall Unit
		elif node_name.contains("wall_unit") or (node_name.contains("medical") and node_name.contains("unit")):
			if not current.has_node(TRIPO_VISUAL_NODE_NAME):
				var vis := replace_prop_visual(current as Node3D, "medical_wall_unit")
				if vis:
					result["replaced_count"] += 1
					result["replaced_paths"].append(str(room_root.get_path_to(current)))
					replaced = true

	for child in current.get_children():
		_apply_to_node_recursive(child, room_root, result)

## Verifies that all CollisionShape3D and interaction areas under root_node remain intact and enabled.
static func verify_colliders_intact(root_node: Node) -> bool:
	if not root_node:
		return false

	var colliders := root_node.find_children("*", "CollisionShape3D", true, false)
	for col in colliders:
		var c := col as CollisionShape3D
		if not c or c.shape == null:
			push_error("verify_colliders_intact: Found CollisionShape3D with null shape at %s" % col.get_path())
			return false

	# Verify interaction areas are present and have shapes
	var areas := root_node.find_children("*", "Area3D", true, false)
	for area in areas:
		var a := area as Area3D
		var sub_colliders := a.find_children("*", "CollisionShape3D", true, false)
		if sub_colliders.is_empty():
			# Check for CollisionPolygon3D
			var sub_polys := a.find_children("*", "CollisionPolygon3D", true, false)
			if sub_polys.is_empty():
				push_error("verify_colliders_intact: Area3D has no collision shape at %s" % a.get_path())
				return false

	return true
