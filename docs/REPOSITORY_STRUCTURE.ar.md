# دليل شجرة EchoNetwork

المشروع الحالي `artifacts/eleven-eleven/`. تنظيم المداخل وسياسة الملفات يحافظ على مسارات المشاهد والتقارير وGolden؛ لا يعيد تسمية آلاف الملفات اعتباطيًا.

```text
EchoNetwork/
├─ README.md + PROJECT_MAP.ar.md       البداية وخريطة المصدر
├─ AGENTS.md                          قواعد العمل
├─ docs/                              دليل المستودع
├─ tools/repository/                  جرد وفحص الشجرة، بلا حذف
├─ artifacts/eleven-eleven/
│  ├─ godot/scripts/                  player / systems / ui / cinematics / environment
│  ├─ godot/engine_visuals/           الرسم والكاميرا والمؤثرات الحالية
│  ├─ godot/scenes/ + assets/         مشاهد ومشتقات تشغيل مؤهلة
│  ├─ godot/tests/                    اختبارات وتأهيل Godot
│  ├─ src/                           واجهة الويب
│  ├─ functions/ + workers/          الحساب والحفظ وسلطة الخادم
│  ├─ art/production/                مصادر ومشتقات تأليف وGolden
│  ├─ docs/internal/narrative/current/ar/  Canon
│  ├─ docs/internal/production/       بطاقة وكاش وفهرس وخطة حالية وarchive
│  ├─ tools/                         مختبرات الشخصية والحركة
│  └─ audits/evidence/               تقارير ولقطات وأدلة التأهيل
├─ FlaxMigration/                     تجربة محرك قديمة محفوظة
└─ scratch/                           تجارب تاريخية محفوظة
```

## سياسة الملفات

1. كل مهمة تبدأ من البطاقة والكاش وبصمة المصدر. البحث داخل النظام المتأثر أولًا؛ الأرشيف يفتح بالمسار الصريح عند الحاجة.
2. أصل مؤلف، ومشتق قابل للتتبع، وتقرير تأهيل يذكر الاثنين. لا نسخ كاملة للشخصية أو المصدر لتغيير تأثير فقط.
3. `art/production` مصادر فنية، و`godot/assets` مشتقات التشغيل، و`audits/evidence` دليل. ملفات الجلسة المؤقتة الجديدة في `.tmp` المستبعدة.
4. حزم المراجعةEXE/PCK/APK محلية أو في مخزن إصدارات. سجل التنظيف يحفظ SHA256 والحجم والمسار؛ إعادة بناء مطابقة تحتاج أيضًا نسخة الأدوات وإعداداتها، ولا تُفترض من وجود المصدر.
5. الصور والفيديو وBLEND/GLB الفريدة وتقارير الفشل وCanon وGolden لا تُحذف لمجرد كثرتها. لم يُعد كتابة تاريخGit/LFS ولا تُدّعى استعادة مساحته بهذا التنظيف.
6. لا تجاهل شامل لـaudits أوJSON أوlog: منها أدلة ضرورية. ملفاتuid وimport المقصودة محفوظة؛ تختلف عن كاش.godot.
7. `npm run repo:check` يفحص الفهرس قبل الالتزام. لا أسرار أوenv أو بيانات حسابات؛ الأمثلة خالية من القيم.
8. نجاحcommit لا يثبت الرفع: يجب إتمامLFS ومطابقةSHAالمحلي معorigin/main.

## المداخل الحالية

داخل `artifacts/eleven-eleven/docs/internal/production/`:

| المطلوب | الملف |
|---|---|
| الخطة والدراسات والأدوات | PRODUCTION_MASTER_2026-11-04.ar.md |
| الوضع الفعلي والبوابة التالية | CURRENT_WORK.ar.md ثمCURRENT_CONTEXT_CACHE.json |
| ربط المصدر بالدليل | SOURCE_INDEX.json وCURRENT_CONTEXT_SOURCE_HASHES.json |
| كل غرفة ونظام | WORK_TREE.ar.md |
| ما استُبعد بالتنظيف | REPOSITORY_CLEANUP_2026-11-04.json |

كل المستبعدات تبقى على القرص. لا يُعلن أن الشجرة بلا عمل محلي إلا بعد فحصGitالحالي؛الأعداد والأحجام ليست معيارًا لجودة اللعبة.
