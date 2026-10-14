extends Node3D

## Camera-only inspection of the already stamped skin. No skeleton pose,
## mesh, source keys, player transform or importer is changed by this scope.
var actor:Node3D
var skeleton:Skeleton3D
var camera:Camera3D
var return_camera:Camera3D
var neck_index:=-1
var report:Dictionary={}
var local_forward := Vector3.ZERO
var _ink_bind_points: Dictionary = {}

func begin(model:Node3D, previous:Camera3D) -> bool:
	actor=model
	report=actor.placement_report
	skeleton=actor.find_child("Skeleton3D",true,false) as Skeleton3D
	if not skeleton or report.is_empty(): return false
	var profile := preload("res://scripts/player/echo_rig_profile.gd").identify(skeleton)
	if profile.is_empty(): return false
	local_forward = profile.local_forward
	neck_index=skeleton.find_bone(String(report.get("bone","")))
	if neck_index<0 or not report.get("native_skin",false): return false
	_prepare_ink_centroid()
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
	var outward:Vector3=Basis(Vector3.UP,-angle)*local_forward
	var deformation:=skeleton.get_bone_global_pose(neck_index)*skeleton.get_bone_global_rest(neck_index).affine_inverse()
	var focus:Vector3=skeleton.to_global(deformation*(point+outward*0.02))
	if not _ink_bind_points.is_empty():
		var ink_center := Vector3.ZERO
		for bone in _ink_bind_points:
			var pose := skeleton.get_bone_global_pose(bone)
			var data: Dictionary = _ink_bind_points[bone]
			ink_center += pose.basis * data.point + pose.origin * data.weight
		focus = skeleton.to_global(ink_center)
	var direction:Vector3=(skeleton.global_basis*deformation.basis*outward).normalized()
	var up:Vector3=(skeleton.global_basis*deformation.basis*Vector3.UP).normalized()
	# Reserve the lower frame for the readable confirmation panel.
	# The adopted high collar exposes a much shorter patch than the legacy neck.
	# Keep its measured ink centroid in frame rather than looking down at cloth.
	var margin := 0.005 if report.get("rig_profile", "") == "echo_v31_authored_68" else 0.035
	focus-=up*margin
	camera.global_position=focus+direction*0.30+up*0.014
	camera.look_at(focus,up)

func restore_camera() -> void:
	if is_instance_valid(return_camera): return_camera.current=true

func _prepare_ink_centroid() -> void:
	# Cache the glyphs' actual GPU skin weights once. Neck-only rigid mapping
	# can aim under a high collar when head/spine also deform the stamped skin.
	var records: Array = actor.projection_records
	var body := actor.find_child(str(report.body_mesh),true,false) as MeshInstance3D
	if records.is_empty() or not body or not body.skin: return
	var arrays := body.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per_vertex: int = bones.size()/points.size()
	var divisor: float = records.size()
	for record in records:
		for corner in 3:
			var vertex: int = record.ids[corner]
			var bary: float = record.bary[corner]
			for influence in per_vertex:
				var offset: int = vertex*per_vertex+influence
				var weight: float = bary*weights[offset]/divisor
				if weight <= 0: continue
				var bind: int = bones[offset]
				var bone: int = body.skin.get_bind_bone(bind)
				if bone < 0: bone = skeleton.find_bone(body.skin.get_bind_name(bind))
				if bone < 0: continue
				if not _ink_bind_points.has(bone): _ink_bind_points[bone] = {"point":Vector3.ZERO,"weight":0.0}
				_ink_bind_points[bone].point += (body.skin.get_bind_pose(bind)*points[vertex])*weight
				_ink_bind_points[bone].weight += weight
