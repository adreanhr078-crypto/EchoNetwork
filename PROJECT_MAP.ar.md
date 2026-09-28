# خريطة المشروع — EchoNetwork / 11.11

## ابدأ من هنا

| المكان | دوره |
| --- | --- |
| `AGENTS.md` | قواعد العمل وحفظ التقدم |
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

## سجل ترتيب 2026-09-28

حُذف **880 ملفاً متطابقاً** من `FlaxMigration/SourceAssets/`، بحجم **1,396,160,145 بايت** (حوالي 1.30 GiB). بقيت **56 نسخة فريدة** في هذا المجلد. يربط سجل التنظيف كل ملف محذوف بأصله المحفوظ وبصمة SHA-256:

`artifacts/eleven-eleven/docs/internal/production/2026-09-28-cleanup-manifest.json`

النسخة الاحتياطية خارج المستودع مسجلة داخله؛ ويمكن أيضاً استرجاع النسخ من التزام Git المذكور فيه. لم تُحذف أصول اللعبة الفريدة أو تقارير الكانون أو ملفات التشغيل المستعملة.
