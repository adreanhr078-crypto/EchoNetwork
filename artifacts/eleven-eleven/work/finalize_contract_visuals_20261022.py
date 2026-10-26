"""Compact, evidence-linked continuation record; no source/model modification."""
import hashlib,json,shutil
from pathlib import Path
root=Path(__file__).resolve().parents[1]
prod=root/'docs/internal/production'
evidence=root/'audits/evidence/chapter-cp45-20261020/stage10/charged-gate-20261022'
out=Path('C:/Users/yasmo/Documents/Codex/2026-10-21/11-11-cp44-thread-01a15e1d-f5da/outputs/contract-visuals')
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,data):p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
runtime=[
'godot/scripts/cinematics/pact_revenge_presentation.gd','godot/scripts/systems/native_campaign_controller.gd',
'godot/scripts/player/echo_player.gd','godot/scripts/player/ghost_trail_spawner.gd',
'godot/scripts/player/echo_contract_resonance.gd','godot/scripts/player/zero_shadow_wing.gd',
'godot/scripts/player/zero_eye_singularity.gd','godot/scripts/combat/shadow_wave_projectile.gd',
'godot/scripts/ui/system_window.gd','godot/scripts/ui/system_signal_glass.gd',
'godot/engine_visuals/shaders/motion_echo.gdshader','godot/engine_visuals/shaders/signal_cut.gdshader',
'godot/engine_visuals/shaders/contract_resonance.gdshader','godot/shaders/zero_contract_iris.gdshader',
'godot/shaders/zero_feather_detail.gdshader','godot/tests/zero_encounter_player_review.gd',
'godot/tests/combat_contact_regression.gd','godot/tests/ghost_skin_snapshot_review.gd']
hashes={p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in runtime}
full=read(evidence/'legendary-rendered/review.json')
assert full['checks']==222 and full['reloads']==14
assert 'PASS isolated earned contract reveal checks=16' in (evidence/'pupil-compat-final.log').read_text()
forward=read(evidence/'pupil-forward-final/reveal-review.json')
assert forward['checks']==16 and forward['renderer']=='forward_plus'
assert 'PASS isolated actual earned power-test checkpoint checks=10' in (evidence/'tap-final.log').read_text()
assert 'PASS charged contact: low cover, diagonal cover' in (evidence/'combat-final-paced.log').read_text()
for p,h in full['source_hashes'].items():
    if p.startswith('tests/'):continue
    assert hashlib.sha256((root/'godot'/p).read_bytes()).hexdigest()==h,p
for p,h in forward['source_hashes'].items():
    assert hashlib.sha256((root/'godot'/p).read_bytes()).hexdigest()==h,p
