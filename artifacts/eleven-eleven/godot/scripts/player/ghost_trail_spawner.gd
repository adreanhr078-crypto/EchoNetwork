class_name GhostTrailSpawner
extends Node

## A bounded snapshot of the visible, posed skin. Hidden VFX and rest meshes
## cannot become giant phantom geometry. The GPU shares the original skin mesh.
static func spawn_ghost(parent: Node, target_node: Node3D, duration: float=0.24, color: Color=Color(0.52,0.16,0.72,0.14), world_offset: Vector3=Vector3.ZERO) -> void:
	if not parent or not target_node or not parent.is_inside_tree() or not target_node.is_inside_tree(): return
	var controlled := target_node.get_parent()
	if controlled is CharacterBody3D and controlled.has_method("set_mobile_input_vector") and controlled.get("reduced_motion") == true: return
	if parent.get_tree().get_nodes_in_group("echo_motion_ghost").size()>=3: return
	var source_rig:=target_node.find_child("Skeleton3D",true,false) as Skeleton3D
	if not source_rig: return
	var ghost:=Node3D.new()
	ghost.name="PosedMotionEcho"
	parent.add_child(ghost)
	ghost.global_transform=target_node.global_transform
	ghost.add_to_group("echo_motion_ghost")
	var rig:=Skeleton3D.new()
	ghost.add_child(rig)
	rig.global_transform=source_rig.global_transform
	for bone in source_rig.get_bone_count():
		rig.add_bone(source_rig.get_bone_name(bone))
		rig.set_bone_parent(bone,source_rig.get_bone_parent(bone))
		rig.set_bone_rest(bone,source_rig.get_bone_rest(bone))
		var ancestor:=source_rig.get_bone_parent(bone)
		var pose:=source_rig.get_bone_global_pose(bone)
		if ancestor>=0: pose=source_rig.get_bone_global_pose(ancestor).affine_inverse()*pose
		rig.set_bone_pose(bone,pose)
	var ink:=ShaderMaterial.new()
	ink.shader=preload("res://engine_visuals/shaders/motion_echo.gdshader")
	ink.set_shader_parameter("ink_color",Color(color.r,color.g,color.b,1.0))
	ink.set_shader_parameter("opacity",minf(color.a,0.14))
	var hips:=source_rig.find_bone("Hips")
	ink.set_shader_parameter("snapshot_center",source_rig.to_global(source_rig.get_bone_global_pose(hips).origin)+world_offset if hips>=0 else target_node.global_position+world_offset)
	for original: MeshInstance3D in target_node.find_children("*","MeshInstance3D",true,false):
		if not original.mesh or not original.skin or not original.is_visible_in_tree(): continue
		# Wing feathers own a different rig. A body snapshot must never bind
		# that accessory's skin to the body's unrelated bone indices/names.
		if original.get_node_or_null(original.skeleton) != source_rig: continue
		var clone:=MeshInstance3D.new()
		clone.set_meta("source_skin_instance_id",original.get_instance_id())
		clone.mesh=original.mesh
		clone.skin=original.skin
		clone.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		clone.material_override=ink
		ghost.add_child(clone)
		clone.skeleton=clone.get_path_to(rig)
		clone.global_transform=original.global_transform
	ghost.global_position+=world_offset
	var tween:=ghost.create_tween()
	tween.tween_method(func(value:float):ink.set_shader_parameter("opacity",value),float(ink.get_shader_parameter("opacity")),0.0,duration)
	tween.tween_callback(ghost.queue_free)
