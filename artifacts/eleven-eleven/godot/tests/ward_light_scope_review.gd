extends SceneTree
class MainStub extends Node3D:
	var player: Node3D
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var main:=MainStub.new();root.add_child(main)
	main.player=Node3D.new();main.add_child(main.player)
	var facility:=DirectionalLight3D.new();main.add_child(facility)
	var hidden:=DirectionalLight3D.new();main.add_child(hidden);hidden.hide()
	var face:=OmniLight3D.new();face.name="EchoFaceFill";main.player.add_child(face)
	var shoulder:=OmniLight3D.new();shoulder.name="EchoShoulderFill";main.player.add_child(shoulder);shoulder.hide()
	var ward:=Node3D.new();main.add_child(ward)
	var daylight:=DirectionalLight3D.new();ward.add_child(daylight)
	var controller=load("res://scripts/systems/native_campaign_controller.gd").new()
	controller.main=main;controller.hospital=ward
	controller._scope_ward_lights()
	if facility.visible or face.visible or shoulder.visible or not daylight.visible or hidden.visible:
		push_error("Ward light ownership changed an unrelated/ward light");quit(1);return
	controller._scope_ward_lights()
	controller._restore_facility_lights()
	if not facility.visible or not face.visible or shoulder.visible or hidden.visible or not daylight.visible:
		push_error("Repeated ownership did not restore original visibility");quit(1);return
	controller._scope_ward_lights();facility.free();controller._restore_facility_lights()
	if not face.visible or shoulder.visible:
		push_error("Freed light prevented remaining scope restoration");quit(1);return
	var camera:=Camera3D.new();main.add_child(camera);camera.far=4000.0
	controller._scope_ward_camera(camera)
	controller._scope_ward_camera(camera)
	if camera.far!=16.0:
		push_error("Ward camera did not acquire its measured room range");quit(1);return
	controller._restore_ward_camera()
	if camera.far!=4000.0:
		push_error("Repeated ward camera ownership lost the original range");quit(1);return
	controller._scope_ward_camera(camera);camera.free();controller._restore_ward_camera()
	controller.free();main.queue_free()
	print("WARD_LIGHT_SCOPE PASS owned facility/daylight/fills, repeated entry and freed-owner cleanup")
	quit(0)
