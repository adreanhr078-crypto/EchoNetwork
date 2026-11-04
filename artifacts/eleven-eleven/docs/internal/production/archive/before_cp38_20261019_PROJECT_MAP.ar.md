# خريطة المشروع — 11.11 / EchoNetwork

الحالة الحالية: **CP37 / 18 أكتوبر2026 — الفصل قيد التنفيذ**. رحلة Godot المحلية01→10 مرسومة ومختبرة؛ أداء الشخصيات، الصوت الياباني، المدخل الحي، الفن والمتعة والأجهزة ليست معتمدة. لا تنقل ملفات runtime ولا تعتمد تاريخ الصور وحده.

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
