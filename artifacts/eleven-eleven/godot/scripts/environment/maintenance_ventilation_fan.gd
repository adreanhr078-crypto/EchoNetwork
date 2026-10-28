extends Node3D

## Rigid machinery reads the existing room presentation clock. It owns no
## interaction,save,physics,character key or animation time source.
const ASSET=preload("res://assets/environments/maintenance_cp45/maintenance_ventilation_fan_pbr.glb")
const KIT=preload("res://scripts/environment/specimen_mechanical_dressing.gd")
const ENVIRONMENT_LAYER=1<<18
var room:Node3D
var rotor:Node3D
var assembly:Node3D

func _ready()->void:
	process_priority=1
	position=Vector3(-4.13,7.65,-6.8)
	rotation.y=PI*.5
	assembly=ASSET.instantiate();add_child(assembly)
	rotor=assembly.find_child("FanPBRRotorPivot",true,false) as Node3D
	assert(is_instance_valid(rotor),"Mechanical rotor pivot missing")
	var meshes:=assembly.find_children("*","MeshInstance3D",true,false)
	assert(meshes.size()==2,"Ventilation source must retain two rigid roles")
	for visual:MeshInstance3D in meshes:
		visual.layers|=ENVIRONMENT_LAYER
		for surface in visual.mesh.get_surface_count():
			var original:StandardMaterial3D=visual.get_active_material(surface)
			# Facility machinery uses the established neutral environment PBR
			# response. The character cel-shadow tint must not turn alloy purple.
			var finish:ShaderMaterial=KIT._texture_finish(original,room)
			finish.set_meta("pbr_source",original)
			visual.set_surface_override_material(surface,finish)
	# Recess backing closes the view through the fan to the existing wall.
	# The rear motor sits inside that unchanged wall;the fixture is above the
	# route atY7.05..8.25 and adds no collision or implied playable surface.
	var duct:=MeshInstance3D.new();duct.name="RecessedDuctBackplate"
	var plane:=QuadMesh.new();plane.size=Vector2(1.10,1.10);duct.mesh=plane
	var finish:=StandardMaterial3D.new();finish.albedo_color=Color(.018,.022,.021);finish.roughness=.88
	duct.material_override=finish;duct.position.z=-.025;duct.layers|=ENVIRONMENT_LAYER;add_child(duct)
	set_meta("presentation_only",true)
	set_meta("source_triangles",1775556)
	set_meta("source_clearance_sample_count",12)
	set_meta("native_front_axis","+Z")

func _process(_delta:float)->void:
	if not is_instance_valid(room) or not is_instance_valid(room.presentation):return
	if not room.presentation._inside_room or room.presentation.reduced_motion:return
	# Stable40rpm equivalent. Pause/RM/absence already freeze this source
	# clock,so resuming never changes gameplay or invents elapsed animation.
	rotor.rotation.z=-fposmod(room.presentation._motion_time*4.2,TAU)
