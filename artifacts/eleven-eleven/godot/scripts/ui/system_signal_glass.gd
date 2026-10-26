extends Control

## Quiet edge reveal, then persistent cracks. Text remains a separate live layer.
var age := 0.0
var reduced_motion := false
var fractured := false
var palette:=Color(.82,.14,.2)
var personal:=false

func set_palette(color: Color, is_personal: bool) -> void:
	palette=color
	personal=is_personal
	queue_redraw()

func begin(reduced: bool, fracture: bool) -> void:
	reduced_motion = reduced
	fractured = fracture
	age = 1.4 if reduced else 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree() or reduced_motion or age >= 1.4: return
	age += delta
	queue_redraw()

func _draw() -> void:
	if size.x <= 0 or size.y <= 0: return
	var reveal := clampf(age/0.45,0,1)
	var ink := Color(palette,0.46*reveal)
	for corner in [Vector2(0,0),Vector2(size.x,0),size,Vector2(0,size.y)]:
		var inward := Vector2(1 if corner.x == 0 else -1,1 if corner.y == 0 else -1)
		draw_line(corner+inward*Vector2(10,10),corner+inward*Vector2(40,10),ink,2,true)
		draw_line(corner+inward*Vector2(10,10),corner+inward*Vector2(10,30),ink,2,true)
		if fractured:
			var crack := clampf((age-0.25)/0.7,0,1)
			var points := PackedVector2Array([corner+inward*Vector2(3,3),corner+inward*Vector2(28,19),corner+inward*Vector2(21,31),corner+inward*Vector2(48,39)])
			for i in range(points.size()-1):
				var part := clampf(crack*3-i,0,1)
				if part>0: draw_line(points[i],points[i].lerp(points[i+1],part),Color(palette,0.28),1,true)
	if personal:
		# Etched side rails and a stable channel marker; no animated text,
		# flashing backdrop, or full-screen chromatic distortion.
		draw_line(Vector2(6,38),Vector2(6,size.y-38),Color(palette,.12),1,true)
		draw_line(Vector2(size.x-6,38),Vector2(size.x-6,size.y-38),Color(palette,.12),1,true)
		var lead:=size.x-14 if is_layout_rtl() else 14.0
		var direction:=-1.0 if is_layout_rtl() else 1.0
		for i in 2:
			draw_line(Vector2(lead+direction*i*6,42),Vector2(lead+direction*i*6,68),Color(palette,.55*reveal),2,true)
		for i in 3:
			draw_circle(Vector2(size.x*.5+(i-1)*8,size.y-10),1.2,Color(palette,.55*reveal))
	if not reduced_motion and age<0.8:
		var x := size.x*clampf(age/0.8,0,1)
		draw_line(Vector2(maxf(0,x-65),1),Vector2(x,1),Color(palette.lightened(.15),.45),1,true)
