"""Read-only geometric/UV component audit before authoring facial controls."""
from pathlib import Path
import bpy,numpy as np,json,hashlib
p=Path(__file__).resolve().parents[1];out=p/'facial';source=p/'source/echo-school-rig-metric.blend';bpy.ops.wm.open_mainfile(filepath=str(source))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');body=next(o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers));mesh=body.data
coords=np.empty(len(mesh.vertices)*3,dtype=np.float32);mesh.vertices.foreach_get('co',coords);coords=coords.reshape(-1,3);world=np.array(body.matrix_world,dtype=float);points=coords@world[:3,:3].T+world[:3,3]
_,inverse=np.unique(np.round(points,6),axis=0,return_inverse=True);parent=list(range(int(inverse.max())+1))
def root(i):
 while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
 return i
for edge in mesh.edges:
 a,b=(root(int(inverse[i])) for i in edge.vertices)
 if a!=b:parent[b]=a
roots=np.array([root(int(i)) for i in inverse]);ids,assignment=np.unique(roots,return_inverse=True)
uv=np.zeros((len(mesh.vertices),2),dtype=float)
for loop in mesh.loops:uv[loop.vertex_index]=mesh.uv_layers.active.data[loop.index].uv[:]
images=[n.image for mat in mesh.materials for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image and n.image.colorspace_settings.name=='sRGB'];assert images
image=images[0];w,h=image.size
pixels=np.empty(w*h*4,dtype=np.float32);image.pixels.foreach_get(pixels);pixels=pixels.reshape(h,w,4)
def rgb(indices):
 values=[]
 for i in indices[::max(1,len(indices)//100)]:
  u,v=uv[i]%1;x=min(w-1,int(u*w));y=min(h-1,int(v*h));values.append(pixels[y,x,:3])
 return np.mean(values,axis=0).tolist() if values else []
reports=[]
for cid in range(len(ids)):
 indices=np.where(assignment==cid)[0];pts=points[indices];lo=pts.min(axis=0);hi=pts.max(axis=0)
 if hi[2]<1.48:continue
 roi=indices[(pts[:,2]>1.50)&(pts[:,2]<1.655)&(np.abs(pts[:,0]-.003)<.075)&(pts[:,1]<-.015)]
 reports.append({'component':cid,'vertices_with_uv_splits':len(indices),'unique_points':len(np.unique(inverse[indices])),'bounds_min':lo.tolist(),'bounds_max':hi.tolist(),'face_front_roi_vertices':len(roi),'face_roi_mean_rgb':rgb(roi),'first_vertex':int(indices[0])})
reports.sort(key=lambda x:x['face_front_roi_vertices'],reverse=True)
np.savez_compressed(out/'component-assignments.npz',vertex_component=assignment,world_points=points,uv=uv)
report={'status':'READ_ONLY_COMPONENT_AUDIT','source_blend_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'virtual_weld_epsilon_m':.000001,'actual_source_welded':False,'total_components':len(ids),'body_vertices':len(coords),'albedo_image':image.name,'head_components':reports}
(out/'component-audit.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'total_components':len(ids),'top_face_components':reports[:8]},indent=2))
