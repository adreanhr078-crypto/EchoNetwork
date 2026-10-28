extends RefCounted

## Complete four-view Tripo architecture inside the original first-wall solid.
## Handholds, collision, traversal, film and state remain authored room owners.
const ASSET=preload("res://assets/environments/maintenance_cp45/maintenance_primary_cassette_pbr4k.glb")
const KIT=preload("res://scripts/environment/specimen_mechanical_dressing.gd")

static func build(room:Node3D,root:Node3D)->void:
	var body:StaticBody3D=room.get_node("COLL_CLIMB_FirstWall")
	var size:Vector3=body.get_child(0).shape.size
	var native:=AABB(body.position-size*.5,size)
	var assembly:Node3D=ASSET.instantiate()
	assembly.name="MeasuredPrimaryTripoCassette"
	assembly.position=body.position
	root.add_child(assembly)
	var meshes:=assembly.find_children("*","MeshInstance3D",true,false)
	assert(meshes.size()==1,"Primary cassette structural role changed")
	assert(assembly.find_children("*","CollisionObject3D",true,false).is_empty(),"Cassette must not own physics")
	for visual:MeshInstance3D in meshes:
		visual.layers|=KIT.ENVIRONMENT_LAYER
		var bounds:AABB=(room.global_transform.affine_inverse()*visual.global_transform)*visual.mesh.get_aabb()
		assert(native.grow(.002).encloses(bounds),"Primary cassette escaped its original solid")
		for surface in visual.mesh.get_surface_count():
			var original:StandardMaterial3D=visual.get_active_material(surface)
			assert(original!=null,"Primary cassette PBR source missing")
			var finish:ShaderMaterial=KIT._texture_finish(original,room)
			# Match the facility's satin alloy under its actual HDR lighting.
			# Retain all source maps while controlling fine normal sparkle and
			# the broad panel highlight that clipped in the first native review.
			finish.set_shader_parameter("base_color",original.albedo_color*Color(.62,.63,.60))
			finish.set_shader_parameter("metalness",original.metallic*.75)
			finish.set_shader_parameter("minimum_roughness",.50)
			finish.set_shader_parameter("normal_strength",original.normal_scale*.45)
			finish.set_meta("pbr_source",original)
			visual.set_surface_override_material(surface,finish)
	assembly.set_meta("native_climb_volume",native)
	assembly.set_meta("source_triangles",1943923)
	assembly.set_meta("source_workspace","bd6b234b-5a6b-44f5-bd19-fa5d6ff03fb8")
	assembly.set_meta("presentation_only",true)
	assembly.set_meta("native_front_axis","+Z")
