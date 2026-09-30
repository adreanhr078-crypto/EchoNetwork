"""Conservative toe-stance diagnostics in Blender world metres and Z-up.

Low height alone is not planting. Compensated horizontal velocity must be low;
airborne/swing intervals remain outside contact measurements. This is evidence,
not a quality approval or a generic motion phase classifier.
"""
import numpy as np


def measure_contacts(positions, roles, fps):
    if len(positions) < 3 or "hips" not in roles:
        return {}
    toes = {side: roles.get(side+"_toe", roles.get(side+"_foot")) for side in ("left", "right")}
    if any(i is None for i in toes.values()):
        return {}
    height_samples = np.concatenate([positions[:, i, 2] for i in toes.values()])
    ground = float(np.quantile(height_samples, .02))
    near_ground = {side: positions[:, i, 2] < ground+.025 for side, i in toes.items()}
    velocities = {side: np.diff(positions[:, i, :2], axis=0)*fps for side, i in toes.items()}
    hips = positions[:, roles["hips"], :2]
    moving_root = np.linalg.norm(hips[-1]-hips[0]) >= .03
    compensation = np.zeros(2)
    if not moving_root:
        engaged = [velocities[s][near_ground[s][:-1] & near_ground[s][1:]] for s in toes]
        engaged = np.concatenate(engaged)
        if len(engaged): compensation = -np.median(engaged, axis=0)
    result = {}
    for side, i in toes.items():
        corrected = velocities[side]+compensation
        mask = near_ground[side][:-1] & near_ground[side][1:] & (np.linalg.norm(corrected, axis=1) < .25)
        intervals = []
        start = None
        for j, active in enumerate(mask):
            if active and start is None: start = j
            if start is not None and (not active or j == len(mask)-1):
                end = j+1 if active else j
                xyz = positions[start:end+1, i, :2]+np.arange(start,end+1)[:,None]*compensation/fps
                intervals.append({"start_frame":start,"end_frame":end,
                                  "world_drift_m":float(np.linalg.norm(xyz-xyz[0],axis=1).max())})
                start = None
        result[side] = {"ground_m":ground,"contact_samples":int(mask.sum()),
                        "fitted_capsule_velocity_xy_mps":compensation.round(4).tolist(),
                        "root_interpretation":"translating" if moving_root else "fitted_in_place",
                        "contact_slide_residual_mps":float(np.sqrt(np.mean(np.sum(corrected[mask]**2,axis=1)))) if mask.sum() >= 3 else None,
                        "contact_intervals":intervals,
                        "contact_method":"near_ground_and_low_compensated_velocity_v2"}
    return result
