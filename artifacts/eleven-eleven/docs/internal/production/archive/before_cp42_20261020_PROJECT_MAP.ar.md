# خريطة المشروع — 11.11 / EchoNetwork

الحالة الحالية: **CP41 / 20 أكتوبر2026 — نواة Hyper Anime مدمجة، الفصل قيد التنفيذ**. رحلة Godot المحلية01→10 مرسومة ومختبرة؛ أداء الشخصيات، الصوت الياباني، المدخل الحي، الفن والمتعة والأجهزة ليست معتمدة. لا تنقل ملفات runtime ولا تعتمد تاريخ الصور وحده.

## مسار القراءة الاقتصادي

`AGENTS.md` → بطاقة `artifacts/eleven-eleven/docs/internal/production/CURRENT_WORK.ar.md` → `CURRENT_CONTEXT_CACHE.json` → صف النظام في `WORK_TREE.ar.md` → المقطع المتغير فقط. عند بدء مهمة جديدة اقرأ تعليماتها الإلزامية مرة واحدة. لا تقرأ سجل المحادثة أو CONTINUATION كاملًا عند كل تعديل.

## الشجرة

```text
EchoNetwork/
├── AGENTS.md + PROJECT_MAP.ar.md         التعليمات ومدخل واحد للخريطة
├── tools/ + lib/ + scripts/              أدوات الجذر
├── scratch/ + FlaxMigration/             تجارب؛ خارج runtime الحالي
└── artifacts/eleven-eleven/              التطبيق الفعلي
    ├── godot/
    │   ├── scenes/                      المشاهد الفعلية
    │   ├── scripts/{systems,environment,cinematics,player,ui}
    │   ├── engine_visuals/              البيئة/المواد/الكاميرا/المؤثرات الدائمة
    │   ├── assets/ + shaders/           الأصول والمؤثرات
    │   └── tests/                       فحوص Godot؛ ليست حالة لعب جاهزة
    ├── src/ + public/                   الويب والمحتوى المنشور
    ├── functions/api/player/            سلطة الحساب والإيصالات
    ├── migrations/ + workers/           قواعد البيانات والخدمات
    ├── android/ + ios/ + src-tauri/      أغلفة المنصات
    ├── art/production/                  المصادر الأصلية وGolden المحمي
    ├── docs/internal/production/        البطاقة والشجرة والفهرس والخطة
    │   └── archive/                     تاريخ محفوظ؛ لا يبدأ منه الاستئناف
    ├── audits/evidence/                 أدلة مؤرخة ومربوطة ببصمات
    └── .tmp/ + dist/                    مصادر وسيطة ونواتج؛ لا حذف شامل
```

## العقود الثابتة

Godot للعب؛ الويب والخادم للحساب والإيصالات. اللاعب Echo V31 High؛ CP21 معزول. Golden Walk وCanon وPART_3 وSFX_ONLY محفوظة. الخطة `CHAPTER_QUALITY_EXECUTION_PLAN_2026-10-16.ar.md` مع خطة الثلاثين مرحلة. لا قدرة قبل العقد الصريح، ولا إيصال حساب من حفظ محلي. الهاتف مرحلة لاحقة.

تعريف الأنظمة والغرف والاختبارات في `WORK_TREE.ar.md`، والبصمات في `SOURCE_INDEX.json`. التحقق العام من الجذر: `npm run agent:preflight` ثم `npm run agent:postflight`، والفحوص المتأثرة مرة أخرى عند تعديلها. تاريخ الخريطة قبل CP37 محفوظ في `archive/before_cp37_20261018_PROJECT_MAP.ar.md` داخل production. لا تحذف `.tmp/` أو أصولًا فريدة لتوفير السياق.

CP38: مستشفى بأثاث مرجعي مؤهل وصور حالية؛ مسار341/حفظ24/حزمة22/Golden192/postflight649. التمثيل والجودة الكلية OPEN. اشتراكTripo متاح2945بعد90كريديت؛ KinjaP2معزول. التفاصيل والبوابة التالية فيCURRENT_WORK.


CP39 الحالي: واجهة شخصية تتابع إيكو بلا حجب التحكم؛ I للحالة، مهام من حفظ ناجح، طابور32/صور26/مسار340/حزمة28/postflight649/Golden192. مصادر الحركات الجديدة معزولة في art/production/echo-tripo-cp39-20261019؛ لا استبدال V31، آخر رصيد2875. البطاقة الحالية هي مرجع البوابة التالية.

CP41 الحالي: مهارة Hyper Anime دائمة +5محاور النواة في godot/engine_visuals؛35Forward+/35Compatibility/19مشهد/19مستشفى/340مسار/31حزمة،Golden192/postflight649. الأداء العالي والفن وmantle مستقل ما زالت OPEN؛ البطاقة والفهرس هما مرجع الاستئناف. أرقام رصيد Tripo في الفقرات السابقة تاريخية وتحتاج فحصًا حيًا قبل الإنفاق.
