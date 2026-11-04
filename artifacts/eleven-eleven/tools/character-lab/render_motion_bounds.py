"""Camera-only framing wrapper for existing source/target fidelity captures."""
from pathlib import Path
import hashlib
import json
import sys

app = Path(__file__).resolve().parents[2]
mesh_bounds='--mesh-bounds' in sys.argv
if mesh_bounds:sys.argv.remove('--mesh-bounds')
original = app/'tools/animation-library/render_single_motion.py'
code = original.read_text(encoding='utf-8')
needle = '        center=Vector((hip.x,hip.y,1.0))'
replacement = '''        visible=list(points.values())
        if mode!='source':
            visible.extend(target.matrix_world @ bone.matrix.translation for bone in target.pose.bones)
        low=Vector(tuple(min(p[a] for p in visible) for a in range(3)))
        high=Vector(tuple(max(p[a] for p in visible) for a in range(3)))
        center=(low+high)*0.5
        width=high.x-low.x if view=='back' else high.y-low.y
        camera.data.ortho_scale=max((high.z-low.z+0.5)*(1200/720),width+0.5)'''
if code.count(needle)!=1:
    raise ValueError('Original framing changed; inspect before adapting')
if mesh_bounds:
    anchor='        low=Vector(tuple(min(p[a] for p in visible) for a in range(3)))'
    mesh_code='''        if mode!='source':
            from mathutils import Vector as _BoundsVector
            for _mesh in bpy.context.scene.objects:
                if _mesh.type=='MESH' and not _mesh.hide_render and any(_modifier.type=='ARMATURE' and _modifier.object==target for _modifier in _mesh.modifiers):
                    _evaluated=_mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
                    visible.extend(_evaluated.matrix_world @ _BoundsVector(corner) for corner in _evaluated.bound_box)
'''
    assert replacement.count(anchor)==1
    replacement=replacement.replace(anchor,mesh_code+anchor)
code=code.replace(needle,replacement).replace("dest=out/(mode+'-frames')", "dest=out/(mode+'-mesh-frames')" if mesh_bounds else "dest=out/(mode+'-full-frames')")
case=Path(sys.argv[sys.argv.index('--case')+1])
native=(case/'native-adapter-provenance.json').exists()
if native:
    # Native glTF timeline begins at zero; FBX inspection begins at frame one.
    code=code.replace("scene.frame_set(i+1 if mode=='source' else i)","scene.frame_set(i)")
    code=code.replace('scene.frame_set(i+1)','scene.frame_set(i)')
scope={'original_renderer_sha256':hashlib.sha256(original.read_bytes()).hexdigest(),
       'adaptation':'Camera framing and new capture directory only; no bone/mesh/key/transfer changes'}
if mesh_bounds:scope['bounds']='Actual evaluated target mesh bounds plus source/targetjoints;wing feathers can extend beyond wing bones. Priorbone-only captures retained.'
if native: scope['sampling']='Original glTF time-zero timeline,including pre-first-key clamp;not FBX frame-one offset'
namespace={'__name__':'__main__','__file__':str(original)}
exec(compile(code,str(original),'exec'),namespace)
(namespace['out']/'blender-framing-provenance.json').write_text(json.dumps(scope,indent=2)+'\n',encoding='utf-8')
