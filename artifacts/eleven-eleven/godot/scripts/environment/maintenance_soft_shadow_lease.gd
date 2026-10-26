extends Node

## Room-local static shadow softness. Preserve the actual previous value and
## release it at native room departure or teardown;never own gameplay/time.
var room:Node3D
var _key:DirectionalLight3D
var _leased:=false
var _prior:=0.0
var _owned:=0.0
func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	_key=room.get_parent().get_node_or_null("DirectionalLight3D") as DirectionalLight3D
func _process(_delta:float)->void:
	if not is_instance_valid(_key):return
	var inside:bool=is_instance_valid(room) and is_instance_valid(room.presentation) and room.presentation._inside_room
	if inside and not _leased:
		_prior=_key.light_angular_distance;_owned=maxf(_prior,1.25)
		_key.light_angular_distance=_owned;_leased=true
	elif not inside:_release()
func _release()->void:
	if _leased and is_instance_valid(_key) and is_equal_approx(_key.light_angular_distance,_owned):_key.light_angular_distance=_prior
	_leased=false
func _exit_tree()->void:_release()
