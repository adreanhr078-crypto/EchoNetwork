"""Read-only local coordinate/cut diagnosis for a nonfolding eyelid patch."""
import hashlib,json,math
from pathlib import Path
import bpy
import numpy as np
from mathutils.geometry import delaunay_2d_cdt
APP=Path(__file__).resolve().parents[2];face=APP/'art/production/echo-school-rebuild-20261029/face'
old=face/'blink-retopology-20261102';intake=face/'intake-20261102';out=face/'blink-nested-20261103';out.mkdir(exist_ok=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
rim=json.loads((intake/'eye-rim-region-preview.json').read_text())
mapping=json.loads((intake/'blink-whole-eye-mask-preview.json').read_text())['original_to_welded']
canonical={}
for index,welded in enumerate(mapping):canonical.setdefault(welded,index)
bpy.ops.wm.open_mainfile(filepath=str(old/'connected-blink-research.blend'))
obj=next(obj for obj in bpy.context.scene.objects if obj.type=='MESH')
points=np.asarray([list(obj.matrix_world@v.co) for v in obj.data.vertices],dtype=np.float64)
def cross(a,b):return a[0]*b[1]-a[1]*b[0]
def crossings(poly):
 pairs=[];n=len(poly)
 for i in range(n):
  a,b=poly[i],poly[(i+1)%n]
  for j in range(i+1,n):
   if j==i+1 or (i==0 and j==n-1):continue
   c,d=poly[j],poly[(j+1)%n];den=cross(b-a,d-c)
   if abs(den)<1e-14:continue
   t=cross(c-a,d-c)/den;u=cross(c-a,b-a)/den
   if 1e-7<t<1-1e-7 and 1e-7<u<1-1e-7:pairs.append([i,j])
 return pairs
rows={}
for side,eye in rim['eyes'].items():
 indices=[canonical[index] for index in eye['loop_welded_vertices']];p=points[indices];center=np.mean(p,axis=0)
 trials=[]
 for angle in range(-60,61,2):
  theta=math.radians(angle);u=np.asarray([math.cos(theta),math.sin(theta),0]);v=np.asarray([0,0,1])
  projected=np.stack([(p-center)@u,(p-center)@v],axis=1)
  trials.append({'degrees':angle,'crossing_pairs':crossings(projected)})
 rows[side]={'indices':indices,'points_world':p.tolist(),'center_world':center.tolist(),
             'front_pairs':next(t['crossing_pairs'] for t in trials if t['degrees']==0),
             'projection_trials':trials,'nearest_simple_projection':min([t for t in trials if not t['crossing_pairs']],key=lambda t:abs(t['degrees']),default=None)}
data={'status':'READ_ONLY_COORDINATE_DIAGNOSIS','old_blend_sha256':sha(old/'connected-blink-research.blend'),'eyes':rows,
      'delaunay_api':delaunay_2d_cdt.__doc__}
(out/'parameterization-input.json').write_text(json.dumps(data,indent=2)+'\n')
print('PARAMETERIZATION',json.dumps({side:{'front_pairs':row['front_pairs'],'nearest_simple_projection':row['nearest_simple_projection']} for side,row in rows.items()}))
print('CDT_API',delaunay_2d_cdt.__doc__)
