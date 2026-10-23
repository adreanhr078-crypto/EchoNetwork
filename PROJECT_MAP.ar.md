> **23 أكتوبر2026 — خطة بناء الإصدار:** تحليل آخر خطة (14 بوابة) وسجل الفجوات ومسار R0→R5/C1→C5 لوصول اللعبة إلى التنزيل: `artifacts/eleven-eleven/docs/internal/production/RELEASE_BUILD_PLAN_2026-10-23.ar.md`، والتدقيق الآلي `artifacts/eleven-eleven/audits/release-readiness-20261023/baseline.json`. لا تغيير runtime ولا إغلاق بوابة.

---
> **الأحدث CP36 / 17 أكتوبر2026:** تقييمTripoمحدود؛ H2.5GLB2KاستيرادساكنPASS، P2تمثيل/تصديرمحليOPEN. ابدأCURRENT_WORKثمCURRENT_CONTEXT_CACHE.json؛ لا إعادة قراءة المحادثة كاملة.

---
> **الأحدث CP35 / 16 أكتوبر 2026:** تجربة Tripo جزئية؛ خامة وهيكل P2 اكتملتا، آخر رصيد160، لا تنزيل أو دمج. استكمال فحص الميزات متعثر باتصال المتصفح؛ راجع CURRENT_WORK ثم TRIPO_FEATURE_EVALUATION_CP35_2026-10-16.ar.md. آخر runtime مؤهل CP34.

---

> **الأحدث CP34 / 16أكتوبر2026:** دراسة14مستودعًا وتحسين محدود لخامة كينجا، وحزمة43حركةCC0 معزولة. ابدأCURRENT_WORK ثمCHAPTER_EXECUTION_CP34_2026-10-16.ar.md وverification-cp34.json. لا استبدال شخصية بعد، والفصل/الفن/الأجهزة OPEN؛ ما يلي تاريخي.

---

> **الأحدث CP33 / 16أكتوبر2026:** إصلاح حجب جسم إيكو بكاميرا الانتقام مؤهل في مساري مختبر متصلين من المصدر النهائي. ابدأCURRENT_WORK ثمCHAPTER_EXECUTION_CP33_2026-10-16.ar.md وverification-cp33.json. الفن والتمثيل والمدخل الموثوق والأجهزة والفصلOPEN؛ ما يلي تاريخي.

---

> **الأحدث CP32 / 16 أكتوبر2026:** خطة الجودة المعتمدة قيد التنفيذ؛ المرآة واستعادة المختبر والمسار04→المستشفى مثبتة وظيفيًا بالنطاق المحدد. عودة كاميرا الانتقام FAIL بصريًا وتليها معالجة أداء المختبر؛ مدخل الغلاف native والأجهزة OPEN. ابدأ CURRENT_WORK ثم CHAPTER_EXECUTION_CP32_2026-10-16.ar.md وverification-cp32.json. ما يلي تاريخي.

> **الأحدث CP30 / IN_PROGRESS:** أذن المالك بإكمال08؛ أصلحتعقودالمرآة/البوابة الصغيرة. المصدرومساراالتحققوالدليل فيCURRENT_WORK وROOM08_EXECUTION_2026-10-15.ar.md. تمريرةفن08واستشارةHighالجديدة متعثرةبإرسالالمتصفح؛09لمتعدل. ما يلي تاريخي.

> **الأحدث CP29:** تمريرة بصريات 01–07 ومراجعة أرجون والرحلتان الفعليتان؛ 08 لم تبدأ. البطاقة والتقرير والفهرس الحالي سلطة الحالة؛ الأداء والشخصية والأجهزة OPEN.

> **الأحدث CP28 / CP-20261015-03:** تمريرة مؤثرات07 قوية ومراجعةمصادرArgon، إصلاحRMالحي في06، عبورUV/السلم/التجاوزPASS؛ الفن والأداءوالأجهزةمفتوحة، و08لمتعدل. التقرير ROOM07_VFX_EXECUTION_2026-10-15.ar.md والبطاقة والفهرس سلطةالحالة.




# خريطة العمل الحالية — EchoNetwork / 11.11

**2026-10-14: استأنف المالك التنفيذ غرفةً غرفة؛ الغرفة 01 قيد الصقل — CP23 / CP-20261014-01.** Echo V31 High هو اللاعب الفعلي. CP21 المعزول محفوظ وغير مدمج؛ إصلاح CP22 يخص محاذاة عرض Run مع كبسولة اللاعب، وليس قبول Walk أو النهوض. المرحلة PART_3 ثابتة؛ المراحل الثلاثون لم تعتمد.

## ابدأ هنا

1. اقرأ `AGENTS.md` ثم `artifacts/eleven-eleven/AGENT_RULES.md`.
2. اقرأ بطاقة واحدة: `artifacts/eleven-eleven/docs/internal/production/CURRENT_WORK.ar.md`.
3. اختر الغرفة/النظام من `artifacts/eleven-eleven/docs/internal/production/WORK_TREE.ar.md`؛ فهرس البصمات `SOURCE_INDEX.json` في المجلد نفسه.
4. افتح الملفات الخاصة بتلك المهمة فقط. الخطة المعتمدة `CHAPTER_PLAYABILITY_MASTER_PLAN_2026-10-09.ar.md`، وCanon من `docs/internal/narrative/current/ar/manifest.json` داخل التطبيق.

