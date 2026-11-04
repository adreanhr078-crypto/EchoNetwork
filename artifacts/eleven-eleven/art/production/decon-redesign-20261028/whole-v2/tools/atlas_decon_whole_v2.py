import pathlib,struct,json,io,math,shutil
from PIL import Image
P=pathlib.Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\decon-redesign-20261028\whole-v2\optimized');P.mkdir(exist_ok=True);src=P.parent/'textured-metric-combined.glb';runtime=pathlib.Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\godot\assets\environments\decon_clinical\decon_whole_v2_static.glb')
assert src.exists(),'First retexture repaired authored UV kit and merge it with the78 valid generated groups. Do not pack the old overlapping-UV source.'
b=src.read_bytes();n=struct.unpack_from('<I',b,12)[0];g=json.loads(b[20:20+n]);buf=b[28+n:]
def image_of(t):
 i=g['images'][g['textures'][t]['source']];v=g['bufferViews'][i['bufferView']];return Image.open(io.BytesIO(buf[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']])).convert('RGB')
uvs={}
for mesh in g['meshes']:
 for p in mesh['primitives']:
  a=g['accessors'][p['attributes']['TEXCOORD_0']];v=g['bufferViews'][a['bufferView']];start=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',8)
  uvs.setdefault(p['material'],[]).extend(struct.unpack_from('<ff',buf,start+i*stride) for i in range(a['count']))
tiles=[]
for index,m in enumerate(g['materials']):
 p=m['pbrMetallicRoughness'];ims=[image_of(p['baseColorTexture']['index']),image_of(m['normalTexture']['index']),image_of(p['metallicRoughnessTexture']['index'])]
 assert p.get('baseColorFactor',[1,1,1,1])==[1,1,1,1] and p.get('roughnessFactor',1)==1 and p.get('metallicFactor',1)==1,('Non-unit source factor',m['name'])
 ao=image_of(m['occlusionTexture']['index']).getchannel('R').resize(ims[2].size) if 'occlusionTexture' in m else Image.new('L',ims[2].size,255)
 ims[2]=Image.merge('RGB',(ao,ims[2].getchannel('G'),ims[2].getchannel('B')))
 W=max(im.width for im in ims);H=max(im.height for im in ims);uv=uvs[index];lo=[min(p[i] for p in uv) for i in range(2)];hi=[max(p[i] for p in uv) for i in range(2)]
 assert min(lo)>-.001 and max(hi)<1.001
 left=max(0,math.floor(lo[0]*W)-2);right=min(W,math.ceil(hi[0]*W)+2);top=max(0,math.floor((1-hi[1])*H)-2);bottom=min(H,math.ceil((1-lo[1])*H)+2)
 crop=(left/W,top/H,right/W,bottom/H);tiles.append({'name':m['name'],'ims':ims,'crop':crop,'source_size':(right-left,bottom-top)})
N=4096;pad=4
def pack(scale):
 free=[(0,0,N,N)];placements={}
 sizes=[(i,max(16,math.ceil(t['source_size'][0]*scale)),max(16,math.ceil(t['source_size'][1]*scale))) for i,t in enumerate(tiles)]
 for i,w,h in sorted(sizes,key=lambda p:max(p[1:]),reverse=True):
  rw,rh=w+pad*2,h+pad*2;candidates=[(min(f[2]-rw,f[3]-rh),f[2]*f[3]-rw*rh,k,f) for k,f in enumerate(free) if f[2]>=rw and f[3]>=rh]
  if not candidates:
   print('PACK_FAIL',scale,i,w,h,'AREA',sum(w*h for _,w,h in sizes),len(free));return None
  _,_,k,f=min(candidates);x,y,fw,fh=f;placements[i]=(x+pad,y+pad,w,h);fresh=[]
  # MaxRects split; remove contained free rectangles to avoid overlapping allocations.
  for fx,fy,fW,fH in free:
   if x+rw<=fx or fx+fW<=x or y+rh<=fy or fy+fH<=y:fresh.append((fx,fy,fW,fH));continue
   if x>fx:fresh.append((fx,fy,x-fx,fH))
   if x+rw<fx+fW:fresh.append((x+rw,fy,fx+fW-x-rw,fH))
   if y>fy:fresh.append((fx,fy,fW,y-fy))
   if y+rh<fy+fH:fresh.append((fx,y+rh,fW,fy+fH-y-rh))
  free=[a for k,a in enumerate(fresh) if not any(k!=j and a[0]>=v[0] and a[1]>=v[1] and a[0]+a[2]<=v[0]+v[2] and a[1]+a[3]<=v[1]+v[3] and (a!=v or k>j) for j,v in enumerate(fresh))]
 return placements
for scale in [1,.875,.75,.625,.5,.4375,.375,.3125,.25]:
 placements=pack(scale)
 if placements:break
assert placements
atlases=[Image.new('RGB',(N,N),c) for c in [(255,255,255),(128,128,255),(255,255,0)]];records={}
for i,t in enumerate(tiles):
 x,y,w,h=placements[i];l,top,r,bottom=t['crop']
 for channel,im in enumerate(t['ims']):
  tile=im.crop((round(l*im.width),round(top*im.height),round(r*im.width),round(bottom*im.height))).resize((w,h),Image.Resampling.LANCZOS);atlas=atlases[channel];atlas.paste(tile,(x,y))
  atlas.paste(tile.crop((0,0,1,h)).resize((pad,h)),(x-pad,y));atlas.paste(tile.crop((w-1,0,w,h)).resize((pad,h)),(x+w,y))
  atlas.paste(atlas.crop((x-pad,y,x+w+pad,y+1)).resize((w+pad*2,pad)),(x-pad,y-pad));atlas.paste(atlas.crop((x-pad,y+h-1,x+w+pad,y+h)).resize((w+pad*2,pad)),(x-pad,y+h))
 records[t['name']]={'uv_min':[l,1-bottom],'uv_span':[r-l,bottom-top],'atlas_offset':[x/N,1-(y+h)/N],'atlas_scale':[w/N,h/N],'source_crop_pixels':list(t['source_size'])}
for name,im in zip(['basecolor','normal','orm'],atlases):im.save(P/('atlas-'+name+'.png'))
report={'atlas_size':N,'scale':scale,'materials_before':len(tiles),'materials_after':1,'images_before':len(g['images']),'images_after':3,'tiles':records,'source':str(src),'runtime':str(runtime),'scope':'Exact geometry;UV crop/pack only;original Tripo maps preserved in source'}
(P/'atlas-layout.json').write_text(json.dumps(report,indent=2));print('ATLAS_PACKED',scale,N,len(tiles))
