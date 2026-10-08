extends Node3D

## Camera-only inspection of the already stamped skin. No skeleton pose,
## mesh, source keys, player transform or importer is changed by this scope.
var actor:Node3D
var skeleton:Skeleton3D
var camera:Camera3D
var return_camera:Camera3D
var neck_index:=-1
var report:Dictionary={}

func begin(model:Node3D, previous:Camera3D) -> bool:
	actor=model
	report=actor.placement_report
	skeleton=actor.find_child("Skeleton3D",true,false) as Skeleton3D
	if not skeleton or report.is_empty(): return false
	neck_index=skeleton.find_bone(String(report.get("bone","")))
	if neck_index<0 or not report.get("native_skin",false): return false
	return_camera=previous
	camera=Camera3D.new()
	camera.name="ActualSkinInspection"
	camera.fov=35.0
	camera.near=0.015
	camera.environment=previous.environment
	add_child(camera)
	_update_camera()
	camera.current=true
	return true

func _process(_delta:float) -> void:
	if is_instance_valid(actor) and is_instance_valid(skeleton) and camera: _update_camera()

func _update_camera() -> void:
	var center:Array=report.rest_center
	var point:=Vector3(center[0],center[1],center[2])
	var angle:float=deg_to_rad(report.angle_degrees)
	var outward:=Vector3(cos(angle),0,sin(angle))
	var deformation:=skeleton.get_bone_global_pose(neck_index)*skeleton.get_bone_global_rest(neck_index).affine_inverse()
	var focus:Vector3=skeleton.to_global(deformation*(point+outward*0.02))
	var direction:Vector3=(skeleton.global_basis*deformation.basis*outward).normalized()
	var up:Vector3=(skeleton.global_basis*deformation.basis*Vector3.UP).normalized()
	# Reserve the lower frame for the readable confirmation panel.
	focus-=up*0.035
	camera.global_position=focus+direction*0.30+up*0.014
	camera.look_at(focus,up)

func restore_camera() -> void:
	if is_instance_valid(return_camera): return_camera.current=true
