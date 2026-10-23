# تدقيق جاهزية الإصدار — 11.11

_أُنتج آليًا: 2026-10-23T12:09:39+00:00 · commit `9f4f83f0`_

## البيئة الحالية

- Godot: `غير مثبت` · Blender: `غير مثبت` · bpy: `لا`
- كاش استيراد Godot: `غير موجود` · قوالب التصدير: `غير مثبتة`
- المعالج/الذاكرة المتاحة للأداء: 2 نواة

## الشخصيات (قراءة GLB مباشرة)

| الشخصية | الحالة | مفاصل | أصابع | وجه/فك | Morph | حركات داخل الملف |
|---|---|---|---|---|---|---|
| Echo (player) | OK | 68 | 30 | 0 | 0 | 1 |
| Kinja (antagonist) | OK | 33 | 0 | 0 | 0 | 0 |
| Zero (contract entity) | OK | 41 | 0 | 0 | 0 | 1 |

## تغطية الحركة في runtime

- ملفات الحركة: 6 · المفقود: walk, wake_getup, attack, dodge, climb, hit_reaction, interact_hand

## الصوت

- ملفات: 8 (0.55 MB) · ملفات صوت شخصيات: 0

## Git LFS

- أصول runtime غير موجودة فعليًا: 34 · منها مستخدمة فعليًا: 8
- أداة git-lfs مثبتة: لا

## التصدير

- `export_presets.cfg`: موجود · عدد presets: 3
- **Web** (Web) → `../.tmp/godot-web/index.html` · ملفات معلنة مفقودة: 0
- **Windows Opening** (Windows Desktop) → `../.tmp/native-opening/EchoNetwork.exe` · ملفات معلنة مفقودة: 0
- **Android Opening** (Android) → `../.tmp/native-opening/EchoNetwork-debug.apk` · ملفات معلنة مفقودة: 0
  - Android: internet=false, gradle=false, version=0.1-opening (1), package=com.echonetwork.opening, AAB=False

## نقطة الدخول والمحتوى

- مسارات boot: native_journey.tscn, opening_web_room.tscn
- مشاهد Godot: 76 · سكربتات: 195 · فحوص Godot: 151 · فحوص ويب: 110 · e2e: 3
- مجموعات المحتوى في `data/`: {'chapters': 7, 'puzzles': 0, 'memories': 0, 'dialogues': 0, 'endings': 0, 'cinematics': 0}

## الأدلة

- ملفات دليل/تحقق: 255 · منها غير موجود محليًا (LFS): 255 (أحدث 12 في تقرير JSON)

_هذا الملف يقيس الحالة فقط؛ لا يمنح PASS لأي بوابة._