## الشجرة المختصرة

```text
EchoNetwork/
├── PROJECT_MAP.ar.md                       ← هذا المدخل
├── AGENTS.md + run_game.bat                 ← تعليمات وتشغيل
├── tools/ + lib/ + scripts/                 ← أدوات المشروع
├── scratch/                                ← أعمال تجريبية مساندة
├── FlaxMigration/                          ← تجربة منفصلة، خارج runtime الحالي
└── artifacts/eleven-eleven/                 ← التطبيق الفعلي
    ├── godot/{scenes,scripts,assets,shaders,tests}
    ├── src/ + public/                      ← الويب والمنشورات
    ├── functions/ + workers/ + migrations/ ← الخدمات والتقدم الموثوق
    ├── android/ + ios/ + src-tauri/         ← أغلفة المنصات
    ├── art/production/                     ← المصادر الأصلية والفن
    ├── docs/internal/production/           ← البطاقة والشجرة والخطة
    ├── audits/evidence/                    ← أدلة مفصولة حسب المهمة
    └── .tmp/ + dist/                       ← مصادر مؤقتة أيضًا / نواتج بناء
```

## مدخل كل نظام

المسارات التالية نسبية إلى `artifacts/eleven-eleven/`.

| المهمة | المدخل الصحيح |
|---|---|
| تشغيل native | `godot/project.godot` → `scenes/boot.tscn` → `scenes/native_journey.tscn` |
| الافتتاح والصيانة والأمن | `godot/scripts/systems/native_journey_controller.gd`؛ اختر الغرفة من WORK_TREE |
| بقية غرف الفصل والمستشفى | `godot/scripts/systems/native_campaign_controller.gd` |
| Echo المعتمد | `godot/scenes/player/echo_player.tscn` → `scenes/characters/echo_v31_adopted.tscn` |
| حركة V31 | `godot/scripts/player/echo_v31_motion_adapter.gd` + `godot/assets/animations/v31/` |
| السلاح والقتال | `godot/scripts/player/tripo_weapon_visuals.gd` + `godot/scripts/combat/` |
| كينجا وزيرو والعقد | `godot/scripts/environment/dr_kinja_lab_room.gd` + `godot/scripts/cinematics/pact_revenge_presentation.gd` |
| الكلام والتلاشي | `godot/scripts/ui/dialogue_overlay.gd` و`system_window.gd` |
| الكاميرا وVFX/SFX | `godot/scripts/player/`، `scripts/cinematics/`، `scripts/effects/`، `shaders/`؛ بلا موسيقى |
| الويب والخدمات | `src/`، `functions/`، `workers/realtime/`؛ منفصلة عن Godot |
| المرجع المحمي | `art/production/master-animation-library/golden/walk-v1/` |
| جودة المشروع | `npm run agent:preflight` قبل التعديل، `npm run agent:postflight` بعده من جذر المستودع |

## قواعد الأدلة والتنظيف

CP20 في `audits/evidence/chapter-execution-20261009/cp20-v31-integration/` يصف آخر دمج مراجعة. CP21 في `cp21-v31-walk/` تشخيص معزول لم يبدل اللاعب. صور CP17 والحركات المعزولة، وصور CP18/CP19/الإصدارات السابقة، محددة بتاريخها ونسختها؛ ليست قبولًا للغرفة الحالية. طابق المسار والبصمة قبل أي حكم بصري، وإلا الحالة UNVERIFIED.

حُذف كاش المراجعات القابل لإعادة التوليد وشجرة أدلة فارغة خاطئة فقط. مصادر الفن وFBX وGolden والصور الفريدة والعمل السابق محفوظة. **لا تحذف `.tmp/` جملةً**: تحتوي `.tmp/master-animation-library/sources/` المطلوبة. مسارات `res://` وترتيب ملفات runtime محفوظان.

سجل التنظيف والتحقق في `audits/evidence/project-cleanup-20261012/`. الخريطة القديمة كاملة في `docs/internal/production/archive/PROJECT_MAP_history_to_2026-10-12.ar.md`؛ افتحها فقط لسؤال تاريخي. `.tmp-tripo-godot-bridge-inspect/` في جذر المستودع مرجع plugin متتبع تاريخي؛ ليس مصدر اللاعب.

العمل الحالي: **الغرفة الأولى مع V31 الحالي، ثم الثانية بعد قبول الأولى، ثم باقي المسار**. مدخل الافتتاح الفعلي `opening_web_facility.tscn` تحت `opening_native_room`/`native_journey`؛ `opening_room.tscn` مستقل ولا يملك هذه الرحلة. تُراجع الحركة والتفاعل والكاميرا والتأثيرات ضمن الغرفة، والقتال حيث يسمح التسلسل. الهاتف مؤجل، والأفقي إلزامي، والعمل فردي.

## فحص الغرفة01 الحالي — CP23

`godot/scripts/cinematics/opening_inspection.gd` يستعمل الكاميرا نفسها والدليل السابق بتأكيد/رجوع؛ أصل خامةFlow في `art/production/room01-20261014/`. الأدلة الحالية `audits/evidence/room01-20261014/verification.json` والتقرير `docs/internal/production/ROOM01_EXECUTION_2026-10-14.ar.md` داخل التطبيق. الغرفة01 و30مرحلة OPEN.
