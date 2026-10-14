# شجرة العمل الحالية — 11.11 — 2026-10-14

**استؤنف التطوير بطلب المالك غرفةً غرفة — CP23 / CP-20261014-01.** الغرفة الأولى قيد الصقل مع V31 الحالي؛ أعمال CP21 المعزولة محفوظة ولم تدمج. الشجرة تحدد مكان العمل؛ لا تعتمد المراحل الثلاثين أو الجودة الفنية.

ابدأ ببطاقة `CURRENT_WORK.ar.md` في هذا المجلد، ثم صف الغرفة أو النظام أدناه. المسارات نسبية إلى `artifacts/eleven-eleven/` ما لم يذكر جذر المستودع.

```text
EchoNetwork/
├── PROJECT_MAP.ar.md                 ← المدخل الحالي المختصر
├── AGENTS.md                         ← تعليمات المستودع
├── run_game.bat                      ← تشغيل Godot المحلي
├── tools/ + lib/ + scripts/          ← أدوات المشروع والوسائط
├── scratch/                         ← تجارب وأعمال مساندة
├── FlaxMigration/                   ← تجربة محرك منفصلة، خارج اللعبة الحالية
└── artifacts/eleven-eleven/          ← التطبيق الفعلي
    ├── godot/
    │   ├── project.godot            ← boot.tscn
    │   ├── scenes/
    │   │   ├── boot.tscn            ← native_journey أو opening_web_room حسب المنصة
    │   │   ├── native_journey.tscn  ← المسار المحلي المتصل
    │   │   ├── environment/         ← غرف الفصل والممرات
    │   │   ├── player/              ← اللاعب والأسلحة والمقابس
    │   │   ├── characters/          ← غلاف V31 وكينجا
    │   │   └── cinematics/ + ui/ + effects/
    │   ├── scripts/
    │   │   ├── systems/             ← التقدم والحفظ وربط الغرف
    │   │   ├── environment/         ← التفاعل داخل الغرفة
    │   │   ├── player/ + combat/    ← الحركة والسلاح والقتال
    │   │   └── cinematics/ + ui/ + effects/
    │   ├── assets/                  ← المجسمات والخامات والحركات المستخدمة
    │   ├── shaders/                 ← الخامات والتأثيرات المتحركة
    │   └── tests/                   ← فحوص Godot
    ├── src/ + public/               ← الويب والقصة والمنشورات
    ├── functions/ + workers/        ← الخدمات والسلطة الخادمية
    ├── migrations/                 ← قاعدة البيانات
    ├── android/ + ios/ + src-tauri/ ← أغلفة المنصات
    ├── art/production/              ← مصادر الفن وBlender والحركات الأصلية
    ├── art/godot/                   ← مشاريع إثبات معزولة
    ├── docs/
    │   ├── project-memory.json      ← الذاكرة والمرحلة الحالية
    │   ├── internal/narrative/current/ar/manifest.json ← اختيار Canon
    │   └── internal/production/
    │       ├── CURRENT_WORK.ar.md   ← بطاقة واحدة للمتابعة
    │       ├── WORK_TREE.ar.md      ← هذه الشجرة
    │       ├── SOURCE_INDEX.json    ← المسارات الحالية وبصمات الملفات
    │       └── archive/             ← خرائط تاريخية
    ├── audits/evidence/             ← الأدلة حسب المهمة/checkpoint
    ├── tools/                       ← الفحص والتصدير والتحقق
    ├── .tmp/                        ← يحتوي أيضًا FBX مصادر، ليس كله قابلًا للحذف
    └── dist/                        ← نواتج بناء قابلة للتوليد
```

## مسار اللاعب: غرفة واحدة في كل مرة

وجود الغرفة والكود لا يعني قبول متعتها أو رسمها. عند استئناف التطوير، ابدأ بالغرفة الأولى وثبت الحركة وفهم المهمة والانتقال قبل الانتقال للغرفة التالية.

