"""Explicit joint mapping for the inspected Mixamo/Motus and Rokoko rigs."""
from bone_roles import normalize
import math


def planar_yaw(source, target):
    if math.hypot(source[0],source[1]) < 1e-6 or math.hypot(target[0],target[1]) < 1e-6:
        raise ValueError('Cannot establish planar character forward')
    return math.atan2(target[1],target[0])-math.atan2(source[1],source[0])


def joint_map(names):
    keys = [normalize(name) for name in names]
    # Rokoko's LeftLeg is the thigh, unlike Mixamo's LeftLeg (the shin).
    rokoko = 'leftshin' in keys and 'rightshin' in keys
    aliases = {'spine1': 'spine', 'spine2': 'spine1', 'chest': 'spine2',
               'neck1': 'neck', 'leftleg': 'leftupleg', 'rightleg': 'rightupleg',
               'leftshin': 'leftleg', 'rightshin': 'rightleg'} if rokoko else {}
    if 'thighl' in keys and 'calfl' in keys and 'thighr' in keys and 'calfr' in keys:
        aliases.update(pelvis='hips', spine01='spine', spine02='spine1', spine03='spine2', neck01='neck')
        for side, suffix in [('left','l'),('right','r')]:
            aliases.update({name+suffix:side+joint for name,joint in
                            [('clavicle','shoulder'),('upperarm','arm'),('lowerarm','forearm'),
                             ('hand','hand'),('thigh','upleg'),('calf','leg'),('foot','foot'),('ball','toebase')]})
    result = {}
    for name, key in zip(names, keys):
        key = aliases.get(key, key)
        if key in result:
            raise ValueError(f'Ambiguous retarget joint: {key}')
        result[key] = name
    return result
