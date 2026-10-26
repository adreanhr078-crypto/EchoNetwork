extends MeshInstance3D

## The existing reactor owns breaker truth and its accessibility-safe clock.
var reactor:Node3D
var instrument:=0
func _process(_delta:float)->void:
	sync_state()

func sync_state()->void:
	if not is_instance_valid(reactor):return
	var finish:ShaderMaterial=material_override
	finish.set_shader_parameter("relay_a",1.0 if reactor.breaker_a_done else 0.0)
	finish.set_shader_parameter("relay_b",1.0 if reactor.breaker_b_done else 0.0)
	finish.set_shader_parameter("instrument",instrument)
	finish.set_shader_parameter("phase",reactor._reactor_time)
