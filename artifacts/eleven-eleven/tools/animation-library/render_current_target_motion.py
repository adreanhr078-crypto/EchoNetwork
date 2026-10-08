"""Frame the isolated current-target comparison without changing motion.

The original review camera assumed an anatomical Hips at pelvis height. This
target uses a floor controller, so frame the observed joints instead. The
saved inspection/bake and all source keys stay untouched.
"""
from pathlib import Path

original = Path(__file__).with_name('render_single_motion.py')
code = original.read_text(encoding='utf-8')
old = '        center=Vector((hip.x,hip.y,1.0))'
new = '''        visible_points=list(points.values())
        if mode!='source':
            visible_points.extend((target.matrix_world @ target.pose.bones[v['target']].matrix).translation.copy() for v in mapping.values())
        low=Vector(tuple(min(p[j] for p in visible_points)-.20 for j in range(3)))
        high=Vector(tuple(max(p[j] for p in visible_points)+.20 for j in range(3)))
        center=(low+high)*.5
        height=high.z-low.z
        width=(high.x-low.x) if view=='back' else (high.y-low.y)
        camera.data.ortho_scale=max(width*1.15,height*1.15/(720/1200),2.0)'''
if code.count(old) != 1:
    raise ValueError('Review-camera entry point changed; inspect first')
exec(compile(code.replace(old,new),str(__file__),'exec'),{'__name__':'__main__','__file__':str(__file__)})
