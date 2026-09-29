# خريطة المشروع — EchoNetwork / 11.11

## ابدأ من هنا

| المكان | دوره |
| --- | --- |
| `AGENTS.md` | قواعد العمل وحفظ التقدم |
| `artifacts/eleven-eleven/docs/internal/production/CURRENT_WORK.ar.md` | بطاقة متابعة قصيرة: آخر تنفيذ مثبت، الملفات المعنية، النواقص والخطوة التالية |
| `artifacts/eleven-eleven/docs/11-11/START_HERE.md` | نقطة الدخول إلى وثائق اللعبة |
| `artifacts/eleven-eleven/docs/11-11/design/CONTINUATION.md` | آخر ما نُفّذ واختُبر وحدوده |
| `artifacts/eleven-eleven/docs/PROJECT_VISION.md` | الرؤية المعتمدة |
| `artifacts/eleven-eleven/docs/internal/narrative/current/ar/manifest.json` | مراجع الكانون |

## مسارات التنفيذ

- اللعبة ثلاثية الأبعاد: `artifacts/eleven-eleven/godot/`؛ المشاهد في `scenes/`، الشيفرة في `scripts/`، الأصول في `assets/`، اختبارات Godot في `tests/`.
- واجهة الويب والخدمات القائمة: `artifacts/eleven-eleven/src/` و`functions/` و`workers/`. وجود افتتاح Godot مرشح لا يعني قبول الانتقال إليه في الويب.
- فحوص المشروع: `artifacts/eleven-eleven/tools/project-doctor/`.
- بناء افتتاح Windows وAndroid التجريبي: `artifacts/eleven-eleven/tools/build-godot-native.ps1`؛ متطلبات البناء وحدود القبول في `docs/internal/production/NATIVE_BUILD_AND_BATCH2_2026-09-28.ar.md` داخل التطبيق.
- الأدلة والتدقيق: `artifacts/eleven-eleven/audits/`؛ تقارير الإنتاج في `docs/internal/production/`.
- مراجعة صورة الافتتاح وإصلاحات الدفعة الثالثة: `artifacts/eleven-eleven/docs/internal/production/OPENING_VISUAL_BATCH3_2026-09-28.ar.md`؛ دراسة الإضاءة المولدة وسجلها في `art/production/opening-lighting-study/` داخل التطبيق، وهي مرجع فني خارج تشغيل اللعبة.

## أرشيف التجارب

`FlaxMigration/` تجربة نقل قديمة، وليست مصدر تشغيل Godot. حُفظت ملفاتها الفريدة والتقارير، وحُذفت النسخ المتطابقة فقط. ملفات `scratch/` تجارب وأدلة يُرجع إليها عند الحاجة. تستثني `.rgignore` هذه المسارات من البحث المعتاد؛ يمكن قراءتها بالمسار الصريح أو البحث مع `--no-ignore`.

ابدأ البحث داخل مجلد النظام المعني، ثم وسّعه عند الحاجة. لا حاجة لقراءة جميع الأصول أو التقارير كل مرة، ولا تُحذف نسخة فريدة لمجرد قدمها.

## الحفاظ على الخريطة عند الإضافة

1. اقرأ بطاقة المتابعة ثم آخر نقطة متابعة ذات صلة؛ السجل الكامل مرجع تاريخي عند الحاجة.
2. حافظ على قراءة القواعد والذاكرة ومراجع الكانون الإلزامية، ثم افتح ملفات المهمة فقط.
3. ضع شيفرة Godot في `godot/scripts/<system>/`، والمشاهد في `godot/scenes/`، واختباراتها في `godot/tests/` داخل التطبيق. استخدم مجلد النظام الموجود أولاً.
4. ضع مصادر الإنتاج القابلة للتحرير وسجل التوليد في `art/production/<asset-or-task>/`، والأصول المستخدمة فعلياً في `godot/assets/`، والصور الداعمة في `audits/evidence/`.
5. ضع التقرير المفصل في `docs/internal/production/` واربطه من بطاقة المتابعة. لا تنسخ التقرير أو التاريخ الكامل إلى البطاقة.
6. الملفات المؤقتة ومخرجات البناء تبقى في `.tmp/` المتجاهل. لا تضع مفاتيح الخدمات داخل المشروع.
7. حدّث الخريطة عند إضافة نظام أو نقطة دخول، وحدّث البطاقة ونقطة المتابعة بعد كل تسليم فعلي. تحقق من وجود الروابط؛ حالة الوثيقة لا تثبت اكتمال الميزة.

## مراجع الافتتاح الحالية

داخل `artifacts/eleven-eleven/`:

- `godot/scripts/player/echo_player.gd`: حركة Echo والتحريك وربط التحكم.
- `godot/scripts/player/player_traversal_controller.gd`: أساس التسلق والسباحة؛ وجوده لا يثبت قابلية التسلق للاعب.
- `godot/scenes/system_journey_preview.tscn`: نموذج صيانة اختياري متصل بنهاية الافتتاح؛ ليس قبولاً للرحلة الكاملة.
- `godot/scripts/player/surface_traversal_motor.gd`: تسلق وتعلق وصعود حافة بفحص كبسولة اللاعب.
- `godot/scripts/systems/system_journey_preview.gd`: مراحل الصيانة وحفظ الاستراحة المستقل.
- `art/production/maintenance-jutsu-v1/` و`art/production/echo-parkour-v1/`: مصادر الغرفة والتحريك القابلة للتحرير؛ أصول التشغيل في `godot/assets/`.
- `docs/internal/production/JUTSU_MAINTENANCE_2026-09-29.ar.md`: أحدث تنفيذ ودليل وحدود معيار الجودة.
- `godot/scripts/main.gd`: تدفق الغرفة والحوارات والحدود الحالية.
- `docs/internal/production/JUTSU_SIGNAL_CONSOLE_2026-09-28.ar.md`: دمج محطة الافتتاح المثبت سابقاً.
- `docs/internal/production/OPENING_PLAYABILITY_2026-09-28.ar.md`: عيوب اللعب وأدلتها.
- `docs/internal/production/GODOT_SYSTEM_EXECUTION_2026-09-28.ar.md`: سجل الدفعات السابق؛ توجيهات المالك اللاحقة تُوثّق قبل تحديثه.

## سجل ترتيب 2026-09-28

حُذف **880 ملفاً متطابقاً** من `FlaxMigration/SourceAssets/`، بحجم **1,396,160,145 بايت** (حوالي 1.30 GiB). بقيت **56 نسخة فريدة** في هذا المجلد. يربط سجل التنظيف كل ملف محذوف بأصله المحفوظ وبصمة SHA-256:

`artifacts/eleven-eleven/docs/internal/production/2026-09-28-cleanup-manifest.json`

النسخة الاحتياطية خارج المستودع مسجلة داخله؛ ويمكن أيضاً استرجاع النسخ من التزام Git المذكور فيه. لم تُحذف أصول اللعبة الفريدة أو تقارير الكانون أو ملفات التشغيل المستعملة.