delivery={
 'checkpoint':'CP45_CONTRACT_VISUALS_AND_CHARGED_GATE_SCOPED_VERIFIED',
 'date':'2026-10-22','status':'SCOPED_PASS_FINAL_ART_AND_CHAPTER_OPEN',
 'changes':['Quiet translucent red system glass; readable opaque text/focus.',
 'Purple source-iris radiance and fine optical facial veins, source wing emergence/root and anatomical left forearm/hand resonance; four owned camera shots after explicit consent.',
 'Real charged versus tap release, safe in-room staging, camera lease fallback/defer fixes.',
 'Independent wing skin excluded from body ghosts; actual swept placement, bounded transparent arcs/wave, near-camera ghost fading.',
 'No body/face/rest/native animation source modifications.'],
 'evidence':{'earned_rendered_encounter':'legendary-rendered/review.json','checks':222,'reloads':14,
 'final_reveal_compatibility':'pupil-compat-final.log','final_reveal_forward_plus':'pupil-forward-final/reveal-review.json','reveal_checks_each':16,
 'tap':'tap-final.log','tap_checks':10,'cover_contact':'combat-final-paced.log',
 'snapshot_geometry':'ghost-veins-final/review.json','snapshot_checks':354,'maximum_baked_skin_error_m':3.93209984395071e-6,
 'legacy_manifestation':'manifestation-backcompat.log','legacy_checks':48,'notice_queue':'quiet-ui.log','notice_checks':34,'golden':'golden-current.log','golden_files':192},
 'evidence_boundary':'Full222/reloads14 covers unchanged gameplay, camera, UI, ghost shader and assets. Subsequent changes only resonance/iris visual strength, adjacent optical facial veins on exact source weights and reveal capture timing; final16-shot/pause/RM verification on both renderers. Snapshot354 includes the new facial-skin overlay and near-camera fade; the final pupil adjustment is fragment color only. Not final acting, art, fun, device/performance, chapter, package or Steam acceptance.',
 'rejected_visual_iterations':['Camera wall contraction to0.16m','Old giant opaque slash and near-camera trail projection','Dim Compatibility aura before visible-radiance correction'],
 'current_source_hashes':hashes,'additional_tripo_spend':0,
 'owner_eye_direction':'Purple luminous source iris with fine optical facial veins; source atlas pupil contrast retained. Inspired mood only; no eye enlargement, original face/body deformation, or source texture replacement.',
 'next':['Stage11 native weapon/hand grip and attack performance: SwordAndShield original53samples/30Hz baked in isolation;106 comparison images not fully reviewed, no runtime integration.',
 'Stage12 wish/hospital;13 final art/face/fingers/acting/audio;14 complete route/save/device/performance/package/live receipts.']}
write(evidence/'delivery.json',delivery)
cache=read(prod/'CURRENT_CONTEXT_CACHE.json')
cache.pop('active_visual_work_20261022',None);cache['checkpoint']=delivery['checkpoint'];cache['contract_visuals_20261022']={'delivery':str((evidence/'delivery.json').relative_to(root)).replace('\\','/'),'status':delivery['status'],'checks':222,'reloads':14,'final_reveal_each_renderer':16,'additional_credits':0,'next':delivery['next']}
cache['resume_20261022'].update(state=delivery['checkpoint'],encounter='222 actual rendered checks/14 reloads; final reveal16 each renderer. Final art/whole chapter OPEN.',combat='Actual charged .8067 and tap0 observed; low/diagonal cover and child damageable collider PASS; native weapon motion/grip OPEN.')
write(prod/'CURRENT_CONTEXT_CACHE.json',cache)
resume=root/'audits/evidence/chapter-cp45-20261020/stage11/resume-state-20261022.json'
state=read(resume);state.update(checkpoint=delivery['checkpoint'],status=delivery['status'],current_verification_boundary=delivery['evidence_boundary'],next=delivery['next'],current_contract_delivery=cache['contract_visuals_20261022']['delivery'])
state['current_source_hashes'].update(hashes);write(resume,state)
card=prod/'CURRENT_WORK.ar.md';text=card.read_text(encoding='utf-8-sig')
text=text.replace('**الآن: المرحلة10 مفتوحة؛ أُنجز تغيير الشخصية المحدود بقص المعطف بموافقة المالك.**','**الآن: تحقق محدود للعقد والعرض البنفسجي والعين ذات العروق البصرية؛ الحركة القتالية11 والفن النهائي ما زالا مفتوحين.**')
start=text.index('**استئناف مقتصد');end=text.index('**قص المعطف',start)
text=text[:start]+'**استئناف مقتصد —22أكتوبر:** ابدأ من `audits/evidence/chapter-cp45-20261020/stage10/charged-gate-20261022/delivery.json` ثم cache؛ لا تعد قراءة التاريخ. السحب المشحون الحقيقي وملكية الكاميرا/التأجيل:222تحققًا Windows/14reload. كشف الجناح/العين/اليد والشفافية:16تحققًا على كل من Compatibility وForward+؛ pause/RM؛ صور فعلية مراجعة. اللوحة الحمراء أهدأ وشفافة؛ وهج بنفسجي للقزحية الأصلية وعروق بصرية رفيعة حولها وجذر الجناح واليد اليسرى. الجسم/الوجه/68عظمة ومفاتيح الحركة محفوظة. قبول الفن النهائي/الأداء/الفصل ما زال OPEN.\n\n'+text[end:]
start=text.index('**القتال مفتوح:**');end=text.index('**تريبو الحالي:**',start)
text=text[:start]+'**القتال11 مفتوح:** charged فعلي بنسبة0.8067 وتاب0، كاميرا السحب بقيت قرابة3m داخل الغرفة. الغطاء المنخفض/المائل وdamageable child PASS. أُزيل خلط skin الجناح المستقل في أشباح الجسم؛354تحققًا بمقارنة جلد مخبوز من المحرك وخطأ أقصى0.00394mm، ثم تلاشي الأشباح قرب الكاميرا. أقواس/موجة شفافة محدودة. مصدر SwordAndShield خُبز مع53عينة30Hz في العزل؛106صور مقارنة أُنشئت ولم تكتمل مراجعتها، ولا دمج/اعتماد قبضة كاتانا. لا تعلن اكتمال11.\n\n'+text[end:]
text=text.replace('اجتاز التشخيص والتقاط المصدر فقط، والمراجعة/الخبز/الدمج لم تتم.','اجتاز التشخيص والخبز المقارن في العزل، والمراجعة الشاملة/الدمج لم تتم.')
card.write_text(text,encoding='utf-8')
index=read(prod/'SOURCE_INDEX.json');index['status']=delivery['checkpoint'];index['last_runtime_integration_checkpoint']=delivery['checkpoint']
for p in runtime:
    entry=next((x for x in index['entries'] if x.get('path')==p),None)
    if entry is None:entry={'group':'contract_presentation','path':p};index['entries'].append(entry)
    entry.update(sha256=hashes[p],bytes=(root/p).stat().st_size,review_checkpoint=delivery['checkpoint'])
