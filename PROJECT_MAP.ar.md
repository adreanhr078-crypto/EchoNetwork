# Active execution CP-20261008-01 — 2026-10-08

Production is IN_PROGRESS. Read artifacts/eleven-eleven/docs/internal/production/CURRENT_WORK.ar.md first; historical acceptance claims below are not current proof. Echo owner-adoptedV31 isolatedrig/motion; Zero Tripo source+rig95credits actual; Gemini assets task dispatched; Flow938credits verified. GuardGolden and preserve all dirty work. No finalart/deviceacceptance.

---

# خريطة المشروع والتحكم المركزي — EchoNetwork / 11.11

> **القاعدة الذهبية للتنقل (Owner Navigation Rule):**
> لا تقرأ كامل ملفات المستودع أو السجلات التاريخية أبداً. ابدأ دائماً من هذه الخريطة، ثم اقرأ بطاقة المتابعة الحالية في `artifacts/eleven-eleven/docs/internal/production/CURRENT_WORK.ar.md`. افتح فقط ملفات النظام المعني بالمهمة، ونفّذ، وافحص، ثم حدّث الخريطة والبطاقة بعد كل تسليم فعلي مثبت بالأدلة.

---

متابعة الجودة الحالية: `artifacts/eleven-eleven/docs/internal/production/ANTIGRAVITY_QUALITY_REPAIR_2026-10-06.ar.md`؛ تشخيص الاتجاه/Golden في `ANIMATION_FACING_GOLDEN_REVIEW_2026-10-06.ar.md`. الاختبارات الجديدة `avatar_facing_review.gd` و`player_facing_regression.gd`؛ ربط الغرف `native_campaign_controller.gd` واختبار `native_campaign_route_review.gd`. الحالة IN_PROGRESS، لا اعتماد AAA أو الفصل.

تنفيذ المقطع المعتمد في `OPENING_QUALITY_EXECUTION_2026-10-06.ar.md` داخل مجلد الإنتاج نفسه: الحوار والأدلة والإضاءة، واختبارات `dialogue_readability_review.gd` و`opening_evidence_review.gd` و`opening_frame_budget_review.gd`. ملف التحقق الجديد `tools/animation-library/current_target_motion.py` داخل التطبيق؛ Run الحالي FAIL بصريًا ولا تصدير. حزمة مهمة Claude مجهزة في `ANTIGRAVITY_CLAUDE_HANDOFF_2026-10-06.ar.md` ولم ترسل لأن Use Computer لا ترى نافذة Antigravity.

تحديث CP-20261006-02: وافق المالك على المرجع المشتق المعزول؛ أدوات `measured_target_reference.py` و`review_measured_reference.py` و`measured_target_motion.py` داخل animation-library، والأدلة `quality-execution-20261006/current-target/reference-pose-v1` و`run-attempt-02`. الأصل وGolden محفوظان، لا دمج. المتصفح الذي فتحه المالك حل عائق الوصول: تم التحقق من Claude Sonnet 5.5 Medium وإرسال تشخيص rig/skin محدود للقراءة فقط؛ حالة الوكيل RUNNING، لا ناتج نهائي بعد. الاختبارات المحلية الحالية PASS631 و16/16، لا اعتماد فني أو هاتف.

## 1. لوحة الملاحة والتحكم السريع (Quick Navigation Matrix)

حدد نوع مهمتك من الجدول التالي واذهب مباشرة إلى الملفات والأوامر المحددة دون مسح باقي المشروع:

