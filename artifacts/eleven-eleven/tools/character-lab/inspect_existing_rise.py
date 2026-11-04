"""Read original 24 Hz FBX rise takes without modifying or baking them."""
from pathlib import Path
import bpy,hashlib,json,sys
app=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(app/'tools/animation-library'))
from native_timing import read_native_fps
from golden_reference import verify
verify()
manifest=app/'art/production/master-animation-library/manifests'
inventory=json.loads((manifest/'SourceInventory.json').read_text())['files']
candidates=json.loads((manifest/'CandidateReviews.json').read_text())['candidates']
out=app/'art/production/echo-school-rebuild-20261029/motions/wake-existing-source-diagnosis'
out.mkdir(exist_ok=True)
for filename in ['Rise_01_mixamo.fbx','Rise_02_mixamo.fbx','NinjaRise_mixamo.fbx']:
    candidate=next(x for x in candidates if x['original_filename']==filename)
    entry=next(x for x in inventory if x['sha256']==candidate['file_sha256'])
    source=app/entry['working_copy']
    assert hashlib.sha256(source.read_bytes()).hexdigest()==candidate['file_sha256']
    native=read_native_fps(source)
    assert native['native_fps']==candidate['fps']==24
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(source),use_anim=True)
    rig=bpy.data.objects[candidate['rig']]
    action=bpy.data.actions[candidate['source_take']]
    rig.animation_data.action=action
    first,last=action.frame_range
    assert bpy.context.scene.render.fps==24 and list(action.frame_range)==candidate['source_frame_range']
    samples=[]
    for frame in sorted({round(first+(last-first)*i/8) for i in range(9)}):
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        samples.append({'frame':frame,'points':{b.name:list((rig.matrix_world@b.matrix).translation) for b in rig.pose.bones}})
    data={'candidate':candidate,'entry':entry,'native':native,'samples':samples,'parents':{b.name:b.parent.name if b.parent else None for b in rig.data.bones},'source_unchanged':True}
    (out/(filename+'.json')).write_text(json.dumps(data,indent=2)+'\n')
    print(filename,first,last,len(rig.data.bones))
verify()
