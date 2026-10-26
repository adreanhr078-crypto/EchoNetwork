"""Render the frozen target bake with its approved jacket geometry only.

The saved bake/animation/rest remain untouched. The source comparison and
sample clock are the existing renderer's; only inspection framing and the
identically bound garment mesh differ in this unsaved rendering session.
"""
import argparse
from pathlib import Path
import sys
import bpy

p=argparse.ArgumentParser(add_help=False)
p.add_argument('--variant',type=Path,required=True)
marker=sys.argv.index('--')
options,remaining=p.parse_known_args(sys.argv[marker+1:])
sys.argv=sys.argv[:marker+1]+remaining

def replace_geometry(target):
    before=set(bpy.data.objects)
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==target for m in o.modifiers)]
    assert len(meshes)==1,'Ambiguous original target mesh'
    original=meshes[0]
    action=target.animation_data.action
    bpy.ops.import_scene.gltf(filepath=str(options.variant.resolve()))
    imported=set(bpy.data.objects)-before
    variants=[o for o in imported if o.type=='MESH' and any(m.type=='ARMATURE' and m.object for m in o.modifiers)]
    assert len(variants)==1,'Ambiguous jacket source geometry'
    variant=variants[0]
    assert [g.name for g in original.vertex_groups]==[g.name for g in variant.vertex_groups],'Original skin group order differs'
    assert max(abs(original.matrix_world[i][j]-variant.matrix_world[i][j]) for i in range(4) for j in range(4))<1e-6,'Mesh object space differs'
    original.data=variant.data.copy()
    for obj in imported:bpy.data.objects.remove(obj,do_unlink=True)
    assert target.animation_data.action==action,'Inspection changed the baked motion'

renderer=Path(__file__).with_name('render_single_motion.py')
code=renderer.read_text(encoding='utf-8')
target_line="target=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE' and o!=source)"
assert code.count(target_line)==1
code=code.replace(target_line,target_line+"\nif mode!='source': replace_geometry(target)")
center='        center=Vector((hip.x,hip.y,1.0))'
assert code.count(center)==1
code=code.replace(center,"""        visible_points=list(points.values())
        if mode!='source':
            visible_points.extend((target.matrix_world @ target.pose.bones[v['target']].matrix).translation.copy() for v in mapping.values())
        low=Vector(tuple(min(p[j] for p in visible_points)-.20 for j in range(3)))
        high=Vector(tuple(max(p[j] for p in visible_points)+.20 for j in range(3)))
        center=(low+high)*.5
        height=high.z-low.z
        width=(high.x-low.x) if view=='back' else (high.y-low.y)
        camera.data.ortho_scale=max(width*1.15,height*1.15/(720/1200),2.0)""")
code=code.replace("dest=out/(mode+'-frames');dest.mkdir(exist_ok=True)","dest=out/(mode+'-jacket-frames');dest.mkdir(exist_ok=True)")
exec(compile(code,str(renderer),'exec'),{'__name__':'__main__','__file__':str(renderer),'replace_geometry':replace_geometry})