write(prod/'SOURCE_INDEX.json',index)
tree=prod/'WORK_TREE.ar.md';text=tree.read_text(encoding='utf-8-sig');marker='| النظام/الغرفة | المصدر الأول | الدليل/الحد |'
text=text.replace('|---|---|---|','|---|---|---|\n| العقد/العرض البنفسجي الحالي | pact_revenge_presentation.gd؛ echo_contract_resonance.gd؛ zero_shadow_wing.gd؛ zero_contract_iris.gdshader؛ system_window.gd | stage10/charged-gate-20261022/delivery.json؛222/14reload؛16كشف بكل renderer؛ الفن النهائي OPEN |',1);tree.write_text(text,encoding='utf-8')
out.mkdir(parents=True,exist_ok=True)
for shot in ['wing','eye','hand','portrait','reduced-static']:
    shutil.copy2(evidence/f'pupil-forward-final/contract-{shot}.png',out/f'contract-{shot}.png')
shutil.copy2(evidence/'legendary-rendered/question-0.png',out/'quiet-system-window.png')
shutil.copy2(evidence/'legendary-rendered/beat-07-power-action.png',out/'charged-gameplay.png')
write(out/'verification.json',delivery)
(out/'README.ar.md').write_text('نافذة النظام أصبحت أهدأ وشفافة. ظهور الجناح البنفسجي من الظهر مع وهج الجذر والعين الأصلية وعروق بصرية رفيعة حولها واليد اليسرى، ولقطات العقد داخل Godot. الجسم والوجه ومصادر الحركة محفوظة.\n\n222تحققًا و14إعادة تحميل للعقد، ثم16تحققًا لكشف القوة في كل renderer. صور هذا المجلد من Forward+ الفعلي، باستثناء صورة اللوحة والضربة من Compatibility. هذا قبول محدود للتغيير؛ تشطيب الفن والقتال والفصل والأداء وSteam ما زالت مفتوحة.\n',encoding='utf-8')
print(json.dumps({'delivery':str(evidence/'delivery.json'),'outputs':str(out),'status':delivery['status']}))
