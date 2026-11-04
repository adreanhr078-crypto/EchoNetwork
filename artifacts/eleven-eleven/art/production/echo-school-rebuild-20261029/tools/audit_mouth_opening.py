from pathlib import Path
import bpy,numpy as np,json
p=Path(__file__).resolve().parents[1];out=p/'facial';bpy.ops.wm.open_mainfile(filepath=str(p/'source/echo-school-rig-metric.blend'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');body=next(o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers));mesh=body.data;d=np.load(out/'component-assignments.npz');points=d['world_points'];comp=d['vertex_component'];unique,inverse=np.unique(np.round(points,6),axis=0,return_inverse=True)
edges=[]
for face in mesh.polygons:
 if int(comp[face.vertices[0]])!=30:continue
 ids=[int(inverse[i]) for i in face.vertices]
 edges.extend(tuple(sorted((a,b))) for a,b in zip(ids,ids[1:]+ids[:1]) if a!=b)
ue,counts=np.unique(np.array(edges),axis=0,return_counts=True);boundary=ue[counts==1];centres=unique[boundary].mean(axis=1);mask=(np.abs(centres[:,0])<.035)&(centres[:,2]>1.52)&(centres[:,2]<1.565)&(centres[:,1]<-.02);mouth=boundary[mask]
vids=sorted(set(int(i) for e in mouth for i in e));adj={i:[] for i in vids}
for a,b in mouth:adj[int(a)].append(int(b));adj[int(b)].append(int(a))
report={'status':'EXISTING_MOUTH_BOUNDARY' if len(mouth) else 'MOUTH_BOUNDARY_NOT_FOUND','main_component':30,'boundary_edges':len(mouth),'all_degree2':all(len(v)==2 for v in adj.values()),'points':{str(i):unique[i].tolist() for i in vids},'edges':mouth.tolist(),'head_source_untouched':True,'bounds':{'min':unique[vids].min(axis=0).tolist(),'max':unique[vids].max(axis=0).tolist()} if vids else {}}
(out/'mouth-opening-audit.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k not in ['points','edges']},indent=2))
