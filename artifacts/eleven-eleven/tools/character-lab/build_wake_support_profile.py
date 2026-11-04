"""Inspect reach feasibility; visual support intent is an independent hard gate."""
import hashlib
import json
import math
from pathlib import Path

APP = Path(__file__).resolve().parents[2]
CASE = APP/'art/production/echo-school-rebuild-20261029/motions/wake-studio-20261102'
reference = json.loads((CASE/'blender-reference.json').read_text())
gaps = json.loads((CASE/'support-phase-diagnosis.json').read_text())
skin = json.loads((CASE/'native-skin-profile.json').read_text())
assert reference['fps'] == gaps['native_fps'] == 24 and len(reference['samples']) == len(gaps['samples']) == 120
assert gaps['blend_sha256'] == hashlib.sha256((CASE/'single-motion.blend').read_bytes()).hexdigest()
distance = lambda first, second: math.sqrt(sum((a-b)**2 for a,b in zip(first, second)))
hands = {}
for side in ['left', 'right']:
    clearance, reach = [], []
    anchor = reference['samples'][32]['bones'][side+'hand']['position']
    for index, sample in enumerate(reference['samples']):
        points = sample['bones']
        floor = gaps['samples'][index]['target']['floor_before_alignment_m']
        gap = gaps['samples'][index]['target'][side+'_hand_gap_m']
        wrist = points[side+'hand']['position']
        clearance.append(wrist[2]-floor-gap)
        a = list(points[side+'arm']['position'])
        b = points[side+'forearm']['position']
        length = distance(a,b)+distance(b,wrist)
        goal = [anchor[0],anchor[1],clearance[-1]+.002]
        a[2] -= floor
        reach.append(distance(a,goal)/length)
    maximum = max(reach[30:36])
    assert maximum < .985, 'Do not move the torso or stretch bones to force an unreachable support'
    hands[side] = {'anchor_xz':[anchor[0],-anchor[1]], 'wrist_clearance_m':clearance,
                   'envelope_frames':[26,30,35,38], 'native_last_frame':119,
                   'full_support_reach_max':maximum, 'all_native_reach_ratios':reach}
profile = {'status':'UNACCEPTED_REACH_FEASIBILITY_ONLY', 'intent_approved':False, 'source_glb_sha256':skin['source_glb_sha256'],
           'source_blend_sha256':gaps['blend_sha256'], 'native_fps':24,'samples':120,
           'hands':hands,'clearance_m':.002,'reach_limit':.985,
           'intent_review':'Actual native26/28/30/32/34/36/38/40 views reviewed.26..32 includes balance/reaching gestures;reach feasibility does not prove floor-support intent.38..49 floor targets exceed arm reach. The earlier0.32..0.41 floor-lock assertion is not a valid support interval. Do not enable this proposed envelope without a reviewed support source.',
           'scope':'Only the two arm/forearm/hand chains at runtime after source fidelity. No torso,hips,root,scale or source-curve edits.'}
(CASE/'hand-support-profile.json').write_text(json.dumps(profile,indent=2)+'\n')
# Deliberately do not produce importable playback facts for an unreviewed intent.
print(json.dumps({side: hands[side]['full_support_reach_max'] for side in hands}))
