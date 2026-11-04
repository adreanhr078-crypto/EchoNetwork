extends SceneTree
var checks:=0
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->bool:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:quit(1)
	return ok
func run()->void:
	root.size=Vector2i(1280,720)
	var owner:=Node3D.new();root.add_child(owner)
	var reflection:=preload("res://scripts/environment/memory_reflection_space.gd").new();owner.add_child(reflection)
	var plane:=MeshInstance3D.new();plane.mesh=PlaneMesh.new();plane.mesh.size=Vector2(4,4);reflection.add_child(plane);reflection.water=plane
	var camera:=Camera3D.new();owner.add_child(camera);camera.position=Vector3(0,2,6);camera.look_at(Vector3.ZERO);camera.make_current()
	await process_frame
	var visible:float=reflection.visible_water_fraction(camera)
	if not check(visible>.02 and visible<1,"Physical water in front intersects the real frustum"):return
	camera.look_at(camera.position+Vector3.UP,Vector3.FORWARD)
	if not check(is_zero_approx(reflection.visible_water_fraction(camera)),"Water behind an upward camera requires no reflection capture"):return
	camera.look_at(Vector3.ZERO)
	owner.position=Vector3(24,3,-17);owner.rotation.y=1.1
	if not check(absf(reflection.visible_water_fraction(camera)-visible)<.0001,"Room transform preserves water screen coverage"):return
	plane.hide()
	if not check(is_zero_approx(reflection.visible_water_fraction(camera)),"Hidden water cannot keep a viewport alive"):return
	plane.show();plane.position=Vector3(0,0,-1000)
	if not check(is_zero_approx(reflection.visible_water_fraction(camera)),"Far-clipped water requires no capture"):return
	plane.position=Vector3(0,0,5.5);camera.position=Vector3(0,.2,6);camera.look_at(owner.to_global(Vector3(0,0,4)))
	var near:float=reflection.visible_water_fraction(camera)
	if not check(is_finite(near) and near>=0 and near<=1,"Near-plane crossing remains finite and bounded"):return
	print("WATER_REFLECTION_FRUSTUM ",checks);quit(0)
