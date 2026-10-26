"""Record current scoped evidence. Never declares room or chapter acceptance."""
from pathlib import Path
import json,hashlib,shutil,datetime
APP=Path(__file__).resolve().parents[5]
# evidence -> stage13 -> CP45 -> evidence -> audits -> app
assert (APP/'godot/project.godot').is_file(), APP
CASE=Path(__file__).resolve().parent
P=APP/'docs/internal/production'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
stamp=datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
backup=CASE/'before'/('subscription-'+stamp);backup.mkdir(parents=True,exist_ok=True)
for rel in ['CURRENT_WORK.ar.md','CURRENT_CONTEXT_CACHE.json','SOURCE_INDEX.json','WORK_TREE.ar.md']:
 shutil.copy2(P/rel,backup/rel)
ledger=json.loads((CASE/'generation-ledger.json').read_text(encoding='utf-8-sig'))
ledger['authorization']={'source':'Owner confirmed subscription activated and authorized available Tripo credits/features for room quality; no additional purchase performed.',
 'original_budget':200,'activation_balance_observed':3145,'subscription_credit_delta_observed':3000,
 'current_balance_last_observed':3030,'new_paid_operations_since_activation':115,'total_lab_paid_credits_including_pre_subscription_chair':170,
 'policy':'Use fitting operations and existing tasks. Whole-room generation optional; quality governs selection. No credit depletion for its own sake.'}
chair=next(j for j in ledger['jobs'] if j.get('asset')=='neural-chair')
chair.update(state='downloaded_original_and_retopped',export='Subscription active;64.65MB original retained;11.68MB derivative inspected and integrated for native review.',
 original_triangles=1880765,retopo_triangles=20336,retopo_credits=35,retopo_before=3145,retopo_after=3110,
 derivative='art/production/lab-clinical-kit-20261023/tripo/neural-chair-retopo-20k.glb',
 derivative_sha256='0aa2bb8291263e09a5cb42d4b023a9f12e955c91bcc358af821054b1e3e79f12')
ledger['jobs']=[j for j in ledger['jobs'] if j.get('asset') not in ['lab-theater-assembly','full-room-cutaway']]
ledger['jobs'] += [
 {'provider':'tripo','asset':'lab-theater-assembly','task_id':'69598855-5b7b-42c8-a391-1f2540cf8d85','state':'source_and_textured_downloaded_inspection_open',
  'generation':'H3.1 Detailed Generate in Parts,200000 target;121 parts190343 triangles',
  'reference':'01-entry -> actual inferred Tripo multiview; result isolated surgical assembly, NOT full walls',
  'shown_generation_cost':60,'charged_generation':0,'reason':'one free Generate in Parts trial; balance remained3110',
  'texture':'4K reference multiview; Remove Lighting on','charged_texture':20,'before':3110,'after':3090},
 {'provider':'tripo','asset':'full-room-cutaway','task_id':'2ddda695-37ca-4246-9203-ac1ad986a217','state':'segmented_source_downloaded_8k_texture_requested',
  'reference':'references/full-room-cutaway-tripo.png -> actual Tripo-generated four angles, reviewed before3D',
  'generation':'H3.1 Detailed Generate in Parts,200000 target;174 parts176515 triangles',
  'charged_generation':60,'before':3090,'after':3030,'texture':'8K Trial x1, Remove Lighting on; shown30->0, pending return',
  'texture_charge_observed':0,'native_acceptance':'OPEN; measure/edit openings, strip duplicate equipment/floor/water, preserve native landmarks before integration.'}]
