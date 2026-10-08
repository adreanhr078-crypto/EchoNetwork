import { readFile, writeFile } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';
import { config, higgsfield } from '@higgsfield/client/v2';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
dotenv.config({ path: resolve(root,'.env.local'), quiet:true });
const credentials = process.env.HF_CREDENTIALS || process.env.HF_KEY ||
  (process.env.HF_API_KEY_ID && process.env.HF_API_KEY_SECRET ? `${process.env.HF_API_KEY_ID}:${process.env.HF_API_KEY_SECRET}` : '');
if (!credentials) throw new Error('Local Higgsfield credential is unavailable.');
config({ credentials, maxRetries:0 });
const folder = resolve(root,'artifacts/eleven-eleven/public/assets/cinematics/hospital-awakening-v1');
const economy = process.argv.includes('--economy');
const journal = resolve(folder,economy ? 'generation-economy.json' : 'generation.json');
let saved;
try { saved=JSON.parse(await readFile(journal,'utf8')); } catch(e) { if(e.code!=='ENOENT') throw e; }
async function save(data) { await writeFile(journal,JSON.stringify(data,null,2)+'\n'); }
async function status() {
  if (!saved?.request_id) throw new Error('No confirmed request ID. Check the submission outcome before any retry.');
  const res=await fetch(`https://api.higgsfield.ai/requests/${encodeURIComponent(saved.request_id)}/status`,{headers:{Authorization:`Key ${credentials}`},signal:AbortSignal.timeout(30000)});
  if(!res.ok) throw new Error(`Status HTTP ${res.status}`);
  const result=await res.json();
  saved={...saved,status:result.status,last_checked_at:new Date().toISOString()};
  const url=result.video?.url || result.videos?.[0]?.url;
  if(result.status==='completed' && url) {
    const media=await fetch(url,{signal:AbortSignal.timeout(90000)});
    if(!media.ok) throw new Error(`Result HTTP ${media.status}`);
    await writeFile(resolve(folder,economy ? 'awakening-economy.mp4' : 'awakening.mp4'),Buffer.from(await media.arrayBuffer()));
    saved.output=economy ? 'awakening-economy.mp4' : 'awakening.mp4'; saved.review_status='UNVERIFIED';
  }
  if(['failed','nsfw','canceled'].includes(result.status)) saved.provider_error=result.error || result.message || result.status;
  await save(saved);
  console.log(JSON.stringify({request_id:saved.request_id,status:saved.status,output:saved.output}));
}
if(process.argv.includes('--status')) { await status(); }
else if(process.argv.includes('--submit')) {
  if(saved) throw new Error('A submission journal already exists; duplicate submissions are blocked.');
  const input={
    prompt:'One continuous quiet bedside shot. Preserve the exact character, black hair, scars, white patient gown, bed, medical equipment and daylight of the starting frame. The exhausted young adult human slowly inhales, his eyelids open a little, his visible right purple iris stays very faint. His fingers gently relax on the sheet. A very slow 12 cm camera push toward his face. Physically plausible pillow and sheet contact, breathing only, no sitting up, no sudden gestures, no change of clothes, no wings, no transformations, no extra limbs, no text, no subtitles, no voice, no scene cuts. Premium cinematic anime game rendering with restrained motion and consistent face. Soft room tone and distant monitor beep only.',
    duration:economy ? 4 : 6,resolution:economy ? '480p' : '1080p',output_format:'mp4',generate_audio:false
  };
  saved={model:economy ? 'bytedance/seedance-2.0/image-to-video' : 'bytedance/seedance-2.5/image-to-video',input,source:'Approved manhwa PDF page 63; original generated landscape keyframe',submitted_at:new Date().toISOString(),status:'preparing',billing:economy ? 'API key; Seedance2.0 4s480p economy candidate; exact account billing unverified' : 'API key; account discount unverified; public pre-discount 1080p estimate about USD 6.83 for 6s',review_status:'UNVERIFIED'};
  await save(saved);
  const slot=await fetch('https://api.higgsfield.ai/files/generate-upload-url',{method:'POST',headers:{Authorization:`Key ${credentials}`,'Content-Type':'application/json'},body:JSON.stringify({content_type:'image/png'}),signal:AbortSignal.timeout(30000)});
  if(!slot.ok) { saved.status='upload_rejected'; await save(saved); throw new Error(`Reference upload authorization HTTP ${slot.status}; no video generation submitted.`); }
  const upload=await slot.json();
  const put=await fetch(upload.upload_url,{method:'PUT',headers:upload.upload_headers || {'Content-Type':'image/png'},body:await readFile(resolve(folder,'keyframe.png')),signal:AbortSignal.timeout(60000)});
  if(!put.ok) { saved.status='upload_failed'; await save(saved); throw new Error(`Reference storage HTTP ${put.status}; no video generation submitted.`); }
  input.image_url=upload.public_url;
  saved.input=input; saved.status='submission_attempted'; await save(saved);
  let result;
  try { result=await higgsfield.subscribe(saved.model,{input,withPolling:false}); }
  catch(error) {
	const code=error.statusCode || error.status || error.response?.status;
	saved.status=code ? 'submission_rejected' : 'submission_unknown';
	saved.http_status=code || null;
	await save(saved);
	console.error(JSON.stringify({status:saved.status,http_status:saved.http_status,error_type:error.constructor.name}));
	process.exit(1);
  }
  if(!result.request_id) throw new Error('Submission returned no request ID. Do not retry without investigating.');
  saved.request_id=result.request_id; saved.status=result.status;
  await save(saved);
  console.log(JSON.stringify({request_id:saved.request_id,status:saved.status,model:saved.model}));
} else { console.log('Use --submit once, then --status. Credentials stay server-side.'); }