| مجال المهمة | الملفات الأساسية التي تبدأ منها | مسار الأصول / الشيفرة | أمر الفحص / التشغيل |
|---|---|---|---|
| **توليد فيديو/وسائط الذكاء الاصطناعي (Higgsfield / Seedance)** | `index.ts`<br>`tools/higgsfield/run-higgsfield.ts` | `tools/higgsfield/`<br>`.env.local` (محمي) | `npm run higgsfield:example`<br>`npx tsx tools/higgsfield/run-higgsfield.ts -- doctor` |
| **اختيار نموذج Higgsfield بحسب توجيه المالك** | `artifacts/eleven-eleven/docs/internal/production/HIGGSFIELD_MODEL_POLICY_2026-10-01.ar.md` | `higgsfield-preferred-models.json` في المجلد نفسه | Seedance 2.5 / 2.0 للفيديو؛ Jutsu/Blender للمشهد القابل للتحرير؛ تحقق من الكتالوج قبل التشغيل |
| **تحريك الشخصيات والمرجع الذهبي (Golden Animation)** | `tools/animation-library/golden_reference.py`<br>`tools/animation-library/single_motion.py` | `art/production/master-animation-library/golden/`<br>`.agents/skills/echo-golden-animation/` | `python tools/animation-library/golden_reference.py`<br>`python tools/animation-library/test_golden_pipeline.py` |
| **محرك اللعبة والجيم بلاي (Godot 4.7 Engine)** | `artifacts/eleven-eleven/godot/scripts/player/echo_player.gd`<br>`godot/scripts/boot.gd` | `artifacts/eleven-eleven/godot/scenes/`<br>`godot/scripts/`<br>`godot/assets/` | `npm run godot:test`<br>`npm run godot:doctor`<br>`npm run godot:test-combat` |
| **واجهة اللمس وتحكم الهاتف وقائمة الإيقاف** | `godot/scripts/ui/mobile_touch_controls.gd`<br>`godot/scripts/ui/native_pause_menu.gd` | `artifacts/eleven-eleven/godot/scenes/ui/` | `npm run godot:test`<br>`godot/tests/player_controls_capture.gd` |
| **خطة التحكم والمنظور الثالث حسب التوجيه الأخير** | `artifacts/eleven-eleven/docs/internal/production/THIRD_PERSON_FOUNDATION_PLAN_2026-10-01.ar.md`<br>`CURRENT_WORK.ar.md` | `godot/scripts/player/` و`godot/scripts/ui/mobile_touch_controls.gd` داخل التطبيق | `tools/test-third-person-foundation.ps1` داخل التطبيق:16 حالة محلية؛ Walk/Run تدريجيان وRoll منفصل منفذان، الفن والهاتف غير مقبولين |
| **مراجعة الجاذبية والحركة الفعلية** | `artifacts/eleven-eleven/docs/internal/production/PROFESSIONAL_ART_REVIEW_2026-10-01.ar.md` | `audits/evidence/third-person-foundation-20261001/implementation/art-review-v3/` و`audits/evidence/sprint-natural-20261001/` داخل التطبيق | `godot/tests/player_art_review_capture.gd` و`opening_art_direction_capture.gd` للتصوير المرئي؛ Run البديلةFAIL_CONTACT معزولة، لاexport أوتبديلavatar |
| **إصلاح غرفة المرجع والوقفة الحالي** | `artifacts/eleven-eleven/docs/internal/production/CHARACTER_REFERENCE_REPAIR_2026-10-01.ar.md` | `audits/evidence/character-shading-20261001/` داخل التطبيق | `character_light_response_smoke.gd` و`character_authored_maps_smoke.gd` مرئيان؛ nativeIdlecandidate معزولة حتى القبول |
| **native من الافتتاح إلى عتبة الأمن** | `godot/scripts/systems/native_journey_controller.gd` و`native_journey_checkpoint.gd` داخل التطبيق | `godot/scenes/native_journey.tscn`؛ `audits/evidence/hospital-route-20261001/` | `native_journey_checkpoint_smoke.gd` و`opening_route_input_smoke.gd -- native-journey`؛ hospitalrouteغير مكتملة، الأمن/bedside أصول مراجعة منفصلة |
| **قياس الهاتف المعزول وإصلاح الإدخال** | `godot/scripts/diagnostics/player_frame_capture.gd`<br>`godot/tests/player_foundation_smoke.gd`<br>`godot/tests/player_frame_capture_smoke.gd` | `artifacts/eleven-eleven/audits/evidence/player-foundation-20260930/` | العلم `--echo-frame-capture` في debug فقط؛ لا يعوض اختبار الهاتف الفعلي |
| **فحص أصابع الشخصية دون تغيير اللاعب** | `audits/evidence/echo-hand-rig-20261001/ROOT_CAUSE.md`<br>`fit_hand_landmarks.py`<br>`build_left_hand_candidate.py` | `art/production/echo-master-character/rig-v3-hands/` داخل التطبيق | مراجعة rest/curl/spread في Blender؛ محاولتان كحد أقصى؛ لا export قبل قبول التشوه |
| **واجهة الويب والشطرنج والقصة (React 19 / Three.js)** | `artifacts/eleven-eleven/src/app/`<br>`artifacts/eleven-eleven/src/components/` | `artifacts/eleven-eleven/src/`<br>`artifacts/eleven-eleven/public/` | `npm run check`<br>`npm run typecheck`<br>`npm test` |
| **الخدمات السحابية والريل تايم (Cloudflare Workers)** | `artifacts/eleven-eleven/workers/realtime/` | `artifacts/eleven-eleven/workers/` | `npm run check:realtime`<br>`npm run typecheck:realtime` |
| **أدوات الوسائط والبلندر بدون تثبيت (Media & Blender CLI)** | `tools/blender/run-blender.ts`<br>`tools/media/validate-glb.ts` | `tools/blender/`<br>`tools/media/` | `npm run blender:doctor`<br>`npm run gltf:validate` |
| **بوابات الجودة والفحص العام (Autonomous Quality Gate)** | `artifacts/eleven-eleven/tools/project-doctor/` | `tools/environment-setup/` | `npm run agent:preflight`<br>`npm run doctor`<br>`npm run agent:postflight` |

