extends "res://tests/player_motion_regression.gd"
func _drive(stick:Vector2,frames:int) -> void:
	if OS.get_cmdline_user_args().has("--idle-clock"):
		player.animation_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	print("DIAG_START ",stick," ",player.global_position," velocity=",player.velocity)
	await super._drive(stick,frames)
	print("DIAG_END ",stick," ",player.global_position," velocity=",player.velocity," skid=",player.locomotion_controller.is_skidding," clip=",player.current_anim)
func _check(ok:bool,message:String) -> void:
	if not ok and not failures.has(message):
		print("DIAG_FAILURE ",message," position=",player.global_position," velocity=",player.velocity," input=",player.resolve_movement_input()," floor=",player.is_on_floor()," camera=",player.player_camera.global_rotation," visual=",player.visual_root.global_rotation)
	super._check(ok,message)
