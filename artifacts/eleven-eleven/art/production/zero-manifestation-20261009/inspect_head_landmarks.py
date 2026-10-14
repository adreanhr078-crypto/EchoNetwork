"""Project actual textured source vertices for attachment landmark review."""
import io
import json
import struct
from pathlib import Path
from PIL import Image, ImageDraw
from inspect_manifestation_sources import APP, CASE, FILES


def read(path):
    raw = path.read_bytes()
    size = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20+size])
    blob = raw[28+size:]
    def accessor(index):
        item = doc['accessors'][index]
        view = doc['bufferViews'][item['bufferView']]
        count = {'SCALAR':1, 'VEC2':2, 'VEC3':3, 'VEC4':4}[item['type']]
        fmt = {5126:'f',5123:'H',5125:'I',5121:'B'}[item['componentType']]
        length = struct.calcsize('<'+fmt*count)
        start = view.get('byteOffset',0)+item.get('byteOffset',0)
        stride = view.get('byteStride',length)
        return [struct.unpack_from('<'+fmt*count, blob, start+i*stride) for i in range(item['count'])]
    primitive=doc['meshes'][0]['primitives'][0]
    pos=accessor(primitive['attributes']['POSITION'])
    uv=accessor(primitive['attributes']['TEXCOORD_0'])
    material=doc['materials'][primitive['material']]
    texture=doc['textures'][material['pbrMetallicRoughness']['baseColorTexture']['index']]
    image=doc['images'][texture['source']]
    if 'uri' in image:
        atlas=Image.open(path.parent / image['uri']).convert('RGB')
    else:
        view=doc['bufferViews'][image['bufferView']]
        start=view.get('byteOffset',0)
        atlas=Image.open(io.BytesIO(blob[start:start+view['byteLength']])).convert('RGB')
    return pos,uv,atlas


if __name__=='__main__':
    records={}
    for name, forward in [('echo_current',0), ('echo_prospective',2)]:
        pos,uv,atlas=read(FILES[name])
        horizontal=2 if forward==0 else 0
        selected=[(p,t) for p,t in zip(pos,uv) if .84<p[1]<.98 and abs(p[horizontal])<.095]
        # Depth-sort source samples: actual geometry and colour, no image synthesis.
        selected.sort(key=lambda item:item[0][forward])
        result=Image.new('RGB',(900,700),(30,30,35))
        draw=ImageDraw.Draw(result)
        for p,t in selected:
            x=450-p[horizontal]*4000
            y=650-(p[1]-.84)*4200
            tx=min(atlas.width-1,max(0,int(t[0]*atlas.width)))
            ty=min(atlas.height-1,max(0,int(t[1]*atlas.height)))
            color=atlas.getpixel((tx,ty))
            draw.ellipse((x-3,y-3,x+3,y+3),fill=color)
        result.save(CASE/(name+'-textured-head-projection.png'))
        records[name]={'horizontal_axis':horizontal,'forward_axis':forward,'points':len(selected),'atlas':[atlas.width,atlas.height]}
    (CASE/'head-projection.json').write_text(json.dumps(records,indent=2))