| الترتيب | الغرفة | المشهد في godot/scenes/environment/ | ملف التفاعل في godot/scripts/environment/ | الحالة |
|---|---|---|---|---|
| 01 | الافتتاح والاستيقاظ والأدلة | `opening_web_facility.tscn` تحت `opening_native_room.tscn` ثم `native_journey.tscn` | `main.gd` + `cinematics/prologue_orchestrator.gd` + `opening_atmosphere.gd` | CP23: فحص كاميرا وتأكيد/رجوع وخامة أثر؛ رحلة/VFX فعلية. النهوض وCanonالصورة والحركة الفنية والاعتماد مفتوحة |
| 02 | الصيانة والمسار المرتفع | `maintenance_vertical.tscn` | `maintenance_vertical.gd` | مراجعة CP20 موجودة؛ متعة المهمة والفن مفتوحان |
| 03 | نقطة الأمن | `security_checkpoint_room.tscn` | `security_checkpoint_room.gd` | طبقة مسح CP20 موجودة؛ جودة الغرفة مفتوحة |
| 04 | احتواء العينات | `specimen_containment_wing.tscn` | `specimen_containment_wing.gd` | القتال والفن والمتعة مفتوحة |
| 05 | أرشيف الذاكرة | `memory_archive_wing.tscn` | `memory_archive_wing.gd` | المهمة والإيقاع والفن مفتوحة |
| 06 | المفاعل | `core_reactor_room.tscn` | `core_reactor_room.gd` | اعتماد الفن واللعب مفتوح |
| 07 | التعقيم والحجر | `decontamination_quarantine_wing.tscn` | `decontamination_quarantine_wing.gd` | الاعتماد مفتوح |
| 08 | المرآة | `mirror_chamber_room.tscn` | `mirror_chamber_room.gd` | الاعتماد مفتوح |
| 09 | مختبر كينجا، الغرق، زيرو والعقد | `dr_kinja_lab_room.tscn` | `dr_kinja_lab_room.gd` | الشخصيات موجودة؛ المواجهة والتوقيت والحركات مفتوحة |
| 10 | المستشفى | `hospital_bedside_room.tscn` | `hospital_bedside_room.gd` | المسار موجود؛ الاعتماد مفتوح |

مالكا التسلسل في `godot/scripts/systems/`: `native_journey_controller.gd` للافتتاح→الصيانة→الأمن، ثم `native_campaign_controller.gd` للعينات→الأرشيف→المفاعل→التعقيم→المرآة→المختبر→المستشفى. ملفات `*_conduit.tscn` هي الممرات. الحفظ في `native_journey_checkpoint.gd` و`native_campaign_checkpoint.gd`؛ سلطة المكافآت في الخدمات الأصلية.

الغرفة الأولى المستقلة `opening_room.tscn`/`opening_room.gd` محفوظة، لكنها ليست مدخل اللعبة الفعلي. CP22 يربط الأدلة والصوت وموجة الاكتشاف وخط الطاقة ومسح الزجاج بالرحلة القائمة؛ لا ينشئ مسار تقدم آخر.

## الشخصية والسلاح والعرض الحالي

| العنصر | مدخل العمل الصحيح | ما يزال مفتوحًا |
|---|---|---|
| Echo المعتمد | `godot/scenes/player/echo_player.tscn` → `godot/scenes/characters/echo_v31_adopted.tscn` → `godot/assets/characters/echo_v31_adopted_high.glb` | V31 High هو اللاعب الحالي؛ نسخ v1…v13 تاريخية |
| حركة V31 | `godot/assets/animations/v31/` + `godot/scripts/player/echo_v31_motion_adapter.gd` | Idle/Run/Jump من CP17؛ WALK مؤقتًا Run بطيء؛ هجوم/roll/wake غير مقبولة |
| مصدر الشخصية | `art/production/echo-tripo-hd-v31-8k/` | الوجه والقبضة واعتماد العباءة مفتوحة |
| السلاحان والغمد | `godot/assets/weapons/` + `godot/scripts/player/tripo_weapon_visuals.gd` | نماذج Tripo موجودة؛ المقابس تفتحها بعد فتح القتال |
| كينجا | `godot/scenes/characters/dr_kinga.tscn` → `godot/assets/characters/kinja_revenge_rig_v1.glb` | موجود في المختبر؛ جودة المواجهة مفتوحة |
| زيرو | `godot/assets/characters/zero_manifestation_profile_v1.json` → `zero_manifestation_idle_v1.glb` + `godot/assets/animations/zero/` | موجود؛ اختيار العقد الصريح شرط القوة |
| الحوار | `godot/scripts/ui/dialogue_overlay.gd` + `system_window.gd` | الكلام والتلاشي يُراجعان داخل الغرفة الفعلية |
| الكاميرا والمؤثرات | `godot/scripts/player/echo_player.gd`، `godot/scripts/cinematics/`، `godot/scripts/effects/`، `godot/shaders/` | فحص اللعب والأداء؛ SFX_ONLY بلا موسيقى |