ledger.pop('tripo_remaining_authorized',None)
(CASE/'generation-ledger.json').write_text(json.dumps(ledger,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
policy='docs/internal/production/ROOM_CINEMATIC_PRODUCTION_POLICY_2026-10-23.ar.md'
cache=json.loads((P/'CURRENT_CONTEXT_CACHE.json').read_text(encoding='utf-8-sig'))
cache.setdefault('verified_source_hashes',{})
cache['room_policy']=policy
cache['active_gate']['progress']='Native05 chair20,336tri integrated; Native06 architectural continuous PBR response explored, get_meta error fixed, fresh rendered rerun required. Room still REFINE. Actual Tripo full-room174parts176515tri returned, source downloaded;8K trial texture requested. No current art acceptance.'
cache['active_gate']['resource_route']='Subscription active,3145 observed on activation;35retopo+20texture+60fullroom generation=115 new paid;3030 last observed. Total lab170 including earlier55chair. Resume existing tasks; no extra purchase.'
cache['active_gate']['local_checks']='26 headless presentation lifecycle checks passed:2advancing muted whole videos, pause, liveRM posters/frozenwater, low/high targets, no story mutation, unload. Not rendered/performance acceptance.'
cache['next']=['Inspect/finish full-room2ddda695 and theater69598855 locally; preserve174/121parts source, use suitable architecture/equipment only. Whole-room adoption optional.',
 'Rerun rendered lifecycle/art views after corrected architectural material. Refine geometry/shader/light and Canon interactions until actual quality gate passes.',
 'Current lab still rejected/REFINE. Verify actual connected route/save/camera/pause/RM/audio/performance before advancing to the next under-quality room.']
cache['external_state']='Flow473 last observed,12spent8s720p preserved. Tripo3030 latest visible aftersubscription;170labtotal. Task IDs and per-operation ledger saved. No purchase/stage/commit/publication.'
export=APP/'godot/export_presets.cfg';text=export.read_text(encoding='utf-8-sig')
old='"res://assets/environments/lab_clinical_cp45/neural_chair.glb"'
new='"res://assets/environments/lab_clinical_cp45/neural_chair_tripo_20k.glb"'
if new not in text:
 assert text.count(old)==3,text.count(old)
 shutil.copy2(export,backup/'export_presets.cfg')
 export.write_text(text.replace(old,old+', '+new),encoding='utf-8')
card=P/'CURRENT_WORK.ar.md';text=card.read_text(encoding='utf-8-sig')
marker='<!-- ROOM_POLICY_CURRENT -->'
if marker in text:text=text[:text.index(marker)]
text=text.replace('الإنفاق الجديد0.','الإنفاق الحالي موثق فيgeneration-ledger؛ لا تستعمل0التاريخية كرصد حي.')
text+='\n'+marker+'\n**سياسة المالك الأحدث:** صور4متسقة ثمFlow ثمTripo/Blender/الشيدر حسب الجودة للغرف دون المستوى؛ المختبر أولًا، والجيدة مثل01لا تُعاد تلقائيًا. توليد غرفة كاملة اختياري؛ لا قبول أو انتقال قبل البوابة. المرجع: `'+policy+'`.\n\n**تفعيل Tripo:**3145عند التفعيل،3030آخر رصد؛115جديد و170إجمالي المختبر. كرسي20,336مثلثًا ببصمة0aa2bb82 دخلGodot؛ مجموعة121جزءًا و190343مثلثًا مع4K محفوظة؛ الغرفة174جزءًا و176515مثلثًا محفوظة وخامة8Kالتجريبية مطلوبة. كلاهما تحت الفحص، وليس اعتمادًا.\n\n**الفحص الحالي:**26تحققًا headless لدورة الشاشات/الماء/Pause/RM/الجودة/التحميل، دون تغيير القصة. Native05/06 مراجعاتREFINE؛06أظهر get_meta errors ثمأُصلح الحارس وتلزم إعادة مصورة. الكاميرا/المسار/الأداء/الصوت/الفن النهائي مفتوحة؛649/363/223/58أعلاه تخص بصماتStage11القديمة.\n'
card.write_text(text,encoding='utf-8')
work=P/'WORK_TREE.ar.md';text=work.read_text(encoding='utf-8-sig')
row='| المختبر13 الحالي | clinical_lab_architecture.gd؛lab_memory_cinema.gd؛memory_reflection_space.gd | lab-rebuild-20261023/generation-ledger.json؛26headless lifecycle؛Native06REFINE؛Tripo174/121parts تحت الفحص؛الفن/المسار/الأداءOPEN |'
if '| المختبر13 الحالي |' not in text:text=text.replace('|---|---|---|','|---|---|---|\n'+row,1)
work.write_text(text,encoding='utf-8')
vision=APP/'docs/PROJECT_VISION.md';text=vision.read_text(encoding='utf-8-sig')
if '## توجيه المالك23أكتوبر2026 — سياسة الغرف السينمائية' not in text:
 shutil.copy2(vision,backup/'PROJECT_VISION.md')
 vision.write_text('## توجيه المالك23أكتوبر2026 — سياسة الغرف السينمائية\n\nالمختبر المرفوض يُصقل أولًا حتى بوابته الفعلية، ثم الغرف دون المستوى فقط. أربع صور متسقة ومشهدFlow مرجعي ومواردTripo/Blender وشيدرHyper Anime وتفاعلات سينمائية ذات غرض. توليد غرفة كاملة اختياري؛ النتيجة والجودة ومسار اللعب يحكمان. الغرف الجيدة مثل01لا تُعاد تلقائيًا. الاشتراك فُعل والكريديت المتاح مأذون لتحسين الموارد؛ لا شراء آخر ولا قبول تلقائي أو تغييرPART_3. التفصيل في `internal/production/ROOM_CINEMATIC_PRODUCTION_POLICY_2026-10-23.ar.md`.\n\n'+text,encoding='utf-8')
paths=['godot/scripts/environment/clinical_lab_architecture.gd','godot/scripts/environment/lab_memory_cinema.gd','godot/scripts/environment/memory_reflection_space.gd','godot/shaders/clinical_architecture_surface.gdshader','godot/shaders/clinical_porcelain_floor.gdshader','godot/assets/environments/lab_clinical_cp45/neural_chair_tripo_20k.glb','godot/tests/lab_presentation_lifecycle_review.gd','godot/export_presets.cfg','docs/PROJECT_VISION.md',policy,'docs/internal/production/CURRENT_WORK.ar.md','docs/internal/production/WORK_TREE.ar.md']
index=json.loads((P/'SOURCE_INDEX.json').read_text(encoding='utf-8-sig'));entries={i['path']:i for i in index['entries']}
for rel in paths:
 file=APP/rel
 if rel not in entries:
  item={'path':rel,'group':'lab_clinical_rebuild_cp45'};index['entries'].append(item);entries[rel]=item
 entries[rel].update(sha256=sha(file),bytes=file.stat().st_size,review_checkpoint=cache['checkpoint'])
 cache['verified_source_hashes'][rel]=sha(file)
(P/'SOURCE_INDEX.json').write_text(json.dumps(index,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
cache['verified_source_hashes']['docs/internal/production/SOURCE_INDEX.json']=sha(P/'SOURCE_INDEX.json')
(P/'CURRENT_CONTEXT_CACHE.json').write_text(json.dumps(cache,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('LAB_REBUILD_CHECKPOINT_SAVED_NOT_ACCEPTED',APP)
