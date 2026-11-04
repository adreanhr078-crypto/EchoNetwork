extends RefCounted

## Measured room-local route. Presentation and saves share this layout revision.
const REVISION := "stormworks-20261027-v3"
const SECURITY_LOCAL_ORIGIN := Vector3(0,5.5,-19.25)
const FIRST_MANTLE := AABB(Vector3(-1.8,2,-6.3),Vector3(1.4,.65,1.6))
const FINAL_MANTLE := AABB(Vector3(-2.5,5.4,-17.3),Vector3(1.55,.65,1.1))
const VAULT_LANDING := AABB(Vector3(-4.5,2.65,-16.4),Vector3(1.1,.7,.65))
const EXIT_REGION := AABB(Vector3(-.65,5.4,-19.1),Vector3(1.3,.65,.6))
const HANDOFF_REGION := AABB(Vector3(-.65,5.4,-19.75),Vector3(1.3,.65,.75))
const GAP_BROAD := [
	AABB(Vector3(-5.95,1.95,-9.1),Vector3(1.95,.8,2.2)),
	AABB(Vector3(-4.45,1.95,-12.7),Vector3(1.9,.8,2.2)),
	AABB(Vector3(-3.1,2.7,-15.4),Vector3(1.8,.75,1.9))]
const GAP_SAFE := [
	AABB(Vector3(-5.65,1.95,-8.85),Vector3(1.35,.8,1.5)),
	AABB(Vector3(-4.1,1.95,-12.3),Vector3(1.2,.8,1.4)),
	AABB(Vector3(-2.95,2.7,-15.3),Vector3(1.2,.75,1.05))]

static func anchor(stage: int, step: int) -> Vector3:
	if stage == 2:
		return [Vector3(-1.15,2.3,-5.58),Vector3(-4.95,2.3,-8),Vector3(-3.5,2.3,-11.6)][clampi(step,0,2)]
	return [Vector3(0,.1,-3.4),Vector3(0,.1,-3.4),Vector3.ZERO,
		Vector3(-2.3,3.08,-14.65),Vector3(-4,3.02,-16.06),
		Vector3(-1.8,5.65,-16.725),Vector3(1.25,5.65,-17.46),
		Vector3(0,5.65,-18.85)][clampi(stage,0,7)]

static func minimum_retry_height(stage: int, step: int) -> float:
	# The chamber has a solid floor at y=0. Once the elevated course is earned,
	# falling onto that floor must retry rather than strand the player below it.
	# All authored landings are within 0.15m of their checkpoint height; leave
	# 1.2m clearance for jump, vault and native mantle capsule travel.
	return anchor(stage,step).y-1.2 if stage >= 2 else -0.18
