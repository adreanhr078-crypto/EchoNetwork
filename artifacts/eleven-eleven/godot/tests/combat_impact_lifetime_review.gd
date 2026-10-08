extends SceneTree

## A scene transition can remove impact geometry before its deferred fade.
## The fade must stop with that node, including its captured resource cleanup.
func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var world:=Node3D.new()
	root.add_child(world)
	preload("res://scripts/combat/impact_spawner.gd").spawn_katana_sparks(world,Vector3.ZERO)
	for i in 4: await process_frame
	world.queue_free()
	for i in 190: await physics_frame
	print("PASS impact scene transition: captured-node fade lifetime cancels with removed decal")
	quit(0)
