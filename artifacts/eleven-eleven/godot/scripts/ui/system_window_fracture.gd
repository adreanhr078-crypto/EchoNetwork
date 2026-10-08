extends RefCounted

## Snapshot only the chosen dialog. Shards never carry interactive state.
static func play(window: Control, panel: Control) -> void:
	if DisplayServer.get_name() == "headless" or not window.is_inside_tree(): return
	var viewport := window.get_viewport()
	var rendered := viewport.get_texture().get_image()
	if not rendered or rendered.is_empty(): return
	var logical := viewport.get_visible_rect().size
	var ratio := Vector2(rendered.get_width(),rendered.get_height())/logical
	var rectangle := panel.get_global_rect()
	var crop := Rect2i(rectangle.position*ratio,rectangle.size*ratio).intersection(Rect2i(Vector2i.ZERO,rendered.get_size()))
	if crop.size.x<=0 or crop.size.y<=0: return
	var texture := ImageTexture.create_from_image(rendered.get_region(crop))
	var layer := CanvasLayer.new()
	layer.name = "SystemWindowFracture"
	layer.layer = 89
	window.get_tree().root.add_child(layer)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1111
	var cell := rectangle.size/Vector2(4,3)
	for row in range(3):
		for column in range(4):
			var origin := Vector2(column,row)*cell
			var vertices := [origin,origin+Vector2(cell.x,0),origin+cell,origin+Vector2(0,cell.y)]
			for indices in [[0,1,2],[0,2,3]]:
				var center: Vector2 = (vertices[indices[0]]+vertices[indices[1]]+vertices[indices[2]])/3
				var shard := Polygon2D.new()
				var points := PackedVector2Array()
				var uv := PackedVector2Array()
				for index in indices:
					points.append(vertices[index]-center)
					uv.append(vertices[index]*ratio)
				shard.polygon = points
				shard.uv = uv
				shard.texture = texture
				shard.position = rectangle.position+center
				layer.add_child(shard)
				var drift := (center-rectangle.size*0.5).normalized()*rng.randf_range(30,70)+Vector2(0,rng.randf_range(30,65))
				var tween := shard.create_tween().set_parallel(true)
				tween.tween_property(shard,"position",shard.position+drift,0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tween.tween_property(shard,"rotation",rng.randf_range(-0.12,0.12),0.55)
				tween.tween_property(shard,"modulate:a",0.0,0.55)
	window.get_tree().create_timer(0.6).timeout.connect(func(): if is_instance_valid(layer): layer.queue_free())
