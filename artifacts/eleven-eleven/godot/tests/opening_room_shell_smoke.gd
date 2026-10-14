extends SceneTree

const Main = preload("res://scripts/main.gd")
class EmbeddedMain extends Main:
	func _requires_web_configuration() -> bool: return true

var checks := 0
func _initialize() -> void: _run.call_deferred()
func check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		push_error(message)
		quit(1)
	return condition
func snapshot(shell: Node3D) -> Array:
	var records := []
	for child in shell.find_children("*", "Node3D",true,false):
		if child is MeshInstance3D or child is CollisionShape3D:
			records.append([str(child.global_transform),child.get_class(),str(child.mesh.get_aabb()) if child is MeshInstance3D else str(child.shape.get_debug_mesh().get_aabb())])
	return records
func _run() -> void:
	var baseline: Array
	for path in ["res://scenes/opening_web_room.tscn","res://scenes/opening_native_room.tscn"]:
		var main = load(path).instantiate()
		main.set_script(EmbeddedMain)
		main.native_session_enabled=false
		root.add_child(main)
		for unused in 3: await physics_frame
		var shells: Array[Node] = main.find_children("Sector11OpeningShell", "",true,false)
		if not check(shells.size()==1,"Opening must contain exactly one shell, including the inherited native scene"): return
		var shell: Node3D = shells[0]
		if not check(shell.opening_only and shell.get_node_or_null("WestContainmentWall") != null and shell.get_node_or_null("EastContainmentWall") != null and shell.get_node_or_null("SouthContainmentWall_Body") != null, "Opening shell lost its physical enclosure"): return
		var geometry := snapshot(shell)
		if not check(geometry.size()>50,"Existing architectural detail and collision shell did not initialize"): return
		if baseline.is_empty(): baseline=geometry
		elif not check(geometry==baseline,"Web and native opening architecture differ or the native shell was duplicated"): return
		if not check(main.is_web_configuration_pending() and not main.can_process(),"Architecture reuse released the pending configuration gate"): return
		# Disabled CollisionObject3D nodes are removed from the physics space.
		# Verify enclosure only after the real valid handoff restores the scene.
		main.opening_web_handoff._apply_configuration({"source":"11-11-web","type":"configure","bridgeVersion":1,"nonce":"shell-review","coverVerified":true,"locale":"en","muted":true,"reducedMotion":true})
		for unused in 3: await physics_frame
		# Isolate the reused shell's physical contribution: other opening props
		# and the still-locked gameplay gate remain owned by their own systems.
		var excluded: Array[RID] = []
		for body in main.find_children("*","PhysicsBody3D",true,false):
			if not shell.is_ancestor_of(body): excluded.append(body.get_rid())
		var world: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(Vector3(0,3,-8),Vector3(10,3,-8))
		query.exclude=excluded
		var hit := world.intersect_ray(query)
		if not check(not hit.is_empty() and shell.is_ancestor_of(hit.collider),"Reused east enclosure has no working collision"): return
		query.from=Vector3(0,2,-17.4)
		query.to=Vector3(0,2,-18.6)
		if not check(world.intersect_ray(query).is_empty(),"Decorative shell sealed the actual authored gate opening"): return
		main.queue_free()
		for unused in 3: await process_frame
	print("PASS opening shell: %d checks; one existing shell, Web/native visual and collider parity, containment collision, authored gate gap and pending input gate" % checks)
	quit(0)
