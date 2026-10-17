extends SceneTree

class RoomFixture extends Node3D:
	var reduced_motion:=true

var failures:=0
func check(ok:bool,message:String)->void:
	if not ok:
		failures+=1
		push_error(message)
func _initialize()->void:_run.call_deferred()
func actor()->Node3D:
	var instance=load("res://scenes/characters/dr_kinga.tscn").instantiate()
	instance.set_script(load("res://scripts/characters/kinja_revenge_actor.gd"))
	return instance
func surface(model:Node)->MeshInstance3D:
	return model.find_child("KinjaPreservedScientistSurface",true,false) as MeshInstance3D
func _run()->void:
	var path:="res://assets/characters/kinja_revenge_rig_v1.glb"
	var source_hash:=FileAccess.get_sha256(path)
	var source_model:Node3D=load(path).instantiate()
	var original:=surface(source_model).get_active_material(0) as BaseMaterial3D
	var original_metal:=original.metallic
	var room:=RoomFixture.new()
	root.add_child(room)
	var first:=actor()
	var second:=actor()
	second.position.x=5
	room.add_child(first)
	room.add_child(second)
	for i in 4:await process_frame
	var mat:=surface(first.get_node("KinjaReviewedRevengeRig")).get_active_material(0) as ShaderMaterial
	var other:=surface(second.get_node("KinjaReviewedRevengeRig")).get_active_material(0) as ShaderMaterial
	check(mat!=null and other!=null,"Actual campaign actor did not install the qualified material")
	if mat and other:
		check(mat!=other,"Two Kinja instances share a mutable material")
		check(mat.next_pass==null,"Material finish added a geometry pass")
		check(mat.get_shader_parameter("albedo_texture")==original.albedo_texture,"Authored color atlas was replaced")
		check(mat.get_shader_parameter("normal_texture")==original.normal_texture,"Authored normal map was replaced")
		check(mat.get_shader_parameter("roughness_texture")==original.roughness_texture,"Authored roughness map was replaced")
		check(mat.get_shader_parameter("metallic_texture")==original.metallic_texture,"Authored metal map was replaced")
		check(mat.get_shader_parameter("roughness_channel")==ShaderApplicator._texture_channel(original.roughness_texture_channel),"Roughness channel changed")
		check(mat.get_shader_parameter("metallic_channel")==ShaderApplicator._texture_channel(original.metallic_texture_channel),"Metal channel changed")
		check(mat.get_shader_parameter("normal_depth")==original.normal_scale,"Normal strength changed")
		check(is_equal_approx(float(mat.get_shader_parameter("diffuse_light_ceiling")),.65),"Kinja direct-light ceiling was not installed")
		check(mat.get_shader_parameter("normalize_light_response")==true,"Kinja reverted to double albedo or unnormalized light units")
		mat.set_shader_parameter("specular_color",Color.BLACK)
		check(other.get_shader_parameter("specular_color")==Color(.18,.18,.18),"One actor mutated another actor's profile")
	check(not original.ao_enabled,"Current source gained AO that needs explicit mapping before conversion")
	check(original.metallic==original_metal and original is StandardMaterial3D,"Imported source resource was mutated")
	check(first.trauma_pose.skeleton.get_bone_count()==33,"Material finish altered the Kinja skeleton")
	check(FileAccess.get_sha256(path)==source_hash,"Material finish changed the source asset")
	var echo:=ShaderApplicator._make_stylized_material(original,load("res://shaders/anime_cel.gdshader"),Color.WHITE,Color.WHITE,Color.GRAY,3,.1,null,"EchoV31BodyAndCoat")
	# Unset material parameters return null; the shader owns their zero default.
	var diffuse_default:Variant=echo.get_shader_parameter("diffuse_light_ceiling")
	var specular_default:Variant=echo.get_shader_parameter("specular_light_ceiling")
	check(diffuse_default==null or is_zero_approx(diffuse_default),"Existing Echo materials inherited Kinja's optional ceiling")
	check(specular_default==null or is_zero_approx(specular_default),"Existing Echo specular response changed")
	source_model.free()
	room.queue_free()
	for i in 5:await process_frame
	print("Kinja surface profile failures=",failures,"; actual actor, source/maps/channels/skeleton, resource isolation and unchanged Echo defaults")
	quit(1 if failures else 0)