---

## 2. هيكل المستودع المنظم (Repository Structure Map)

```text
EchoNetwork/
├── .agents/skills/                 # المهارات المتخصصة وقواعد وكلاء الذكاء الاصطناعي (مثل echo-golden-animation)
├── .env.local                      # مفاتيح وبيئة الخادم المحلية (محمية ومستثناة من Git)
├── index.ts                        # نقطة الدخول الرسمية لـ Higgsfield SDK مع Seedance 2.5
├── package.json                    # إعدادات الحزم المركزية والأوامر العامة (npm)
├── PROJECT_MAP.ar.md               # هذه الخريطة المرجعية الشاملة (دليل الملاحة الأول)
│
├── tools/                          # أدوات الدعم والأتمتة المستقلة:
│   ├── higgsfield/                 # عميل وأدوات Higgsfield AI وتحويل Blender إلى فيديو
│   ├── blender/                    # أداة تشغيل Blender Headless المحمولة
│   ├── godot/                      # أداة تشغيل وفحص واختبارات Godot Headless
│   ├── unity/                      # أداة ومسارات Unity CLI
│   ├── canva/                      # واجهة Canva API للتصاميم
│   ├── stable-diffusion/           # مشغل ومولد ComfyUI المحلي
│   ├── ai-audio/                   # أدوات توليد الصوت عبر TTS
│   ├── media/                      # أدوات ضغط وفحص GLB/GLTF وتشفير الفيديو
│   └── environment-setup/          # فحص وتجهيز بيئة العمل
│
├── artifacts/eleven-eleven/        # تطبيق اللعبة والإنتاج النشط (القلب النابض للمشروع):
│   ├── godot/                      # مشروع محرك Godot 4.7 (النسخة ثلاثية الأبعاد المعتمدة):
│   │   ├── scenes/                 # مشاهد اللعبة (اللاعب echo_player.tscn، الصيانة، الغرف)
│   │   ├── scripts/                # سكربتات GDScript (اللاعب، الكاميرا Phantom Camera، البيئة، الواجهات)
│   │   ├── assets/                 # أصول التشغيل الفعلية (المجسمات GLB، الخامات، المؤثرات الصوتية)
│   │   ├── tests/                  # اختبارات Godot التلقائية (التحكم باللمس، التحريك، الغرف)
│   │   └── addons/                 # إضافات المحرك المعتمدة (مثل Phantom Camera)
│   │
│   ├── src/                        # واجهة الويب وتطبيق React 19 + Three.js / R3F:
│   │   ├── app/                    # التوجيه وهيكل التطبيق
│   │   ├── components/             # مكونات واجهة المستخدم (لوحة الشطرنج، الألغاز، المانهوا)
│   │   ├── stores/                 # إدارة الحالة بالعميل عبر Zustand
│   │   └── ui/                     # مكتبة مكونات Radix UI و Tailwind
│   │
│   ├── art/production/             # أصول الإنتاج الفني القابلة للتحرير (Blender, Rig, Kitting):
│   │   ├── master-animation-library/# مكتبة التحريك الرئيسية والمرجع الذهبي المجمد (golden/walk-v1/)
│   │   ├── echo-master-character/  # شخصية إيكو الرئيسية وهيكلها العظمي ونماذج LOD
│   │   ├── maintenance-jutsu-v1/   # غرفة الصيانة، عناصر التصادم، وسجلات الإخراج
│   │   └── echo-parkour-v1/        # حركات الباركور و IK على هيكل إيكو
│   │
│   ├── audits/evidence/            # أدلة الفحص والتدقيق الملموسة (صور، سجلات JSON، بصمات التجزئة)
│   ├── docs/                       # وثائق الكانون، خطة الإنتاج، وبطاقة المتابعة:
│   │   ├── 11-11/START_HERE.md     # مدخل وثائق اللعبة والرؤية
│   │   ├── 11-11/design/           # تفويض المالك وسجل CONTINUATION.md
│   │   └── internal/production/    # بطاقة العمل CURRENT_WORK.ar.md وتقارير الجودة التفصيلية
│   │
│   ├── tools/                      # أدوات داخلية لتطبيق 11.11:
│   │   ├── animation-library/      # نصوص بايثون لحراسة وتصدير واختبار حركات Golden Reference
│   │   ├── project-doctor/         # نظام التشخيص الشامل والفحص المسبق/اللاحق
│   │   └── manhwa/                 # أدوات استيراد وفحص المانهوا
│   │
│   └── workers/                    # عمال Cloudflare السحابيون للبيانات والوقت الفعلي (Realtime)
│
├── FlaxMigration/                  # [أرشيف تاريخي معزول] تجربة نقل سابقة — لا تلمسه ومستثنى بالبحث
└── scratch/                        # [مسودة تجارب] ملفات مؤقتة ومخرجات تدقيق سريعة
```

