extends SceneTree
func _initialize() -> void:
	var n=load("res://scenes/characters/dr_kinga.tscn").instantiate()
	root.add_child(n)
	var s=n.find_child("Skeleton3D",true,false)
	print("KINGA rig=",s)
	if s:
		for i in s.get_bone_count(): print(s.get_bone_name(i)," ",s.get_bone_global_rest(i).origin)
	for m in n.find_children("*","MeshInstance3D",true,false): print("MESH ",m.name," ",m.get_aabb()," transform ",m.global_transform)
	n.free()
	quit()
