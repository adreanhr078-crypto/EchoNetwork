# EchoNetwork / 11.11

لعبة بهوية Echo: رعب نفسي وغموض هادئ، ومهام متسلسلة تستند إلى المانهوا.
Godot هو مسار التطوير المعتمد للعبة ثلاثية الأبعاد. واجهة الويب وخدمات الحساب القائمة في المشروع محفوظة.

## خريطة سريعة

ابدأ بـ [خريطة المشروع](PROJECT_MAP.ar.md)، ثم [نقطة الدخول](artifacts/eleven-eleven/docs/11-11/START_HERE.md) و[سجل الاستمرار](artifacts/eleven-eleven/docs/11-11/design/CONTINUATION.md).

| المسار | المحتوى |
| --- | --- |
| `artifacts/eleven-eleven/godot/` | مشاهد Godot والشخصيات والتحريك والاختبارات |
| `artifacts/eleven-eleven/src/` | واجهة الويب ومنطق التطبيق |
| `artifacts/eleven-eleven/functions/` و`workers/` | خدمات المشروع |
| `artifacts/eleven-eleven/docs/` | الكانون والرؤية وخطط الإنتاج |
| `artifacts/eleven-eleven/audits/` | العيوب وأدلة الاختبار |
| `FlaxMigration/` | أرشيف تجربة نقل قديمة؛ انظر README داخله |

## تشغيل الويب وفحوصه

من `artifacts/eleven-eleven/`:

```text
npm install
npm run dev
npm run agent:preflight
npm run agent:postflight
```

## تشغيل Godot

افتح `artifacts/eleven-eleven/godot/project.godot` في Godot 4.7.2.
نسخة افتتاح الويب مرشح يحتاج قبولاً كاملاً قبل تفعيله؛ لا تُستنتج جودة الهاتف أو اكتمال القصة من نجاح الاختبارات الآلية.

## حفظ المشروع

الكانون والأصول الفريدة والتقارير محفوظة. يوثق سجل تنظيف 2026-09-28 إزالة نسخ أرشيفية متطابقة فقط، مع الأصل المحفوظ وبصمته ونسخة احتياطية.
