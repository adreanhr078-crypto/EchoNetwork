class_name GhostTrailSpawner
extends Node

## Spawns translucent high-speed anime phantom silhouettes (NieR / Genshin style)
## Used during dodge rolls, sprint dashes, and Charged Iai Slashes.

static func spawn_ghost(parent: Node, target_node: Node3D, duration: float = 0.28, color: Color = Color(0.0, 0.94, 1.0, 0.75)) -> void:
	if not parent or not target_node:
		return

	var ghost_root := Node3D.new()
	ghost_root.name = "GhostPhantom"
	ghost_root.global_transform = target_node.global_transform if target_node.is_inside_tree() else target_node.transform

	# Find meshes to duplicate as ghost silhouette
	var mesh_instances: Array = target_node.find_children("*", "MeshInstance3D", true, false)
	for mi in mesh_instances:
		var original_mi := mi as MeshInstance3D
		if not original_mi or not original_mi.mesh:
			continue

		var clone := MeshInstance3D.new()
		clone.mesh = original_mi.mesh
		clone.transform = original_mi.transform

		var ghost_mat := StandardMaterial3D.new()
		ghost_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		ghost_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
		ghost_mat.blend_mode = StandardMaterial3D.BLEND_MODE_ADD
		ghost_mat.albedo_color = color
		ghost_mat.cull_mode = StandardMaterial3D.CULL_DISABLED
		clone.material_override = ghost_mat

		ghost_root.add_child(clone)

	parent.add_child(ghost_root)

	var tree = parent.get_tree() if parent.is_inside_tree() else null
	if tree:
		var tween := tree.create_tween()
		tween.set_parallel(true)
		for child in ghost_root.get_children():
			if child is MeshInstance3D and child.material_override:
				tween.tween_property(child.material_override, "albedo_color:a", 0.0, duration)
		tween.chain().tween_callback(func():
			if is_instance_valid(ghost_root):
				ghost_root.queue_free()
		)
