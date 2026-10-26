import runpy,sys
from pathlib import Path
app=Path.cwd()
case=app/'audits/evidence/chapter-cp45-20261020/stage11/sword-shield'
sys.argv=['v31_parkour_motion.py','--','--mode','inspect','--output',str(case),'--take-id','8ec89e0c14d16944efba775b:0:13373cc7','--clip-name','Attack']
runpy.run_path(str(app/'tools/animation-library/v31_parkour_motion.py'),run_name='__main__')
sys.argv=['render_current_target_motion.py','--','--case',str(case),'--phase','source']
runpy.run_path(str(app/'tools/animation-library/render_current_target_motion.py'),run_name='__main__')
