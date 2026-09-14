# بطاقة الأصل المرجعية: كبسولة الاستيقاظ للقطاع 11 (Sector 11 Wake Capsule)

- **معرف الأصل:** sector11-wake-capsule
- **الحالة:** معتمد إنتاجياً (Production-Ready Hero Prop)
- **الموقع:** artifacts/eleven-eleven/art/production/sector11-wake-capsule/
- **المحرك المستهدف:** Three.js / React Three Fiber (Web & Mobile)

---

## 1. مواصفات الأصل البنيوية (Structural Metrics)

| الخاصية | القيمة المعتمدة | ميزانية المشروع (asset-budgets.json) | الحالة |
| :--- | :--- | :--- | :--- |
| **حجم ملف GLB** | 1.47 MB (1,538,452 بايت) | <= 6.0 MB | ✅ ممتاز (25% من الحد) |
| **إجمالي المضلعات (Triangles)** | 55,102 مثلث | <= 80,000 مثلث | ✅ ممتاز (68% من الحد) |
| **عدد الرؤوس (Vertices)** | 27,301 رأس | — | ✅ خفيف وسلس |
| **عدد العظام (Bones)** | 3 عظام (root, capsule_base, canopy_hinge) | <= 128 عظمة | ✅ خفيف جداً |
| **طقم الحركات (Actions)** | 4 حركات هيدروليكية معتمدة | — | ✅ كامل |

---

## 2. طقم الحركات الهيدروليكية (Animation Suite)

1. **CAPSULE_IDLE_CLOSED** (30 إطار):
   - الكبسولة محكمة الإغلاق ومحبوسة بنظام قفل الضغط أثناء استلقاء Echo بداخلها.
2. **CAPSULE_OPEN** (60 إطار - 2.5 ثانية):
   - الإطارات 1-10: تحرير أقفال الضغط الهيدروليكية وانبثاق الغطاء قليلاً للأمام (Unlatch Pop).
   - الإطارات 11-50: صعود هيدروليكي انسيابي بزاوية 80 درجة للأعلى مع تمدد المكابس.
   - الإطارات 51-60: استقرار ميكانيكي هادئ في وضعية الفتح الكامل (Damped Settle).
3. **CAPSULE_IDLE_OPEN** (30 إطار):
   - وضعية الثبات المفتوحة بعد خروج Echo وكشف كامل المقعد الداخلي وقنوات السوائل.
4. **CAPSULE_CLOSE** (60 إطار):
   - إغلاق هيدروليكي متزن ينتهي بإحكام قفل الكبسولة.

---

## 3. خامات الأنمي المعتمدة (Genshin-Grade PBR Suite)

- **Mat_Capsule_Obsidian**: ألياف كربونية سوداء مطفية (#0b0c10) بدون لمعان بلاستيكي.
- **Mat_Capsule_DarkSteel**: معدن مصفح غامق للمكابس الهيدروليكية والصمامات.
- **Mat_Capsule_CyanEmissive**: قنوات تدفق سائل التجميد المشعة باللون السياني (#00f0ff / Emission 6.0).
- **Mat_Capsule_SignalCrimson**: مؤشرات أقفال التحذير وحلقات الخطر القرمزية (#ff2a4b).
- **Mat_Capsule_CryoGlass**: زجاج تجميد شبه شفاف شفافية عالية للمعاينة الداخلية.

---

## 4. بصمات الملفات الرسمية (SHA-256 Checksums)

- wake-capsule.glb: 38c1cdbda2be7721ecbae0c62118358f9ce03f88bfa5bbf819c7a430b7beb0a6
- wake-capsule.blend: e1a8d184846bddaf78bc5dc19463b3aac4ad3ced98d9b3b80aa92934777a925f
- capsule_opening_preview.mp4: f7f0793ccebed4f70fd21fd0d21cb0f4b22f76c18c529d739da05f547c7e71a2
- render_front.png: c4f20b59e68948ec98493ff6351f0ce9b82d9bf3aa42424e056eb2468fd82c44
- render_open.png: e4c55f40fc67a404d2da49f722c937147627198b0e9c76ca173579c40f2a5a57
- render_side.png: a1eca775a264868c383e5160a8a18b920c10912b7a6a9d93e45b3c9f98331c8b
- render_three_quarter.png: 50f649043d4b4af9c5facc049edf40f8cb31b7b0b6367765609e274d05a82b4b