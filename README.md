# EchoNetwork / 11.11

لعبة أنمي نفسية سينمائية بهوية إيكو. Godot مسار اللعب الحالي؛ واجهة الويب وخدمات الحساب والحفظ القائمة محفوظة.

ابدأ من [خريطة المشروع](PROJECT_MAP.ar.md)، ثم [بطاقة العمل](artifacts/eleven-eleven/docs/internal/production/CURRENT_WORK.ar.md) و[الكاش](artifacts/eleven-eleven/docs/internal/production/CURRENT_CONTEXT_CACHE.json). [الخطة الشاملة والأدوات](artifacts/eleven-eleven/docs/internal/production/PRODUCTION_MASTER_2026-11-04.ar.md) هي مدخل الإنتاج الحالي.

| المسار | مسؤوليته |
|---|---|
| `artifacts/eleven-eleven/godot/` | اللعب والمشاهد والحركة والكاميرا والاختبارات |
| `artifacts/eleven-eleven/src/` | واجهة الويب ومنطقها |
| `artifacts/eleven-eleven/functions/` و`workers/` | الحساب والحفظ والإيصالات وسلطة الخادم |
| `artifacts/eleven-eleven/art/production/` | مصادر التأليف والأصول وGolden المحمي |
| `artifacts/eleven-eleven/docs/internal/narrative/current/ar/` | Canon ومراجعه |
| `artifacts/eleven-eleven/docs/internal/production/` | بطاقة وكاش وفهرس وخطة حالية؛ التاريخ فيarchive |
| `artifacts/eleven-eleven/audits/evidence/` | تقارير وأدلة مرتبطة بالمصادر |
| `tools/` | أدوات مشتركة؛ `tools/repository/` لفحص الشجرة |
| `FlaxMigration/` و`scratch/` | تجارب تاريخية محفوظة خارج المسار المعتاد |

التفصيل: [دليل الشجرة](docs/REPOSITORY_STRUCTURE.ar.md). مسارات الأصول والكانون وGolden لا تنقل اعتباطيًا؛ مراجع المشاهد والبصمات تعتمد عليها.

## التشغيل والفحوص

من الجذر:

```text
npm install
npm run dev
npm run godot:run
npm run repo:check
npm run agent:preflight
npm run agent:postflight
```

Godot المرصود `4.8.dev7.c971f93e7`؛ لا ترقية تلقائية أثناء تأهيل الأصول. أوامر Godot تحوي مسارات محلية تحتاج ضبطًا على جهاز آخر؛ المشروع `artifacts/eleven-eleven/godot/project.godot`. المصادر الثقيلة تستخدمGit LFS: نفّذ `git lfs install` و`git lfs pull` بعد الاستنساخ.

## المصدر والأدلة وحزم المراجعة

بيانات المستخدم والكاش وPython bytecode وحزم مراجعةEXE/PCK/APK ملفات مولدة محلية، وليست مصدرًا. مستبعدات تنظيف4نوفمبر محفوظة على القرص وبصماتها في سجل التنظيف. لا إعادة كتابة للتاريخ أو محو للأصول الفريدة. حزم التسليم المعتمدة توزع لاحقًا من مخزن إصدارات مع مصدر البناء والبصمة.

نجاح الفحوص البرمجية لا يثبت قبول الفن أو المتعة أو الصوت أو الأجهزة. لا يُعلن اكتمال فصل أو تفوق مقارن دون لعب ومراجعة وأداء مقاس.
