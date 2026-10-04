extends SceneTree
func _initialize():
 var avatar=load("res://assets/characters/echo_opening_uniform_v13.glb").instantiate()
 root.add_child(avatar)
 var s=avatar.find_child("Skeleton3D",true,false)
 for i in s.get_bone_count(): print(i," ",s.get_bone_name(i)," parent=",s.get_bone_parent(i)," rest=",s.get_bone_global_rest(i).origin)
 avatar.queue_free()
 quit()