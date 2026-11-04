"""Select one existing glTF take, then use the independent native skin reviewer."""
from pathlib import Path
import hashlib,json

app=Path(__file__).resolve().parents[2]
original=app/'tools/animation-library/render_native_gltf_skin.py'
code=original.read_text(encoding='utf-8')
old='action = rig.animation_data.action\nassert action, \'No imported authored action\''
new='''matches=[item for item in bpy.data.actions if item.name==reference['action']]
assert len(matches)==1, 'Original named take is ambiguous or missing'
action=matches[0]
rig.animation_data_create()
for track in rig.animation_data.nla_tracks: track.mute=True
rig.animation_data.action=action
if action.is_action_layered:
    assert len(action.slots)==1, 'Ambiguous source action slot'
    rig.animation_data.action_slot=action.slots[0]'''
if code.count(old)!=1: raise ValueError('Existing source reviewer changed')
namespace={'__name__':'__main__','__file__':str(original)}
exec(compile(code.replace(old,new),str(original),'exec'),namespace)
out=namespace['a'].output
(out/'selected-take-provenance.json').write_text(json.dumps({
    'original_reviewer_sha256':hashlib.sha256(original.read_bytes()).hexdigest(),
    'scope':'Named take/action slot selection only;unchanged independent raw sample guard/render;source file andkeys untouched'},indent=2)+'\n')
