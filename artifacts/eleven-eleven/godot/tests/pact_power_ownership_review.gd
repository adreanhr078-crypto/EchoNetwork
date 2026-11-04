extends "res://tests/zero_encounter_player_review.gd"

## Reuses an earned, explicit-consent save to diagnose public power-button ownership.
func _state(label: String) -> void:
	print("POWER_OWNER ",label," step=",pact.encounter_step," locked=",player.control_locked," recovery=",player.opening_recovery_active," combat=",player.combat_available," attack=",player.is_attacking," attack_recovery=",player._attack_recovery," dodge=",player.is_dodging," charging=",player.is_charging_iai," charge=",player.iai_charge," keyboard=",player._keyboard_charge_owned," scale=",Engine.time_scale)

func _run() -> void:
	root.unfocusable=true
	source_profile=ProjectSettings.globalize_path("res://../audits/evidence/chapter-cp45-20261020/stage11/native-attack-20261023/encounter-final/earned/accepted-integration/")
	if not await _load_fixture(true,"power-owner"):return
	if not _check(pact.encounter_step==6 and room.contract_done,"Earned integration source required"):return
	if not await _press(0):return
	_state("before")
	pact._encounter_power.button_down.emit()
	_state("button-down")
	for tick in 45:
		await physics_frame
		if tick in [0,1,3,15,44]:_state(str(tick))
	if not _check(player.is_charging_iai and player.iai_charge>=.8,"Public power button lost charge ownership"):return
	pact._encounter_power.button_up.emit()
	for tick in 240:
		if pact.encounter_step==8:break
		await physics_frame
	if not _check(pact.encounter_step==8 and not pact.encounter_live,"Public release failed to complete the tutorial"):return
	print("PASS public earned power charge/release ownership")
	quit(0)
