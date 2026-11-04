"""Hash-cached contact sheets for source-transfer inspection;never acceptance."""
import argparse,json,hashlib
from pathlib import Path
from PIL import Image,ImageDraw
p=argparse.ArgumentParser();p.add_argument('--case',type=Path,required=True);p.add_argument('--phase',choices=['blender','godot'],required=True);p.add_argument('--mesh-bounds',action='store_true');args=p.parse_args()
c=args.case.resolve();reference=json.loads((c/'blender-reference.json').read_text());count=len(reference['samples'])
n=8 if args.phase=='blender' else 6;frames=sorted({round(i*(count-1)/(n-1)) for i in range(n)})
names=[c/('comparison-mesh-frames' if args.mesh_bounds else 'comparison-full-frames')/('%s-%04d.png'%(view,f)) if args.phase=='blender' else c/('godot-%s-%04d.png'%(view,f)) for f in frames for view in ['back','side']]
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
inputs={str(path):sha(path) for path in names};key=hashlib.sha256(json.dumps(inputs,sort_keys=True).encode()).hexdigest();manifest=c/(args.phase+'-review-sheets.json')
if manifest.exists():
 old=json.loads(manifest.read_text())
 if old.get('input_key')==key and all(Path(path).exists() and sha(Path(path))==digest for path,digest in old['sheets'].items()):print('REVIEW_SHEETS_CACHE_HIT',key);raise SystemExit(0)
columns=2;rows=4 if args.phase=='blender' else 3;size=(600,360) if args.phase=='blender' else (480,640)
sheets={}
for start in range(0,len(names),columns*rows):
 selected=names[start:start+columns*rows];height=((len(selected)+1)//2)*(size[1]+22)
 canvas=Image.new('RGB',(size[0]*columns,height),(22,27,35));draw=ImageDraw.Draw(canvas)
 for slot,path in enumerate(selected):
  x=(slot%2)*size[0];y=(slot//2)*(size[1]+22)
  canvas.paste(Image.open(path).convert('RGB').resize(size),(x,y+22));draw.text((x+8,y+4),path.name,fill='white')
 target=c/(args.phase+'-review-page-%d.jpg'%(start//(columns*rows)));canvas.save(target,quality=92);sheets[str(target)]=sha(target)
manifest.write_text(json.dumps({'status':'CONTACT_SHEETS_CAPTURED_NOT_REVIEWED','input_key':key,'frames':frames,'source_captures':inputs,'sheets':sheets},indent=2)+'\n')
print('REVIEW_SHEETS',json.dumps(list(sheets)))
