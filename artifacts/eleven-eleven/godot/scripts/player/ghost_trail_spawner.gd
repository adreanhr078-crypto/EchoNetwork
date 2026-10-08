class_name GhostTrailSpawner
extends Node

## A bounded snapshot of the visible, posed skin. Hidden VFX and rest meshes
## cannot become giant phantom geometry. The GPU shares the original skin mesh.
static func spawn_ghost(parent: Node, target_node: Node3D, duration: float=0.24, color: Color=Color(0.52,0.16,0.72,0.14)) -> void:
	if not parent or not target_node or not parent.is_inside_tree() or not target_node.is_inside_tree(): return
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
	var ink:=StandardMaterial3D.new()
	ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	ink.blend_mode=BaseMaterial3D.BLEND_MODE_MIX
	ink.albedo_color=Color(color.r,color.g,color.b,minf(color.a,0.14))
	for original: MeshInstance3D in target_node.find_children("*","MeshInstance3D",true,false):
		if not original.mesh or not original.skin or not original.is_visible_in_tree(): continue
		var clone:=MeshInstance3D.new()
		clone.mesh=original.mesh
		clone.skin=original.skin
		clone.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		clone.material_override=ink
		ghost.add_child(clone)
		clone.skeleton=clone.get_path_to(rig)
		clone.global_transform=original.global_transform
	var tween:=ghost.create_tween()
	tween.tween_property(ink,"albedo_color:a",0.0,duration)
	tween.tween_callback(ghost.queue_free)
