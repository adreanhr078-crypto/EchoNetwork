extends Control

## Quiet edge reveal, then persistent cracks. Text remains a separate live layer.
var age := 0.0
var reduced_motion := false
var fractured := false

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
	var ink := Color(0.82,0.14,0.2,0.7*reveal)
	for corner in [Vector2(0,0),Vector2(size.x,0),size,Vector2(0,size.y)]:
		var inward := Vector2(1 if corner.x == 0 else -1,1 if corner.y == 0 else -1)
		draw_line(corner+inward*Vector2(10,10),corner+inward*Vector2(40,10),ink,2,true)
		draw_line(corner+inward*Vector2(10,10),corner+inward*Vector2(10,30),ink,2,true)
		if fractured:
			var crack := clampf((age-0.25)/0.7,0,1)
			var points := PackedVector2Array([corner+inward*Vector2(3,3),corner+inward*Vector2(28,19),corner+inward*Vector2(21,31),corner+inward*Vector2(48,39)])
			for i in range(points.size()-1):
				var part := clampf(crack*3-i,0,1)
				if part>0: draw_line(points[i],points[i].lerp(points[i+1],part),Color(0.9,0.24,0.29,0.6),1,true)
	if not reduced_motion and age<0.8:
		var x := size.x*clampf(age/0.8,0,1)
		draw_line(Vector2(maxf(0,x-65),1),Vector2(x,1),Color(1,0.48,0.48,0.9),2,true)