## اختيار دليل المراجعة

- **CP20**: `audits/evidence/chapter-execution-20261009/cp20-v31-integration/final-verification.json` يصف دمج المراجعة. أحدث حزمة مراجعة محفوظة `EchoNetwork-CP20-reviewed.exe/.pck` في المجلد نفسه؛ لا قبول نهائي للفصل.
- **CP22**: `audits/evidence/room01-20261012/`؛ تشغيل جديد للغرفة الأولى، محاذاة Run الحي مع الكبسولة، مؤثرات اكتشاف/طاقة/زجاج وصوت مكاني. التفاصيل والفحوص الحالية في `ROOM01_EXECUTION_2026-10-12.ar.md`؛ لا إغلاق للغرفة أو مرحلة من الفحص الوظيفي وحده.
- **CP21 — PAUSED / NOT_INTEGRATED**: `audits/evidence/chapter-execution-20261009/cp21-v31-walk/`. تشخيص Walk واتصال القدم وRoot Motion محفوظ؛ لا يبدل المكتبات الحالية.
- **CP17**: مرجع High/Balanced والحركات المعزولة فقط؛ صوره ليست دليلًا على غرفة اليوم.
- **CP18/CP19 وما قبلها**: سياق تاريخي. الصور وتقارير الوكلاء القديمة تحفظ للتشخيص، ولا تتحول إلى قبول للمشهد الحالي.
- **Golden**: `art/production/master-animation-library/golden/walk-v1/`؛ يحمي 192 ملفًا تشمل FBX تحت `.tmp/master-animation-library/sources/`. لا حذف أو إعادة ختم.
- **التنظيف**: `audits/evidence/project-cleanup-20261012/`؛ سجل الحذف والاسترجاع والبصمات والفحوص.

قبل الاستناد إلى صورة، طابق المشهد والأصل وبصماتهما في `SOURCE_INDEX.json` وبيّن نسخة المراجعة. إذا تعذر الربط، الحالة `UNVERIFIED` وتؤخذ لقطة تشغيل جديدة عند استئناف المهمة. فحص التنظيف لا يتضمن مراجعة فنية جديدة للغرف.

## الاستمرار وحدود التنظيف

حُذفت caches معزولة وbytecode غير متتبعة وشجرة أدلة فارغة أُنشئت خطأ في جذر المستودع. مسارات `res://` محفوظة. الصور الفريدة والمصادر والتعديلات السابقة محفوظة، وكذلك كاش المشروع الفعلي. كاش المراجعات يعاد بـGodot import؛ `.blend1` المختلفة عن الأصل نسخ استرجاع، ليست مكررات مثبتة.

الخطة: `CHAPTER_PLAYABILITY_MASTER_PLAN_2026-10-09.ar.md` في هذا المجلد. المرحلة PART_3 ثابتة؛ دمج 07 غير نهائي، و06 والحركة والفن واللعب والأجهزة مفتوحة. الأفقي إلزامي؛ الهاتف مؤجل بطلب المالك. التنفيذ فردي مستأنف: الغرفة 01 مع V31 الحقيقي ثم 02 وباقي المسار بالتتابع بعد أبواب القبول.

## نظام فحص الغرفة01 — CP23

`godot/scripts/cinematics/opening_inspection.gd` مع `opening_evidence.gd` و`native_pause_menu.gd` و`main.gd`؛ الخامة في `godot/assets/textures/opening/` وأصلها في `art/production/room01-20261014/`. الفحوص `opening_inspection_review.gd` و`opening_player_journey_review.gd`. الدليل الحالي `audits/evidence/room01-20261014/verification.json`؛ تقرير `ROOM01_EXECUTION_2026-10-14.ar.md`.
