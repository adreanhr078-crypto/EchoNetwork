extends SceneTree

## Isolated actual lab + approved projection images. No character/fun/route claim.
class VisualPhase extends Node:
	var phase := "dormant"

func _initialize() -> void: _run.call_deferred()
func _frames(count: int) -> void:
	for i in count: await process_frame
func _run() -> void:
	root.unfocusable = true
	root.size = Vector2i(1280,720)
	var folder := ProjectSettings.globalize_path("res://../audits/evidence/pre-tripo-20261018/cp37/memory-water-visual/")
	DirAccess.make_dir_recursive_absolute(folder)
	var lab = load("res://scenes/environment/dr_kinja_lab_room.tscn").instantiate()
	root.add_child(lab)
	var phase := VisualPhase.new()
	lab.add_child(phase)
	var observer := CharacterBody3D.new()
	lab.add_child(observer)
	observer.position = Vector3(0,1.2,-15)
	lab.player = observer
	var camera := Camera3D.new()
	camera.fov = 62
	lab.add_child(camera)
	camera.make_current()
	for spec in [["shizuka",-6.8],["yuki",6.8]]:
		var plate := Sprite3D.new()
		plate.texture = load("res://assets/textures/lab-memory/%s-pdf041.webp" % spec[0])
		plate.pixel_size = .003
		plate.position = Vector3(spec[1],1.96,-19.82)
		plate.shaded = false
		lab.add_child(plate)
	var water := preload("res://scripts/environment/memory_reflection_space.gd").new()
	lab.add_child(water)
	water.configure(phase,lab)
	camera.position = Vector3(0,3.8,-8)
	camera.look_at(Vector3(0,1.2,-20))
	await _frames(20)
	root.get_texture().get_image().save_png(folder+"baseline.png")
	phase.phase = "memories"
	for view in [["entry",Vector3(0,3.8,-8),Vector3(0,1.2,-20)],["lateral",Vector3(12,3,-15),Vector3(0,1.2,-22)],["memory",Vector3(2,2.8,-15),Vector3(-7,1.5,-20)]]:
		camera.position = view[1]
		camera.look_at(view[2])
		await _frames(30)
		root.get_texture().get_image().save_png(folder+view[0]+".png")
		water.reflection_view.get_texture().get_image().save_png(folder+view[0]+"-reflection.png")
	if not water.active or get_root().get_camera_3d()!=camera:
		push_error("Water presentation stole the main camera or failed to activate")
		quit(1)
		return
	var previous_elapsed: float = water.elapsed
	lab.reduced_motion = true
	await _frames(8)
	if water.elapsed != previous_elapsed:
		push_error("Reduced Motion did not freeze water clock")
		quit(1)
		return
	phase.phase = "dormant"
	await _frames(2)
	if water.water.visible or water.reflection_view.render_target_update_mode != SubViewport.UPDATE_DISABLED:
		push_error("Rollback retained water or reflection rendering")
		quit(1)
		return
	print("MEMORY_WATER_ISOLATED PASS actual lab/camera/reflection/motion/rollback only; no character or chapter acceptance")
	quit(0)
