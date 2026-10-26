"""Refresh the economical checkpoint only after the recorded gates finish."""
from pathlib import Path
import hashlib, json, shutil

APP = Path(__file__).resolve().parents[5]
CASE = Path(__file__).resolve().parent
PROD = APP / 'docs/internal/production'
EVIDENCE = CASE.relative_to(APP).as_posix()
CHECKPOINT = 'CP45_NATIVE_HORIZONTAL_SCOPED_PASS_CHAPTER_ART_OPEN'

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def write(path, obj):
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def backup(path):
    target = CASE / 'before' / ('checkpoint-'+path.name)
    if not target.exists():
        shutil.copy2(path, target)

if __name__ == '__main__':
    assert (APP/'godot/project.godot').exists(), APP
    post = read(CASE/'post-contract-final-forward/review.json')
    assert post['checks'] == 58 and post['route_retries'] == 0
    for resource, digest in post['source_hashes'].items():
        assert sha(APP/'godot'/resource.removeprefix('res://')) == digest, resource
    fresh_rel = 'audits/evidence/pre-tripo-20261018/cp37/route/cp45-native11-final-20261023/full-chapter.json'
    fresh = read(APP/fresh_rel)
    assert fresh['route_retries'] == 0 and fresh['display'] == 'headless'
    assert 'PASS interactive Zero encounter checks=223' in (CASE/'encounter-final.log').read_text(encoding='utf-8-sig')
    postflight = (CASE/'postflight-final.log').read_text(encoding='utf-8-sig')
    assert 'ALL CHECKS PASSED' in postflight and '648/649' not in postflight
    paths = [
        'godot/scripts/player/echo_player.gd', 'godot/scripts/player/echo_v31_motion_adapter.gd',
        'godot/scripts/cinematics/pact_revenge_presentation.gd', 'godot/export_presets.cfg',
        'godot/assets/animations/v31/attack_horizontal_cp45.res',
        'godot/assets/characters/echo_v31_short_jacket.glb',
        'godot/tests/combat_pause_contact_review.gd', 'godot/tests/combat_contact_regression.gd',
        'godot/tests/native_attack_pose_review.gd', 'godot/tests/native_melee_input_review.gd',
        'godot/tests/echo_v31_runtime_asset_review.gd', 'godot/tests/full_chapter_journey_review.gd',
        'godot/tests/native_campaign_route_review.gd', 'godot/tests/zero_encounter_route_input.gd',
        'godot/tests/post_contract_journey_review.gd', 'godot/tests/zero_encounter_player_review.gd',
        'tools/animation-library/v31_parkour_motion.py',
    ]
    hashes = {p: sha(APP/p) for p in paths}
    report = {
        'date':'2026-10-23','status':CHECKPOINT,'phase':'PART_3',
        'scope':'One original grounded native cut; pause-safe contact; bounded obstruction clearance; earned pact through ward and a fresh headless connected route. Final chapter/art/device/account acceptance remains OPEN.',
        'native_motion':{'name':'Standing Melee Attack Horizontal','samples':73,'fps':30,'duration_seconds':2.4,'keys_preserved':4380,'blender_replay_max_m':0.000007150958423905144,'godot_all_joints':'horizontal/godot-all-joints.json','blender_visual':'horizontal/blender-visual-review.json','actual_pose_checks':5042,'actual_pose':'horizontal/actual-pose-compat/review.json','contact_seconds':0.933333333333335,'source_sha256':'088cddda8d40025753006381f1bfcbe77e101d5dca5875e83a5a5ffdab2dabad'},
        'verification':{'postflight':'postflight-final.log','golden':'golden-delivery.log','native_contact':'native-input-delivery.log','combat':'combat-delivery.log','pause':'pause-delivery.log','camera':'camera-readable/camera-review.json','legacy_camera':'legacy-camera-return.log','zero':'encounter-final.log','zero_checks':223,'post_contract_forward':'post-contract-final-forward/review.json','post_contract_checks':58,'fresh_headless':fresh_rel,'fresh_checks':fresh['checks'],'fresh_retries':fresh['route_retries']},
        'visual_review':'All146 Blender source/target comparisons and30 actual Godot pose views inspected; final Forward+ three native cuts and ward captures inspected. Both actors now readable; fingers partly open and saturated lab palette remain final-art issues.',
        'prior_failures':[
            'Original always-processing melee timer damaged during pause; regression reproduced, corrected with pausable physics timer.',
            'SwordAndShield jumping lunge rejected for grounded tap after full106-view review.',
            'Downward frozen bake failed10um gate at10.5207um; quarantined with diagnostic blend. No gate relaxation or export.',
            'First post-contract driver had stale capture callback and film preference assumptions; driver corrected; runtime gates retained.',
            'First native postflight648/649 during concurrent heavy jobs: forced-mate assertion failed; final serial result recorded separately. Cause not proven.',
            'First camera clearance returned only1.13m; visual review rejected cramped framing, existing bounded solver refined to3m.'
        ],
        'adviser':{'url':'https://gemini.google.com/u/6/app/26fffb5360f69e02','model':'4 Argon High verified before/after','scope':'Text diagnostic advice only, no visual approval','evidence':'argon-precision-review.txt'},
        'open':['Fine finger enclosure and hand/weapon self-contact art','Distinct three-cut acting and natural charged Iai acting','Stage13 room palette/material/face/Japanese voice and audio listening','Stage14 physical devices, performance across chapter, independent playtest, live account/server receipts and fresh package'],
        'preserved':'Golden192, original V31 body/face/rest/binds/source keys; native timing; SFX_ONLY; consent and server authority. No new spending/purchase/staging/commit/push/publication.',
        'source_hashes':hashes,
    }
    write(CASE/'delivery.json',report)
    for name in ['CURRENT_WORK.ar.md','CURRENT_CONTEXT_CACHE.json','SOURCE_INDEX.json','WORK_TREE.ar.md']:
        backup(PROD/name)
    cache = read(PROD/'CURRENT_CONTEXT_CACHE.json')
    cache.update(checkpoint=CHECKPOINT,date='2026-10-23',status='STAGE11_NATIVE_CUT_AND_CAMERA_SCOPED_PASS__STAGE12_EARNED_WARD_PASS__FINAL_ART_AND_RELEASE_OPEN')
    cache['active_gate'] = {
        'scope':'Stage11 original grounded cut integrated; native source clock/keys unchanged. Stage12 earned pact -> explicit revenge/wish -> actual ward input/mirror PASS.',
        'evidence':EVIDENCE+'/delivery.json',
        'checks':{'postflight':'649/649 + typecheck/content/build PASS; earlier648/649 attempt retained','golden':'192 PASS','zero':'223 rendered Compatibility/14 reloads/2 independent accepts','native':'4380 keys/73 native samples/68 joints;5042 pose checks; contact and blade intersection both0.933333s','camera':'16 checks;0.952m ->3.000m;manual orbit and collision masks preserved','post_contract':'58 rendered Forward+,0 retries,film/skip race and actual ward mirror','fresh_headless':str(fresh['checks'])+' checks,0 retries; local connectivity only'},
        'rejected':'SwordAndShield jumping lunge; Downward69 bake10.5207um over10um, quarantined unchanged.',
        'art_boundary':'One cut reused for3 damage steps. Palm attachment stable; partly open fingers, distinct combo/Iai acting, lab saturation/lighting and final audio/art remain13. No final chapter/device/release approval.'
    }
    cache['verified_source_hashes'] = {p:hashes[p] for p in paths[:6]}
    cache['next'] = ['Stage13: fine hand/weapon grip via admissible original source, distinct combo/Iai acting, coherent room palette/materials/face and Japanese SFX_ONLY review. Preserve frozen source keys/Golden.','Stage14: fresh rendered whole chapter, save/pause/skip/RM, independent playtest/performance/devices/live account receipts and verified fresh package.']
    cache['external_state'] = 'Adobe login restored using owner-selected account. No new generation/spending/purchase/staging/commit/publication. Flow437/Tripo200 are historical, recheck before any spend.'
    write(PROD/'CURRENT_CONTEXT_CACHE.json',cache)
    card = f'''# المتابعة الحالية — CP45 / 23 أكتوبر2026

**الآن: ضربة أرضية أصلية وكاميرا مواجهة اجتازتا التحقق المحدود؛ مسار العقد المكتسب إلى المستشفى يعمل. الفن النهائي والاعتماد14 مفتوحان. PART_3 ثابت.**

ابدأ من `CURRENT_CONTEXT_CACHE.json` ثم `{EVIDENCE}/delivery.json` وصف النظام المطلوب فقط. لا تعد التاريخ أو التوليد؛ النسخة السابقة من البطاقة محفوظة في `stage11/native-attack-20261023/before/checkpoint-CURRENT_WORK.ar.md` تحت دليلCP45.

**11 — PASS محدود:** Standing Melee Attack Horizontal الأصلي73عينة/30Hz/2.4ث،4380مفتاحًا محفوظة؛ Golden192. كل68عظمة اجتازت Godot؛146مقارنةBlender و30لقطةGodot فُحصت،5042تحققًا للوضعية. المصدر الحالي والوجه والجسم والربط لم تُستبدل. السيف ثابت على الكف، لكن انطباق الأصابع والفن الدقيق مفتوحان. نفس القطع يخدم3درجات ضرر؛ لا ادعاء3حركات متميزة أو Iai طبيعي جديد.

تلامس النصل والضرر متزامنان فعليًا عند0.933333ث في عينة الهدف1.8م؛ لم يُستبدل نظام مخروط/مدى الضرب بمسح نصل شامل. أُصلح وقوع الضرر أثناءPause؛ الإلغاء بالحركة بعد1.2ث والقفز/المراوغة/سحب القدرة والغطاء PASS. الكاميرا الملتصقة بالممثل حُلّت بإعادة استخدام خلوصها المحدود90°:0.952→3m، مع حفظ النظر اليدوي والمصادمات؛16تحققًا وانحدار الكاميرا القديمة PASS.

**العقد/12:**223تحققًا مصورًا Compatibility،14reload وقبولان مستقلان. من حفظ العقد المكتسب حتى ثلاث ضربات→متابعة الانتقام الصريحة→الأمنية الوحيدة→العبور الفعلي→فيلم المستشفى/سباقskip→استيقاظ ومشي ومرآة:58Forward+،صفر إعادة. صور الضربات والمستشفى الحالية فُحصت. المسار الجديد الكامل headless:{fresh['checks']}تحققًا وصفر إعادة؛ إثبات اتصال محلي فقط، لا قبول بصري كامل أو حساب حي.

**المفصل الشامل الثاني:**postflight649/649 وtypecheck/content/build PASS. محاولة648/649 السابقة محفوظة؛ فشل forced-mate أثناء حمل متزامن، والسبب غير مثبت. النتيجة النهائية تشغيل متسلسل. لا حزمة جديدة؛ قوائم التصدير الثلاث تشمل المورد الجديد.

**رفض محفوظ:**SwordAndShield قفزة/اندفاع غير مناسب؛Downward69 فشل10um بفارق10.5207um عندLeftToeBase/frame32. لا تخفيف للحارس، لا تصدير أو دمج لذلك المرشح. Horizontal مؤهل مستقلًا. استشارة4ArgonHigh فعلية نصية فقط؛ لا تنسب قبول صور له.

**التالي13 ثم14:**قبضة الأصابع ومصدر حركة صالح، تمثيلCombo/Iai، تشبع المختبر والخامات والإضاءة والوجه والتمثيل الياباني/SFX_ONLY؛ ثم المسار المصور الكامل والحفظ/الإيقاف/التجاوز/RM والأداء والأجهزة والمتعة المستقلة والإيصالات الحية والحزمة. لا ادعاءAAA/Steam/اكتمال الفصل.01–09 وأصل السترة القصيرة محفوظة؛ تفاصيلها في الأرشيف والتقارير الأصلية.

العمل فردي؛لاcommit/stage/push/شراء/نشر. الإنفاق الجديد0. Canon/EX-011/Golden/V31/المفاتيح وسلطة الحساب محفوظة. أرصدةFlow/Tripo القديمة تاريخية؛افحصها حيًا قبل إنفاق. الكاش مختصر والأصل مؤرشف، دون ضمان لتغيير احتساب حصة مزود الخدمة.
'''
    (PROD/'CURRENT_WORK.ar.md').write_text(card,encoding='utf-8')
    index = read(PROD/'SOURCE_INDEX.json')
    index.update(snapshot_date='2026-10-23',status=CHECKPOINT,last_runtime_integration_checkpoint=CHECKPOINT,last_full_chapter_review=fresh_rel)
    index['stage11_verification']={'report':EVIDENCE+'/delivery.json','scope':report['scope']}
    for p in paths:
        entry=next((e for e in index['entries'] if e['path']==p),None)
        if entry is None:
            entry={'group':'stage11_native_cut','path':p}
            index['entries'].append(entry)
        entry.update(sha256=hashes[p],bytes=(APP/p).stat().st_size,review_checkpoint=CHECKPOINT)
    write(PROD/'SOURCE_INDEX.json',index)
    tree=(PROD/'WORK_TREE.ar.md').read_text(encoding='utf-8-sig')
    tree=tree.replace('CP45 / 21 أكتوبر2026','CP45 / 23 أكتوبر2026')
    marker='| الشخصية الحالية |'
    insertion=f'| القطع الأرضي11/الكاميرا/المستشفى12 | echo_player.gd؛ echo_v31_motion_adapter.gd؛ attack_horizontal_cp45.res؛ pact_revenge_presentation.gd | {EVIDENCE}/delivery.json؛73/30Hz،4380مفتاحًا،5042وضعية،223عقدًا،58Forward+،{fresh["checks"]}headless/0retry؛الفن/الأجهزة/الحزمةOPEN |\n'
    tree=tree.replace(marker,insertion+marker,1)
    (PROD/'WORK_TREE.ar.md').write_text(tree,encoding='utf-8')
    map_path=APP.parents[1]/'PROJECT_MAP.ar.md'
    backup(map_path)
    mapping=map_path.read_text(encoding='utf-8-sig').splitlines()
    mapping[2]=f'الحالة الحالية: **{CHECKPOINT} /23أكتوبر2026**. ضربة أصلية73عينة/30Hz،كاميرا واضحة،223عقدًا و58Forward+حتى المستشفى؛{fresh["checks"]}تحققًا للمسارالجديدheadless،صفرإعادة. Golden192 وpostflight649PASS. ابدأ منCURRENT_WORK/cache ثم `{EVIDENCE}/delivery.json`؛الفن13 والأجهزة/الإيصالات/الحزمة14 مفتوحة. الفقرات الأقدم أدناه تاريخية.'
    map_path.write_text('\n'.join(mapping)+'\n',encoding='utf-8')
    continuation=APP/'docs/11-11/design/CONTINUATION.md'
    backup(continuation)
    with continuation.open('a',encoding='utf-8') as f:
        f.write(f'\n\n## CP45 /2026-10-23 — native cut and second regression junction\n\n{CHECKPOINT}. Original73sample/30Hz/4380key grounded cut integrated unchanged on V31;5042 actual pose checks. Pausable physics contact and blade intersection align0.933333s. Existing bounded camera solver restores3m while preserving manual look/masks.223 Zero checks/14 reloads;58 rendered Forward+ earned pact to ward;fresh headless{fresh["checks"]}/0retry. Golden192 and serial postflight649PASS. Exact hashes/rejected sources/earlier failed attempts: `{EVIDENCE}/delivery.json`. Fine fingers, distinct combo/Iai acting, room palette/material/face/Japanese audio13 and performance/devices/live receipts/fresh package14 OPEN. No new spend/staging/commit/publication. Current economical cache/card supersede old checkpoints.\n')
    original=PROD/'archive/before_stage11_20261023_CURRENT_CONTEXT_CACHE.json'
    print(json.dumps({'checkpoint':CHECKPOINT,'cache_bytes':(PROD/'CURRENT_CONTEXT_CACHE.json').stat().st_size,'original_cache_bytes':original.stat().st_size,'fresh_checks':fresh['checks']},ensure_ascii=False))
