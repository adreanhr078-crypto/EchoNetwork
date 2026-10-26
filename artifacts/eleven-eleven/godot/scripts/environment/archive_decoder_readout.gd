extends MeshInstance3D

## Read-only instrument presentation. The room owns collection,decode and
## its pause/Reduced Motion clock;no additional timer or interaction here.
var archive:Node3D
func _process(_delta:float)->void:
	if not is_instance_valid(archive):return
	var finish:ShaderMaterial=material_override
	finish.set_shader_parameter("memories",archive.collected_shards.size())
	finish.set_shader_parameter("decoded",archive.archive_decoded)
	finish.set_shader_parameter("phase",archive._archive_time)
