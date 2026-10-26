"""Render a quarantined failed bake; no export or numerical acceptance."""
from pathlib import Path
import sys
p=Path('tools/animation-library/render_jacket_target_motion.py')
code=p.read_text()
code=code.replace("code=renderer.read_text(encoding='utf-8')", "code=renderer.read_text(encoding='utf-8').replace('single-motion.blend','failed-bake-diagnostic.blend').replace(\"indices=range(count) if mode!='source' else\",\"indices=sorted(set(round(j*(count-1)/8) for j in range(9))) if mode!='source' else\")")
code=code.replace("comparison-jacket-frames","diagnostic-jacket-frames")
sys.argv=[str(p),'--','--variant','godot/assets/characters/echo_v31_short_jacket.glb','--case','audits/evidence/chapter-cp45-20261020/stage11/native-attack-20261023/downward','--phase','comparison']
exec(compile(code,str(p),'exec'),{'__name__':'__main__','__file__':str(p)})
