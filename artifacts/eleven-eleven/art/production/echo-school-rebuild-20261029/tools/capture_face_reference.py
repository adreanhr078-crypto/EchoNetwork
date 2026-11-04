"""Local facial-expression estimates from the owner-approved video;no body retarget."""
from pathlib import Path
import argparse,json,hashlib,gzip,math,urllib.request
import cv2,mediapipe as mp
parser=argparse.ArgumentParser();parser.add_argument('--video',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--model-cache',type=Path,required=True);a=parser.parse_args()
a.output.mkdir(parents=True,exist_ok=True);a.model_cache.mkdir(parents=True,exist_ok=True)
model=a.model_cache/'face_landmarker.task';url='https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/latest/face_landmarker.task'
if not model.exists():
 with urllib.request.urlopen(url,timeout=60) as r:model.write_bytes(r.read())
model_hash=hashlib.sha256(model.read_bytes()).hexdigest()
(a.model_cache/'model-provenance.json').write_text(json.dumps({'url':url,'sha256':model_hash,'guide':'https://developers.google.com/edge/mediapipe/solutions/vision/face_landmarker/python','library':mp.__version__},indent=2)+'\n')
cap=cv2.VideoCapture(str(a.video));fps=cap.get(cv2.CAP_PROP_FPS);assert fps>0
options=mp.tasks.vision.FaceLandmarkerOptions(base_options=mp.tasks.BaseOptions(model_asset_path=str(model)),running_mode=mp.tasks.vision.RunningMode.VIDEO,num_faces=1,output_face_blendshapes=True,output_facial_transformation_matrixes=True)
samples=[];landmarks=[];frame=0
with mp.tasks.vision.FaceLandmarker.create_from_options(options) as detector:
 while True:
  ok,bgr=cap.read()
  if not ok:break
  image=mp.Image(image_format=mp.ImageFormat.SRGB,data=cv2.cvtColor(bgr,cv2.COLOR_BGR2RGB));timestamp=round(frame*1000/fps);result=detector.detect_for_video(image,timestamp)
  sample={'frame':frame,'time_seconds':frame/fps,'timestamp_ms':timestamp,'face_found':bool(result.face_landmarks)}
  if result.face_landmarks:
   sample['coefficients']={c.category_name:float(c.score) for c in result.face_blendshapes[0]};sample['face_transform']=result.facial_transformation_matrixes[0].tolist()
   points=[[float(v.x),float(v.y),float(v.z)] for v in result.face_landmarks[0]];landmarks.append({'frame':frame,'points':points})
   assert all(math.isfinite(x) for p in points for x in p)
  samples.append(sample);frame+=1
cap.release();found=[s for s in samples if s['face_found']];assert samples
names=list(found[0]['coefficients']) if found else []
report={'status':'ESTIMATES_EXTRACTED_REVIEW_REQUIRED' if len(found)/len(samples)>=.98 else 'TRACKING_INCOMPLETE_REVIEW_REQUIRED','source_video':str(a.video),'source_sha256':hashlib.sha256(a.video.read_bytes()).hexdigest(),'model_sha256':model_hash,'fps':fps,'frame_count':len(samples),'faces_found':len(found),'coverage':len(found)/len(samples),'coefficient_count':len(names),'subject_left_right':'Subject sides,not viewer;video not mirrored','ranges':{n:{'min':min(s['coefficients'][n] for s in found),'max':max(s['coefficients'][n] for s in found)} for n in names},'samples':samples,'limits':'ML estimates on stylized anime reference,not an authored rig or artistic acceptance. Original video untouched;Golden/body motion keys untouched.'}
(a.output/'face-capture.json').write_text(json.dumps(report,separators=(',',':'))+'\n')
with gzip.open(a.output/'face-landmarks.json.gz','wt',encoding='utf-8') as f:json.dump({'source_sha256':report['source_sha256'],'fps':fps,'frames':landmarks},f,separators=(',',':'))
print(json.dumps({k:report[k] for k in ['status','fps','frame_count','faces_found','coverage','coefficient_count']},indent=2),flush=True)
print(json.dumps({n:report['ranges'].get(n) for n in ['jawOpen','mouthSmileLeft','mouthSmileRight','eyeBlinkLeft','eyeBlinkRight']},indent=2),flush=True)
