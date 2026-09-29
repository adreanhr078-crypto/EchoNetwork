extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var holder := Node3D.new()
	var player := CharacterBody3D.new()
	var steps := Node3D.new()
	var args := OS.get_cmdline_user_args()
	steps.set_script(load(args[0] if not args.is_empty() else "res://scripts/player/echo_footstep_system.gd"))
	player.add_child(steps)
	holder.add_child(player)
	root.add_child(holder)
	steps._spawn_step_vfx("metal",Vector3.ZERO)
	if holder.get_child_count() != 2:
		push_error("No footstep effect spawned")
		quit(1)
		return
	holder.queue_free()
	await create_timer(0.5).timeout
	print("PASS footstep lifetime: pending puff cleanup survives room teardown")
	quit()
