extends SceneTree

func _init() -> void:
	print("Checking viewport image capture capability...")
	var vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	
	var camera = Camera3D.new()
	camera.position = Vector3(0, 2, 5)
	vp.add_child(camera)
	
	var mesh = MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	vp.add_child(mesh)
	
	for i in range(5):
		await process_frame
	
	var tex = vp.get_texture()
	if tex:
		var img = tex.get_image()
		if img:
			var path = "C:/Users/yasmo/.gemini/antigravity/brain/1e43e74f-96d2-4240-8c06-cdf56025df12/test_viewport_capture.png"
			var err = img.save_png(path)
			print("Viewport save result: ", err, " saved to: ", path)
		else:
			print("Image was null (needs active rendering driver)")
	else:
		print("Texture was null")
	quit(0)
