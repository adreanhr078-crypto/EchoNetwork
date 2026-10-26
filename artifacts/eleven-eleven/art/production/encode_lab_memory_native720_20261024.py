from pathlib import Path
import json,hashlib,subprocess
APP=Path(__file__).resolve().parents[2]
E=APP/'audits/evidence/chapter-cp45-20261020/stage13/modular-20261024d'
P=APP/'art/production/lab-modular-refinement-20261024'
source=APP/'art/production/memory-atmosphere-cp42-20261020'
manifest=json.loads((source/'flow-manifest.json').read_text())
rows=[]
for label in ['city','friends']:
    raw=source/'flow-raw'/(label+'.mp4')
    digest=hashlib.sha256(raw.read_bytes()).hexdigest()
    assert digest==manifest['clips'][label]['sha256'],'Original Flow source changed'
    target=APP/'godot/assets/cinematics/memory-screens'/(label+'-high.ogv')
    backup=E/'before'/(label+'-high-before-native720.ogv')
    assert not backup.exists();backup.write_bytes(target.read_bytes())
    subprocess.run(['ffmpeg','-y','-hide_banner','-loglevel','error','-i',str(raw),'-map','0:v:0','-an','-c:v','libtheora','-q:v','9','-pix_fmt','yuv420p',str(target)],check=True)
    info=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-show_entries','stream=codec_type,width,height,r_frame_rate,nb_read_frames:format=duration','-of','json',str(target)]))
    video=info['streams'][0]
    assert video['width']==1280 and video['height']==720 and video['nb_read_frames']=='192' and len(info['streams'])==1
    subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-i',str(target),'-f','null','-'],check=True)
    rows.append({'clip':label,'original':str(raw.relative_to(APP)).replace('\\','/'),'original_sha256':digest,'previous_high_sha256':hashlib.sha256(backup.read_bytes()).hexdigest(),'runtime':str(target.relative_to(APP)).replace('\\','/'),'runtime_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'native_size':[1280,720],'fps':24,'frames':192,'duration_s':8,'whole_decode':'PASS','audio_streams':0,'scope':'Entire unchanged original8-second Flow picture,high-quality native-resolution Theora encode. Existing approved SFX and Canon untouched. No invented upscaling.'})
(P/'native-hd-memory-media.json').write_text(json.dumps(rows,indent=2)+'\n')
print('WHOLE_NATIVE_720P24_MEMORIES_RESTORED',len(rows))
