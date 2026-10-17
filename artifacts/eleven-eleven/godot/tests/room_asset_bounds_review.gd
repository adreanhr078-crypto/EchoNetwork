extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	for path in ["res://assets/props/server_rack.glb","res://assets/props/signal_console_jutsu.glb"]:
		var asset: Node3D = load(path).instantiate()
		root.add_child(asset)
		await process_frame
		var bounds := AABB()
		var found := false
		for visual in asset.find_children("*","MeshInstance3D",true,false):
			var local: AABB = asset.global_transform.affine_inverse()*visual.global_transform*visual.get_aabb()
			bounds = bounds.merge(local) if found else local
			found = true
		print("ASSET_BOUNDS ",path," bounds=",bounds," meshes=",asset.find_children("*","MeshInstance3D",true,false).size())
		asset.queue_free()
	await process_frame
	print("PASS source asset bounds inspection; no scene or asset mutation")
	quit(0)
