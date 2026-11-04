"""Independently compare exported pact PBR pixels and native body joint positions."""
from pathlib import Path
import io,json,struct,hashlib
import numpy as np
from PIL import Image
app=Path(__file__).resolve().parents[2]
base=app/'art/production/echo-contract-rebuild-20261101'
out=base/'work/wing-rig-v2'
def load(path):
    raw=path.read_bytes();at=12;doc=None;binary=None
    while at<len(raw):
        size,kind=struct.unpack_from('<II',raw,at);chunk=raw[at+8:at+8+size];at+=8+size
        if kind==0x4e4f534a:doc=json.loads(chunk)
        elif kind==0x004e4942:binary=chunk
    assert doc and binary
    return doc,binary,hashlib.sha256(raw).hexdigest()
source,sbin,shash=load(base/'source/contract-rig4k.glb')
target,tbin,thash=load(out/'contract-wing-metric.glb')
def pixels(doc,binary,role):
    mat=doc['materials'][0]
    texture=mat['normalTexture'] if role=='normal' else mat['pbrMetallicRoughness'][role]
    item=doc['images'][doc['textures'][texture['index']]['source']]
    view=doc['bufferViews'][item['bufferView']]
    data=binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']]
    image=Image.open(io.BytesIO(data)).convert('RGBA')
    return image.size,hashlib.sha256(image.tobytes()).hexdigest()
maps={}
for role in ['baseColorTexture','normal','metallicRoughnessTexture']:
    a,b=pixels(source,sbin,role),pixels(target,tbin,role)
    maps[role]={'source':a,'derivative':b,'pixel_identical':a==b}
assert all(row['pixel_identical'] for row in maps.values())
def worlds(doc):
    parents={c:i for i,n in enumerate(doc['nodes']) for c in n.get('children',[])};cache={}
    def world(i):
        if i not in cache:
            n=doc['nodes'][i]
            if 'matrix' in n:m=np.array(n['matrix']).reshape(4,4).T
            else:
                x,y,z,w=n.get('rotation',[0,0,0,1]);m=np.eye(4)
                m[:3,:3]=[[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]]
                m[:3,:3]=m[:3,:3]@np.diag(n.get('scale',[1,1,1]));m[:3,3]=n.get('translation',[0,0,0])
            cache[i]=(world(parents[i]) if i in parents else np.eye(4))@m
        return cache[i]
    return {n.get('name',str(i)).replace(':','_'):world(i) for i,n in enumerate(doc['nodes']) if i in doc['skins'][0]['joints']}
sw,tw=worlds(source),worlds(target)
assert len(sw)==65 and len(tw)==72 and set(sw).issubset(tw)
review=json.loads((out/'review.json').read_text())
factor=review['uniform_metric_scale']
center=(sw['mixamorig_LeftFoot'][:3,3]+sw['mixamorig_RightFoot'][:3,3])*.5;center[1]=0
errors={name:float(np.linalg.norm(tw[name][:3,3]-(matrix[:3,3]-center)*factor)) for name,matrix in sw.items()}
maximum=max(errors.values());assert maximum<1e-5,maximum
report={'status':'PASS_EXPORTED_BODY_JOINTS_AND_PBR_PIXELS','source_sha256':shash,'derivative_sha256':thash,'maps':maps,'body_joints_compared':len(sw),'derivative_joints':len(tw),'max_rest_joint_metric_error_m':maximum,'scope':'Original 65 body joint positions after one measured unit conversion;three 4K PBR maps pixel-identical. No motion/runtime/physics acceptance.'}
(out/'native-export-audit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