---

## 3. قواعد العمل الصارمة والممنوعات (Invariants & Guardrails)

1. **المرجع الذهبي للتحريك (Golden Walk Reference):**
   - النسخة الموجودة في `artifacts/eleven-eleven/art/production/master-animation-library/golden/walk-v1/` مجمدة تماماً برقم بصمتها في `GoldenReference.json`.
   - **يُمنع منعاً باتاً:** إعادة توليد أو تحسين Walk، أو تعديل مفاتيح المصادر يدوياً، أو العبث بـ Skeleton Retarget أو Root Motion أو شجرة التحريك AnimationTree أثناء التحقق.
   - في حال حدوث أي خلل في نقل التحريك، استخدم مهارة `$echo-golden-animation` في `.agents/skills/echo-golden-animation/SKILL.md` فوراً وبحد أقصى محاولتين محسوبتين.

2. **سلطة اللعبة والجوائز (Server Authority & Canon):**
   - منطق الألغاز والقصة وشظايا الذاكرة (Memory Shards) والجوائز وسجل الإنجازات مملوكة للخادم ومحمية.
   - لا تمنح الجوائز أبداً من شيفرات العرض (Presentation Layer) أو نصوص التوليد.

3. **حماية المفاتيح والأمان (Security & Secrets):**
   - مفاتيح الخدمات (مثل مفتاح Higgsfield) تُحفظ فقط في `.env.local` المحمي بالقاعدة `.env.*` داخل `.gitignore`.
   - يُمنع طباعة المفاتيح، أو تمريرها في السجلات (Logs)، أو تضمينها في نصوص المحادثة أو مستودع Git.

4. **توفير استهلاك السياق (Context Optimization):**
   - المجلدات `FlaxMigration/` و `scratch/` و `.tmp/` و `node_modules/` مستثناة من البحث عبر `.rgignore`. لا تبحث داخلها إلا بطلب صريح ومحدد.
   - لا تقرأ سجل `CONTINUATION.md` بالكامل (يتجاوز 2000 سطر)؛ اقرأ فقط آخر نقطة متابعة (مثل `CP-20261001-01` أو سابقتها المباشرة).

