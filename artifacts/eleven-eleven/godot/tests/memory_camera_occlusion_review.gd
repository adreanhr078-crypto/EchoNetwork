extends SceneTree
## Regression for the actual non-physical pane that hid Echo in Stormworks.
class Fixture extends Node3D:
	var player: EchoPlayer

func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	var fixture:=Fixture.new();root.add_child(fixture)
	fixture.player=load("res://scenes/player/echo_player.tscn").instantiate()
	fixture.add_child(fixture.player);fixture.player.finish_opening_recovery()
	fixture.player.set_physics_process(false);fixture.player.set_process(false)
	fixture.player.set_gameplay_orbit(Vector3.ZERO)
	fixture.player.player_camera.make_current()
	var director=load("res://engine_visuals/MemoryAtmosphereDirector.gd").new()
	director.main=fixture;fixture.add_child(director);director.set_process(false)
	var surface:=MeshInstance3D.new();surface.mesh=QuadMesh.new();surface.mesh.size=Vector2(2,2)
	surface.custom_aabb=surface.mesh.get_aabb().grow(.12)
	surface.material_override=ShaderMaterial.new();surface.material_override.shader=load("res://engine_visuals/shaders/memory_monitor.gdshader")
	surface.position=Vector3(0,1.2,1.5);fixture.add_child(surface)
	await process_frame
	var checks:=[]
	director._update_surface_visibility(surface,1.0/60)
	checks.append(surface.material_override.get_shader_parameter("camera_visibility")==0.0)
	surface.position.x=4
	director._update_surface_visibility(surface,.1)
	checks.append(is_equal_approx(float(surface.material_override.get_shader_parameter("camera_visibility")),.5))
	director._update_surface_visibility(surface,.1)
	checks.append(surface.material_override.get_shader_parameter("camera_visibility")==1.0)
	surface.position.x=0;director.reduced_motion=true
	director._update_surface_visibility(surface,0)
	checks.append(surface.material_override.get_shader_parameter("camera_visibility")==0.0)
	surface.position.x=4;director._update_surface_visibility(surface,0)
	checks.append(surface.material_override.get_shader_parameter("camera_visibility")==1.0)
	surface.position.x=0;fixture.player.suspend_gameplay_camera()
	director._update_surface_visibility(surface,0)
	checks.append(surface.material_override.get_shader_parameter("camera_visibility")==1.0)
	fixture.player.resume_gameplay_camera(0)
	var cinematic:=Camera3D.new();fixture.add_child(cinematic);cinematic.make_current()
	director._update_surface_visibility(surface,0)
	checks.append(surface.material_override.get_shader_parameter("camera_visibility")==1.0)
	print("MEMORY_CAMERA_OCCLUSION ",checks)
	var passed:=not checks.has(false)
	if not passed:push_error("Memory pane visibility/cinematic/RM regression")
	fixture.queue_free();await process_frame;quit(0 if passed else 1)