---

## 4. مسارات التنفيذ المباشرة خطوة بخطوة

### أ. عند العمل على الذكاء الاصطناعي والوسائط السينمائية:
1. تحقق من المتغيرات في [`.env.local`](file:///c:/Users/yasmo/EchoNetwork/.env.local).
2. استخدم الكود الجاهز في [`index.ts`](file:///c:/Users/yasmo/EchoNetwork/index.ts) أو الأدوات في [`tools/higgsfield/`](file:///c:/Users/yasmo/EchoNetwork/tools/higgsfield/).
3. للتحقق من الاتصال دون استهلاك رصيد التوليد:
   ```bash
   npx tsx --env-file=.env.local tools/higgsfield/run-higgsfield.ts -- doctor
   ```
4. لتشغيل طلب التوليد الرسمي مع Seedance 2.5 عند التوجيه:
   ```bash
   npm run higgsfield:example
   ```

### ب. عند العمل على حركات وتحريك إيكو (Echo Animations):
1. افحص سلامة ملفات المرجع الذهبي (192 ملفاً):
   ```bash
   python artifacts/eleven-eleven/tools/animation-library/golden_reference.py
   ```
2. استخدم مسار النقل الصارم `single_motion.py` لكل حركة جديدة (بالتتابع: Run/Jog ثم Idle ثم Jump).
3. اختبر الحركة في Godot بدون تشغيل AnimationTree عبر `single_motion.gd`.

### ج. عند العمل على محرك Godot وأسلوب اللعب:
1. ادخل إلى مجلد `artifacts/eleven-eleven/godot/`.
2. المشهد الرئيسي للاعب: [`godot/scenes/player/echo_player.tscn`](file:///c:/Users/yasmo/EchoNetwork/artifacts/eleven-eleven/godot/scenes/player/echo_player.tscn).
3. منطق الحركة والتحكم: [`godot/scripts/player/echo_player.gd`](file:///c:/Users/yasmo/EchoNetwork/artifacts/eleven-eleven/godot/scripts/player/echo_player.gd).
4. تحكم اللمس للهاتف: [`godot/scripts/ui/mobile_touch_controls.gd`](file:///c:/Users/yasmo/EchoNetwork/artifacts/eleven-eleven/godot/scripts/ui/mobile_touch_controls.gd).
5. شغّل الفحص واختبارات Godot Headless:
   ```bash
   npm run godot:doctor
   npm run godot:smoke
   ```

### د. عند العمل على واجهة الويب أو الألغاز:
1. ادخل إلى `artifacts/eleven-eleven/src/`.
2. شغّل الفحص المسبق:
   ```bash
   npm run agent:preflight
   ```
3. أجرِ التعديلات وافحص عبر:
   ```bash
   npm run check
   ```

---

## 5. بروتوكول تسليم المهام وتحديث السجلات

بعد كل إنجاز فعلي مثبت:
1. **لا تعلن الإنجاز بمجرد كتابة الشيفرة؛** يجب تشغيل الفحوصات والتحقق من النتيجة.
2. أضف نقطة متابعة جديدة في [`artifacts/eleven-eleven/docs/internal/production/CURRENT_WORK.ar.md`](file:///c:/Users/yasmo/EchoNetwork/artifacts/eleven-eleven/docs/internal/production/CURRENT_WORK.ar.md) تشمل:
   - رقم النقطة وتاريخها.
   - الملفات التي أضيفت أو عُدلت بروابطها.
   - الفحوصات الفعلية التي نُفذت ونتائجها.
   - القيود والنواقص المتبقية.
   - الخطوة التالية بالضبط.
3. حدّث هذه الخريطة [`PROJECT_MAP.ar.md`](file:///c:/Users/yasmo/EchoNetwork/PROJECT_MAP.ar.md) فقط إذا تمت إضافة نظام جديد، أو أداة رئيسية، أو نقطة دخول جديدة.
